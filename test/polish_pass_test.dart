import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_brand_mark.dart';
import 'package:cove/core/widgets/cove_error_state.dart';
import 'package:cove/core/widgets/cove_splash_screen.dart';
import 'package:cove/core/widgets/cove_sync_tick.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapWithTheme(Widget child, {ThemeMode mode = ThemeMode.dark}) {
  return MaterialApp(
    theme: CoveTheme.lightTheme,
    darkTheme: CoveTheme.darkTheme,
    themeMode: mode,
    home: child,
  );
}

void main() {
  group('Polish Pass: CoveErrorState Component', () {
    testWidgets('Renders generic error state with calm typography and retry button', (tester) async {
      bool retried = false;
      await tester.pumpWidget(_wrapWithTheme(
        CoveErrorState.generic(
          title: 'Unable to load items',
          description: 'Network or storage could not be accessed.',
          onRetry: () => retried = true,
          retryLabel: 'Try again',
        ),
      ));

      expect(find.text('Unable to load items'), findsOneWidget);
      expect(find.text('Network or storage could not be accessed.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
    });

    testWidgets('Renders syncPending error state with calm copy', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(
        CoveErrorState.syncPending(),
      ));

      expect(find.text('Waiting to sync'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_queue_outlined), findsOneWidget);
    });

    testWidgets('Renders partnerWaiting state with invite action', (tester) async {
      bool invited = false;
      await tester.pumpWidget(_wrapWithTheme(
        CoveErrorState.partnerWaiting(
          onInvite: () => invited = true,
        ),
      ));

      expect(find.text("Partner hasn't joined yet"), findsOneWidget);
      expect(find.text('Share invite code'), findsOneWidget);
      await tester.tap(find.text('Share invite code'));
      expect(invited, isTrue);
    });
  });

  group('Polish Pass: CoveBrandMark and CoveSplashScreen', () {
    testWidgets('Renders brand mark with custom size', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(
        const Scaffold(body: Center(child: CoveBrandMark(size: 80))),
      ));

      expect(find.byType(CoveBrandMark), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Renders CoveSplashScreen with wordmark and loading indicator', (tester) async {
      await tester.pumpWidget(_wrapWithTheme(
        const CoveSplashScreen(message: 'Opening your home...', showProgress: true),
      ));

      expect(find.text('Cove'), findsOneWidget);
      expect(find.text('Opening your home...'), findsOneWidget);
      expect(find.byType(CoveBrandMark), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('Polish Pass: Two-Tick Delivery Sync Status Integrity', () {
    final now = DateTime.now();

    test('Private items NEVER show 2 ticks even if partner is present and outbox is synced', () {
      final outbox = [
        LocalOutboxEvent(
          id: 'evt_1',
          homeId: 'home_1',
          actorId: 'user_1',
          eventType: 'subscription_added',
          payloadJson: '{"id": "sub_private_1"}',
          encryptedPayload: 'blob',
          createdAt: now,
          syncStatus: 'syncedToPartner',
          retryCount: 0,
        ),
      ];

      final status = resolveCoveSyncStatus(
        entityId: 'sub_private_1',
        outbox: outbox,
        isPrivate: true,
        hasPartner: true,
      );

      expect(status, equals(CoveSyncStatus.savedLocally));
    });

    test('Items in a home with NO partner NEVER show 2 ticks', () {
      final outbox = [
        LocalOutboxEvent(
          id: 'evt_2',
          homeId: 'home_1',
          actorId: 'user_1',
          eventType: 'list_item_added',
          payloadJson: '{"id": "item_1"}',
          encryptedPayload: 'blob',
          createdAt: now,
          syncStatus: 'syncedToPartner',
          retryCount: 0,
        ),
      ];

      final status = resolveCoveSyncStatus(
        entityId: 'item_1',
        outbox: outbox,
        isPrivate: false,
        hasPartner: false, // NO partner connected
      );

      expect(status, equals(CoveSyncStatus.savedLocally));
    });

    test('Items with pending unsynced outbox events show strictly 1 tick (savedLocally)', () {
      final outbox = [
        LocalOutboxEvent(
          id: 'evt_3',
          homeId: 'home_1',
          actorId: 'user_1',
          eventType: 'expense_logged',
          payloadJson: '{"id": "exp_pending_1"}',
          encryptedPayload: 'blob',
          createdAt: now,
          syncStatus: 'savedLocally', // Still pending transmission
          retryCount: 0,
        ),
      ];

      final status = resolveCoveSyncStatus(
        entityId: 'exp_pending_1',
        outbox: outbox,
        isPrivate: false,
        hasPartner: true,
      );

      expect(status, equals(CoveSyncStatus.savedLocally));
    });

    test('Shared items with partner and confirmed delivery show 2 ticks (syncedToPartner)', () {
      final outbox = [
        LocalOutboxEvent(
          id: 'evt_4',
          homeId: 'home_1',
          actorId: 'user_1',
          eventType: 'calendar_event_added',
          payloadJson: '{"id": "cal_1"}',
          encryptedPayload: 'blob',
          createdAt: now,
          syncStatus: 'syncedToPartner', // Partner confirmed receipt
          retryCount: 0,
        ),
      ];

      final status = resolveCoveSyncStatus(
        entityId: 'cal_1',
        outbox: outbox,
        isPrivate: false,
        hasPartner: true,
      );

      expect(status, equals(CoveSyncStatus.syncedToPartner));
    });

    test('Shared items cleared from outbox in an established 2-member household show 2 ticks', () {
      // Empty outbox means event was confirmed delivered and purged
      final status = resolveCoveSyncStatus(
        entityId: 'cal_old_1',
        outbox: const [],
        isPrivate: false,
        hasPartner: true,
      );

      expect(status, equals(CoveSyncStatus.syncedToPartner));
    });
  });
}
