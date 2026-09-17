import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../notifications/notification_controller.dart';

class CoveUser {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;

  const CoveUser({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
  });

  factory CoveUser.fromSupabase(User user) {
    final meta = user.userMetadata ?? {};
    final bool useInitials = meta['use_initials'] == true;
    final String? rawAvatar = (meta['avatar_url'] as String?)?.trim();
    final String? googlePicture = (meta['picture'] as String?)?.trim();

    String? resolvedAvatar;
    if (!useInitials) {
      if (rawAvatar != null && rawAvatar.isNotEmpty) {
        resolvedAvatar = rawAvatar;
      } else if (googlePicture != null && googlePicture.isNotEmpty) {
        resolvedAvatar = googlePicture;
      }
    }

    final String resolvedName = (meta['display_name'] as String?)?.trim() ??
        (meta['full_name'] as String?)?.trim() ??
        (meta['name'] as String?)?.trim() ??
        user.email?.split('@').first ??
        'Partner';

    return CoveUser(
      id: user.id,
      email: user.email ?? 'user@cove.local',
      displayName: resolvedName,
      avatarUrl: resolvedAvatar,
    );
  }

  factory CoveUser.demo() {
    return const CoveUser(
      id: 'demo-user-alex',
      email: 'alex@cove.local',
      displayName: 'Alex',
    );
  }
}

class AuthNotifier extends Notifier<AsyncValue<CoveUser?>> {
  StreamSubscription<AuthState>? _sub;

  @override
  AsyncValue<CoveUser?> build() {
    final supabase = ref.watch(supabaseClientProvider);

    if (supabase != null) {
      final current = supabase.auth.currentUser;
      _sub?.cancel();
      _sub = supabase.auth.onAuthStateChange.listen((data) {
        final user = data.session?.user;
        state = AsyncValue.data(user != null ? CoveUser.fromSupabase(user) : null);
      });

      ref.onDispose(() => _sub?.cancel());

      if (current != null) {
        _refreshUserFromSupabase(supabase);
        return AsyncValue.data(CoveUser.fromSupabase(current));
      }
    }

    return const AsyncValue.data(null);
  }

  Future<void> _refreshUserFromSupabase(SupabaseClient supabase) async {
    try {
      final res = await supabase.auth.getUser();
      if (res.user != null) {
        state = AsyncValue.data(CoveUser.fromSupabase(res.user!));
      }
    } catch (_) {}
  }

  /// Initiates real Google Sign-In linked to Supabase Auth.
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    final supabase = ref.read(supabaseClientProvider);

    if (supabase == null) {
      state = AsyncValue.error(
        'Authentication service is not configured. Please check connection.',
        StackTrace.current,
      );
      return;
    }

    try {
      final redirectUrl = kIsWeb
          ? Uri.base.origin
          : 'io.supabase.cove://login-callback';

      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );
      final current = supabase.auth.currentUser;
      if (current != null) {
        state = AsyncValue.data(CoveUser.fromSupabase(current));
      } else if (!kIsWeb) {
        state = const AsyncValue.data(null);
      }
    } on AuthException catch (e, st) {
      state = AsyncValue.error(e.message, st);
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
    }
  }



  /// Developer / demo bypass sign-in for tests
  void signInWithDemoUser([String name = 'Alex', String email = 'alex@cove.local']) {
    state = AsyncValue.data(CoveUser(
      id: 'demo-user-${name.toLowerCase()}',
      email: email,
      displayName: name,
    ));
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        final notifService = ref.read(notificationServiceProvider);
        await notifService.unregisterDeviceToken(token);
      }
    } catch (e) {
      debugPrint('[AuthController] Error unregistering token on signOut: $e');
    }

    final supabase = ref.read(supabaseClientProvider);
    try {
      await supabase?.auth.signOut();
    } catch (_) {}
    state = const AsyncValue.data(null);
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AsyncValue<CoveUser?>>(AuthNotifier.new);
