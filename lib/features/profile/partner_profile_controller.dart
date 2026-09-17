import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';

class PartnerProfileState {
  final String displayName;
  final String? avatarUrl;
  final String? userId;
  final bool hasCustomName;

  const PartnerProfileState({
    this.displayName = 'Partner',
    this.avatarUrl,
    this.userId,
    this.hasCustomName = false,
  });

  PartnerProfileState copyWith({
    String? displayName,
    String? avatarUrl,
    String? userId,
    bool? hasCustomName,
  }) {
    return PartnerProfileState(
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      userId: userId ?? this.userId,
      hasCustomName: hasCustomName ?? this.hasCustomName,
    );
  }
}

class PartnerProfileNotifier extends Notifier<PartnerProfileState> {
  static FlutterSecureStorage storage = const FlutterSecureStorage();
  static const _partnerNameKeyPrefix = 'cove_partner_name_';
  static const _partnerAvatarKeyPrefix = 'cove_partner_avatar_';
  static const _partnerIdKeyPrefix = 'cove_partner_id_';
  static final Map<String, PartnerProfileState> _cachedProfiles = {};

  static final Set<PartnerProfileNotifier> _activeNotifiers = {};

  @override
  PartnerProfileState build() {
    _activeNotifiers.add(this);
    ref.onDispose(() => _activeNotifiers.remove(this));

    final homeId = ref.watch(activeHomeIdProvider) ?? 'default';
    ref.watch(authProvider); // Re-run when auth changes or resolves
    _loadPartnerOverrides(homeId);

    final cached = _cachedProfiles[homeId] ?? _cachedProfiles['default'];
    if (cached != null && cached.displayName != 'Partner') {
      return cached;
    }

    return const PartnerProfileState();
  }

  static Future<void> updatePartnerFromRemote({
    required String homeId,
    required String name,
    String? avatarUrl,
    String? userId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == 'Partner' || trimmed == 'You') return;

    // Guard against self-profile updates
    String? currentUserId;
    try {
      currentUserId = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {}
    if (currentUserId != null && userId != null && userId == currentUserId) {
      return;
    }

    final newState = PartnerProfileState(
      displayName: trimmed,
      avatarUrl: avatarUrl,
      userId: userId,
      hasCustomName: true,
    );

    _cachedProfiles[homeId] = newState;
    _cachedProfiles['default'] = newState;

    for (final notifier in _activeNotifiers) {
      notifier.state = newState;
    }

    try {
      await storage.write(key: '$_partnerNameKeyPrefix$homeId', value: trimmed);
      await storage.write(key: '${_partnerNameKeyPrefix}default', value: trimmed);
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        await storage.write(key: '$_partnerAvatarKeyPrefix$homeId', value: avatarUrl);
        await storage.write(key: '${_partnerAvatarKeyPrefix}default', value: avatarUrl);
      }
      if (userId != null && userId.isNotEmpty) {
        await storage.write(key: '$_partnerIdKeyPrefix$homeId', value: userId);
        await storage.write(key: '${_partnerIdKeyPrefix}default', value: userId);
      }
    } catch (_) {}
  }

  Future<void> _loadPartnerOverrides(String homeId) async {
    try {
      final authUser = ref.read(authProvider).value;
      final supabaseUser = ref.read(supabaseClientProvider)?.auth.currentUser;
      final currentUserId = authUser?.id ?? supabaseUser?.id;
      final currentUserName = authUser?.displayName ??
          (supabaseUser?.userMetadata?['display_name'] as String?) ??
          (supabaseUser?.userMetadata?['full_name'] as String?);

      String? name = await storage.read(key: '$_partnerNameKeyPrefix$homeId');
      String? avatar = await storage.read(key: '$_partnerAvatarKeyPrefix$homeId');
      String? pUserId = await storage.read(key: '$_partnerIdKeyPrefix$homeId');

      if (name == null || name.trim().isEmpty || name.trim() == 'Partner' || name.trim() == 'You') {
        // Check default key
        name = await storage.read(key: '${_partnerNameKeyPrefix}default');
        avatar ??= await storage.read(key: '${_partnerAvatarKeyPrefix}default');
        pUserId ??= await storage.read(key: '${_partnerIdKeyPrefix}default');
      }

      // Self-healing: if cached partner name or id matches current user, purge the poisoned cache
      final isPoisoned = (pUserId != null && currentUserId != null && pUserId == currentUserId) ||
          (name != null &&
              currentUserName != null &&
              currentUserName.trim().isNotEmpty &&
              name.trim().toLowerCase() == currentUserName.trim().toLowerCase());

      if (isPoisoned) {
        debugPrint('[PartnerProfile] Purging poisoned partner cache: $name ($pUserId)');
        await storage.delete(key: '$_partnerNameKeyPrefix$homeId');
        await storage.delete(key: '$_partnerAvatarKeyPrefix$homeId');
        await storage.delete(key: '$_partnerIdKeyPrefix$homeId');
        await storage.delete(key: '${_partnerNameKeyPrefix}default');
        await storage.delete(key: '${_partnerAvatarKeyPrefix}default');
        await storage.delete(key: '${_partnerIdKeyPrefix}default');
        _cachedProfiles.remove(homeId);
        _cachedProfiles.remove('default');
        name = null;
        avatar = null;
        pUserId = null;
      }

      // 1. Direct fetch from Supabase home_members (Primary source of truth)
      final supabase = ref.read(supabaseClientProvider);
      if (supabase != null && homeId.isNotEmpty && homeId != 'default') {
        try {
          var query = supabase
              .from('home_members')
              .select('user_id, display_name, avatar_url')
              .eq('home_id', homeId);
          if (currentUserId != null && currentUserId.isNotEmpty) {
            query = query.neq('user_id', currentUserId);
          }
          final rows = await query.limit(1);
          if (rows.isNotEmpty) {
            final row = rows.first;
            final dName = (row['display_name'] as String?)?.trim();
            final sAvatar = row['avatar_url'] as String?;
            final sUserId = row['user_id'] as String?;
            if (dName != null &&
                dName.isNotEmpty &&
                dName != 'Partner' &&
                (currentUserName == null ||
                    dName.toLowerCase() != currentUserName.trim().toLowerCase())) {
              final newState = PartnerProfileState(
                displayName: dName,
                avatarUrl: sAvatar,
                userId: sUserId,
                hasCustomName: true,
              );
              state = newState;
              _cachedProfiles[homeId] = newState;
              _cachedProfiles['default'] = newState;
              await storage.write(key: '$_partnerNameKeyPrefix$homeId', value: dName);
              await storage.write(key: '${_partnerNameKeyPrefix}default', value: dName);
              if (sAvatar != null && sAvatar.isNotEmpty) {
                await storage.write(key: '$_partnerAvatarKeyPrefix$homeId', value: sAvatar);
                await storage.write(key: '${_partnerAvatarKeyPrefix}default', value: sAvatar);
              }
              if (sUserId != null && sUserId.isNotEmpty) {
                await storage.write(key: '$_partnerIdKeyPrefix$homeId', value: sUserId);
                await storage.write(key: '${_partnerIdKeyPrefix}default', value: sUserId);
              }
              return;
            }
          }
        } catch (e) {
          debugPrint('[PartnerProfile] Error fetching partner from Supabase home_members: $e');
        }
      }

      // 2. If valid non-poisoned cache exists, use it
      if (name != null && name.trim().isNotEmpty && name.trim() != 'Partner' && name.trim() != 'You') {
        final newState = PartnerProfileState(
          displayName: name.trim(),
          avatarUrl: avatar,
          userId: pUserId,
          hasCustomName: true,
        );
        state = newState;
        _cachedProfiles[homeId] = newState;
        _cachedProfiles['default'] = newState;
        return;
      }

      // 3. If secure storage and Supabase didn't resolve, fallback to SQLite activity events
      final db = ref.read(appDatabaseProvider);
      final events = await (db.select(db.localActivityEvents)
            ..where((t) =>
                (homeId.isNotEmpty && homeId != 'default'
                    ? t.homeId.equals(homeId)
                    : const Constant(true)) &
                (currentUserId != null && currentUserId.isNotEmpty
                    ? t.actorId.isNotValue(currentUserId)
                    : const Constant(true)))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(50))
          .get();

      for (final event in events) {
        if (currentUserId != null &&
            currentUserId.isNotEmpty &&
            event.actorId == currentUserId) {
          continue;
        }
        try {
          final payload = jsonDecode(event.payloadJson) as Map<String, dynamic>;
          final pUserId = payload['user_id'] as String? ?? event.actorId;
          if (currentUserId != null &&
              currentUserId.isNotEmpty &&
              pUserId == currentUserId) {
            continue;
          }

          final dName = (payload['display_name'] ?? payload['actor_name']) as String?;
          final avatar = payload['avatar_url'] as String?;

          if (dName != null &&
              dName.trim().isNotEmpty &&
              dName.trim() != 'Partner' &&
              dName.trim() != 'You') {
            final trimmed = dName.trim();
            if (currentUserName != null &&
                trimmed.toLowerCase() == currentUserName.trim().toLowerCase()) {
              continue;
            }
            final newState = PartnerProfileState(
              displayName: trimmed,
              avatarUrl: avatar,
              userId: pUserId,
              hasCustomName: true,
            );
            state = newState;
            _cachedProfiles[homeId] = newState;
            _cachedProfiles['default'] = newState;
            await storage.write(key: '$_partnerNameKeyPrefix$homeId', value: trimmed);
            await storage.write(key: '${_partnerNameKeyPrefix}default', value: trimmed);
            return;
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> updatePartnerDisplayName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    final homeId = ref.read(activeHomeIdProvider) ?? 'default';
    final newState = state.copyWith(
      displayName: trimmed,
      hasCustomName: true,
    );
    state = newState;
    _cachedProfiles[homeId] = newState;
    _cachedProfiles['default'] = newState;

    try {
      await storage.write(
        key: '$_partnerNameKeyPrefix$homeId',
        value: trimmed,
      );
      await storage.write(
        key: '${_partnerNameKeyPrefix}default',
        value: trimmed,
      );
    } catch (_) {}
  }

  Future<void> setPartnerFromSync({
    required String name,
    String? avatarUrl,
    String? userId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == 'Partner' || trimmed == 'You') return;

    final currentUserId = ref.read(authProvider).value?.id;
    final currentUserName = ref.read(authProvider).value?.displayName;
    if (currentUserId != null && userId != null && userId == currentUserId) return;
    if (currentUserName != null &&
        currentUserName.trim().isNotEmpty &&
        trimmed.toLowerCase() == currentUserName.trim().toLowerCase()) {
      return;
    }

    final homeId = ref.read(activeHomeIdProvider) ?? 'default';
    final newState = state.copyWith(
      displayName: trimmed,
      avatarUrl: avatarUrl,
      userId: userId,
      hasCustomName: true,
    );
    state = newState;
    _cachedProfiles[homeId] = newState;
    _cachedProfiles['default'] = newState;

    try {
      await storage.write(
        key: '$_partnerNameKeyPrefix$homeId',
        value: trimmed,
      );
      await storage.write(
        key: '${_partnerNameKeyPrefix}default',
        value: trimmed,
      );
      if (avatarUrl != null) {
        await storage.write(
          key: '$_partnerAvatarKeyPrefix$homeId',
          value: avatarUrl,
        );
      }
      if (userId != null && userId.isNotEmpty) {
        await storage.write(
          key: '$_partnerIdKeyPrefix$homeId',
          value: userId,
        );
      }
    } catch (_) {}
  }
}

final partnerProfileProvider =
    NotifierProvider<PartnerProfileNotifier, PartnerProfileState>(
        PartnerProfileNotifier.new);
