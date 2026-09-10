import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../sync/providers/cove_sync_providers.dart';

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
    return CoveUser(
      id: user.id,
      email: user.email ?? 'user@cove.local',
      displayName: (meta['full_name'] as String?) ??
          (meta['name'] as String?) ??
          user.email?.split('@').first ??
          'Partner',
      avatarUrl: meta['avatar_url'] as String?,
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
        return AsyncValue.data(CoveUser.fromSupabase(current));
      }
    }

    return const AsyncValue.data(null);
  }

  /// Initiates Google Sign-In linked to Supabase Auth.
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    final supabase = ref.read(supabaseClientProvider);

    if (supabase == null) {
      // Offline / demo fallback when Supabase credentials are not configured
      await Future.delayed(const Duration(milliseconds: 300));
      state = AsyncValue.data(CoveUser.demo());
      return;
    }

    try {
      await supabase.auth.signInWithOAuth(OAuthProvider.google);
      final current = supabase.auth.currentUser;
      if (current != null) {
        state = AsyncValue.data(CoveUser.fromSupabase(current));
      }
    } catch (_) {
      // In development / demo environments where Google Sign-In isn't configured,
      // fallback to demo session so the user can continue exploring the app.
      state = AsyncValue.data(CoveUser.demo());
    }
  }

  /// Developer / demo bypass sign-in for testing
  void signInWithDemoUser([String name = 'Alex', String email = 'alex@cove.local']) {
    state = AsyncValue.data(CoveUser(
      id: 'demo-user-${name.toLowerCase()}',
      email: email,
      displayName: name,
    ));
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    final supabase = ref.read(supabaseClientProvider);
    try {
      await supabase?.auth.signOut();
    } catch (_) {}
    state = const AsyncValue.data(null);
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AsyncValue<CoveUser?>>(AuthNotifier.new);
