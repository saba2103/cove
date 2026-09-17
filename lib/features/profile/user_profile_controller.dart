import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';

class UserProfileState {
  final String displayName;
  final String? avatarUrl;
  final String email;
  final bool hasCustomName;
  final bool hasCustomAvatar;

  const UserProfileState({
    required this.displayName,
    this.avatarUrl,
    required this.email,
    this.hasCustomName = false,
    this.hasCustomAvatar = false,
  });

  UserProfileState copyWith({
    String? displayName,
    String? avatarUrl,
    bool clearAvatar = false,
    String? email,
    bool? hasCustomName,
    bool? hasCustomAvatar,
  }) {
    return UserProfileState(
      displayName: displayName ?? this.displayName,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      email: email ?? this.email,
      hasCustomName: hasCustomName ?? this.hasCustomName,
      hasCustomAvatar: clearAvatar ? false : (hasCustomAvatar ?? this.hasCustomAvatar),
    );
  }
}

class UserProfileNotifier extends Notifier<UserProfileState> {
  static final Set<UserProfileNotifier> _activeNotifiers = {};
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _customNameKeyPrefix = 'cove_custom_name_';
  static const _customAvatarKeyPrefix = 'cove_custom_avatar_';
  static const _removedAvatarKeyPrefix = 'cove_removed_avatar_';

  static String? cachedDisplayName;
  static String? cachedAvatarUrl;
  static bool? cachedUseInitials;

  @override
  UserProfileState build() {
    _activeNotifiers.add(this);
    ref.onDispose(() => _activeNotifiers.remove(this));

    final user = ref.watch(authProvider).value;
    final homeId = ref.watch(activeHomeIdProvider);
    final userId = user?.id ?? '';

    final defaultName = (cachedDisplayName != null && cachedDisplayName!.isNotEmpty)
        ? cachedDisplayName!
        : (user?.displayName ?? 'You');
    final defaultAvatar = (cachedUseInitials == true)
        ? null
        : ((cachedAvatarUrl != null && cachedAvatarUrl!.isNotEmpty)
            ? cachedAvatarUrl
            : user?.avatarUrl);
    final email = user?.email ?? '';
    final hasName = cachedDisplayName != null && cachedDisplayName!.isNotEmpty;
    final hasAvatar = cachedUseInitials == true || (cachedAvatarUrl != null && cachedAvatarUrl!.isNotEmpty);

    // Load initial synchronous state from defaults, async load overrides
    _loadCustomOverrides(userId, defaultName, defaultAvatar, email, homeId);

    return UserProfileState(
      displayName: defaultName,
      avatarUrl: defaultAvatar,
      email: email,
      hasCustomName: hasName,
      hasCustomAvatar: hasAvatar,
    );
  }

  static Future<void> updateUserFromRemote({
    required String name,
    String? avatarUrl,
    bool useInitials = false,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == 'You') return;

    for (final notifier in _activeNotifiers) {
      notifier.state = notifier.state.copyWith(
        displayName: trimmed,
        avatarUrl: useInitials ? null : avatarUrl,
        clearAvatar: useInitials,
        hasCustomName: true,
        hasCustomAvatar: useInitials || (avatarUrl != null && avatarUrl.isNotEmpty),
      );
    }
  }

  Future<void> _loadCustomOverrides(
    String userId,
    String defaultName,
    String? defaultAvatar,
    String email,
    String? homeId,
  ) async {
    if (userId.isEmpty) return;
    try {
      // 1. Fast local cache read (SharedPreferences + SecureStorage)
      final prefs = await SharedPreferences.getInstance();
      final pName = prefs.getString('cove_user_display_name') ??
          prefs.getString('$_customNameKeyPrefix$userId');
      final pAvatar = prefs.getString('cove_user_avatar_url') ??
          prefs.getString('$_customAvatarKeyPrefix$userId');
      final pInitials = prefs.getBool('cove_user_use_initials') ??
          (prefs.getBool('$_removedAvatarKeyPrefix$userId') ?? false);

      final customName = pName ?? await _storage.read(key: '$_customNameKeyPrefix$userId');
      final isAvatarRemoved = pInitials ||
          await _storage.read(key: '$_removedAvatarKeyPrefix$userId') == 'true';
      final customAvatar = pAvatar ??
          await _storage.read(key: '$_customAvatarKeyPrefix$userId');

      String activeName = (customName != null && customName.trim().isNotEmpty)
          ? customName.trim()
          : defaultName;
      String? activeAvatar = isAvatarRemoved ? null : (customAvatar ?? defaultAvatar);
      bool hasName = customName != null && customName.trim().isNotEmpty;
      bool hasAvatar = isAvatarRemoved || customAvatar != null;

      cachedDisplayName = activeName;
      cachedAvatarUrl = activeAvatar;
      cachedUseInitials = isAvatarRemoved;

      state = UserProfileState(
        displayName: activeName,
        avatarUrl: activeAvatar,
        email: email,
        hasCustomName: hasName,
        hasCustomAvatar: hasAvatar,
      );

      // 2. Fetch directly from Supabase server as primary cloud truth
      final supabase = ref.read(supabaseClientProvider);
      if (supabase != null) {
        try {
          final res = await supabase.auth.getUser();
          final cloudUser = res.user;
          if (cloudUser != null) {
            final meta = cloudUser.userMetadata ?? {};
            final bool useInitials = meta['use_initials'] == true;
            final String? cloudName = (meta['display_name'] as String?)?.trim();
            final String? cloudAvatar = (meta['avatar_url'] as String?)?.trim();

            bool changed = false;
            if (cloudName != null && cloudName.isNotEmpty && cloudName != 'You') {
              activeName = cloudName;
              hasName = true;
              changed = true;
              await _storage.write(key: '$_customNameKeyPrefix$userId', value: cloudName);
            }
            if (useInitials) {
              activeAvatar = null;
              hasAvatar = true;
              changed = true;
              await _storage.write(key: '$_removedAvatarKeyPrefix$userId', value: 'true');
              await _storage.delete(key: '$_customAvatarKeyPrefix$userId');
            } else if (cloudAvatar != null && cloudAvatar.isNotEmpty) {
              activeAvatar = cloudAvatar;
              hasAvatar = true;
              changed = true;
              await _storage.delete(key: '$_removedAvatarKeyPrefix$userId');
              await _storage.write(key: '$_customAvatarKeyPrefix$userId', value: cloudAvatar);
            }

            if (changed && _activeNotifiers.contains(this)) {
              state = UserProfileState(
                displayName: activeName,
                avatarUrl: activeAvatar,
                email: email,
                hasCustomName: hasName,
                hasCustomAvatar: hasAvatar,
              );
            }
          }
        } catch (e) {
          debugPrint('[UserProfile] Error fetching cloud user: $e');
        }
      }
    } catch (_) {
      // Fallback cleanly to defaults if storage read fails
    }
  }

  Future<void> _emitProfileSync(String displayName, String? avatarUrl, {bool useInitials = false}) async {
    final homeId = ref.read(activeHomeIdProvider);
    final user = ref.read(authProvider).value;

    if (homeId != null && homeId.isNotEmpty) {
      try {
        final emitAction = ref.read(coveEmitActionProvider);
        await emitAction(
          eventType: 'member_profile_updated',
          payload: {
            'display_name': displayName,
            'avatar_url': avatarUrl,
            'use_initials': useInitials,
            'user_id': user?.id,
          },
          targetHomeId: homeId,
        );
      } catch (_) {
        // Continue gracefully if offline or sync fails
      }
    }
  }

  /// Announces current user's profile to the active home upon connect/sync.
  Future<void> announceProfile() async {
    if (state.displayName.isNotEmpty) {
      await _emitProfileSync(state.displayName, state.avatarUrl);
    }
  }

  /// Atomically saves user profile changes (name, avatar, or initials preference) to Supabase and storage.
  Future<void> saveProfile({
    required String displayName,
    String? avatarUrl,
    required bool useInitials,
  }) async {
    final user = ref.read(authProvider).value;
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) return;

    final trimmedAvatar = (avatarUrl != null && avatarUrl.trim().isNotEmpty && !useInitials)
        ? avatarUrl.trim()
        : null;

    cachedDisplayName = trimmedName;
    cachedAvatarUrl = trimmedAvatar;
    cachedUseInitials = useInitials;

    state = UserProfileState(
      displayName: trimmedName,
      avatarUrl: trimmedAvatar,
      email: user?.email ?? '',
      hasCustomName: true,
      hasCustomAvatar: useInitials || trimmedAvatar != null,
    );

    // Persist to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cove_user_display_name', trimmedName);
      if (useInitials) {
        await prefs.setBool('cove_user_use_initials', true);
        await prefs.remove('cove_user_avatar_url');
      } else if (trimmedAvatar != null) {
        await prefs.setBool('cove_user_use_initials', false);
        await prefs.setString('cove_user_avatar_url', trimmedAvatar);
      }
      if (user != null) {
        await prefs.setString('$_customNameKeyPrefix${user.id}', trimmedName);
        if (useInitials) {
          await prefs.setBool('$_removedAvatarKeyPrefix${user.id}', true);
          await prefs.remove('$_customAvatarKeyPrefix${user.id}');
        } else if (trimmedAvatar != null) {
          await prefs.setBool('$_removedAvatarKeyPrefix${user.id}', false);
          await prefs.setString('$_customAvatarKeyPrefix${user.id}', trimmedAvatar);
        }
      }
    } catch (_) {}

    if (user != null) {
      await _storage.write(
        key: '$_customNameKeyPrefix${user.id}',
        value: trimmedName,
      );
      if (useInitials) {
        await _storage.write(key: '$_removedAvatarKeyPrefix${user.id}', value: 'true');
        await _storage.delete(key: '$_customAvatarKeyPrefix${user.id}');
      } else if (trimmedAvatar != null) {
        await _storage.delete(key: '$_removedAvatarKeyPrefix${user.id}');
        await _storage.write(key: '$_customAvatarKeyPrefix${user.id}', value: trimmedAvatar);
      }
    }

    final supabase = ref.read(supabaseClientProvider);
    if (supabase != null && user != null) {
      try {
        await supabase.auth.updateUser(
          UserAttributes(
            data: {
              'display_name': trimmedName,
              'full_name': trimmedName,
              'name': trimmedName,
              'avatar_url': trimmedAvatar ?? '',
              'picture': trimmedAvatar ?? '',
              'use_initials': useInitials,
              'avatar_removed': useInitials,
              'use_custom_avatar': !useInitials && trimmedAvatar != null,
            },
          ),
        );
      } catch (e) {
        debugPrint('[UserProfile] Error updating user attributes in Supabase: $e');
      }

      final homeId = ref.read(activeHomeIdProvider);
      if (homeId != null && homeId.isNotEmpty) {
        try {
          await supabase.from('home_members').upsert({
            'home_id': homeId,
            'user_id': user.id,
            'joined_at': DateTime.now().toUtc().toIso8601String(),
            'display_name': trimmedName,
            'avatar_url': trimmedAvatar,
          });
        } catch (_) {}
      }
    }

    await _emitProfileSync(trimmedName, trimmedAvatar, useInitials: useInitials);
  }

  Future<void> updateDisplayName(String newName) async {
    await saveProfile(
      displayName: newName,
      avatarUrl: state.avatarUrl,
      useInitials: state.avatarUrl == null,
    );
  }

  Future<void> updateAvatarUrl(String? newUrl) async {
    await saveProfile(
      displayName: state.displayName,
      avatarUrl: newUrl,
      useInitials: newUrl == null || newUrl.trim().isEmpty,
    );
  }

  Future<void> removeAvatar() async {
    await saveProfile(
      displayName: state.displayName,
      avatarUrl: null,
      useInitials: true,
    );
  }

  Future<void> resetToGoogleDefaults() async {
    final user = ref.read(authProvider).value;
    final defaultName = user?.displayName ?? 'You';
    final defaultAvatar = user?.avatarUrl;

    state = UserProfileState(
      displayName: defaultName,
      avatarUrl: defaultAvatar,
      email: user?.email ?? '',
      hasCustomName: false,
      hasCustomAvatar: false,
    );

    if (user != null) {
      await _storage.delete(key: '$_customNameKeyPrefix${user.id}');
      await _storage.delete(key: '$_customAvatarKeyPrefix${user.id}');
      await _storage.delete(key: '$_removedAvatarKeyPrefix${user.id}');
    }

    final supabase = ref.read(supabaseClientProvider);
    if (supabase != null && user != null) {
      try {
        await supabase.auth.updateUser(
          UserAttributes(
            data: {
              'display_name': defaultName,
              'full_name': defaultName,
              'name': defaultName,
              'avatar_url': defaultAvatar ?? '',
              'use_initials': false,
            },
          ),
        );
      } catch (_) {}
    }

    await _emitProfileSync(defaultName, defaultAvatar, useInitials: false);
  }
}

final userProfileProvider =
    NotifierProvider<UserProfileNotifier, UserProfileState>(UserProfileNotifier.new);
