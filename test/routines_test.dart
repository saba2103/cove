import 'dart:convert';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/features/routines/routine_models.dart';
import 'package:cove/features/routines/routine_screen.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Routine Models Tests', () {
    test('Routine days summary formats correctly', () {
      final r1 = Routine(
        id: '1',
        homeId: 'h1',
        name: 'Weekday',
        days: [1, 2, 3, 4, 5],
        createdAt: DateTime.now(),
      );
      expect(r1.daysSummary, equals('Mon – Fri'));

      final r2 = Routine(
        id: '2',
        homeId: 'h1',
        name: 'Weekend',
        days: [6, 7],
        createdAt: DateTime.now(),
      );
      expect(r2.daysSummary, equals('Sat, Sun'));

      final r3 = Routine(
        id: '3',
        homeId: 'h1',
        name: 'Daily',
        days: [1, 2, 3, 4, 5, 6, 7],
        createdAt: DateTime.now(),
      );
      expect(r3.daysSummary, equals('Every day'));
    });

    test('RoutineEvent time formatters and duration calculate correctly', () {
      expect(RoutineEvent.formatMinutes(0), equals('12:00 AM'));
      expect(RoutineEvent.formatMinutes(540), equals('9:00 AM'));
      expect(RoutineEvent.formatMinutes(720), equals('12:00 PM'));
      expect(RoutineEvent.formatMinutes(810), equals('1:30 PM'));
      expect(RoutineEvent.formatMinutes(1380), equals('11:00 PM'));

      final ev = RoutineEvent(
        id: 'e1',
        routineId: 'r1',
        homeId: 'h1',
        title: 'Morning Run',
        startMinutes: 420, // 7:00 AM
        endMinutes: 480,   // 8:00 AM
        category: 'Fitness',
        createdAt: DateTime.now(),
      );
      expect(ev.durationMinutes, equals(60));
      expect(ev.formattedTimeRange, equals('7:00 AM – 8:00 AM'));
      expect(ev.categoryColor, equals(const Color(0xFFE57373)));
    });
  });

  group('Routine Database & Sync Store Tests', () {
    late AppDatabase db;
    late LocalStateStoreImpl store;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      store = LocalStateStoreImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('LocalStateStore applies routine and routine event lifecycle', () async {
      final now = DateTime.now();

      // 1. Create Routine
      await store.applyEvent(
        homeId: 'home_1',
        eventType: 'routine_created',
        payload: {
          'id': 'routine_1',
          'name': 'Weekday Routine',
          'days_json': jsonEncode([1, 2, 3, 4, 5]),
        },
        timestamp: now,
        authorId: 'user_1',
      );

      final routines = await db.getRoutines('home_1');
      expect(routines.length, equals(1));
      expect(routines.first.name, equals('Weekday Routine'));

      // 2. Create Routine Event
      await store.applyEvent(
        homeId: 'home_1',
        eventType: 'routine_event_created',
        payload: {
          'id': 'ev_1',
          'routine_id': 'routine_1',
          'title': 'Deep Work',
          'start_minutes': 540,
          'end_minutes': 720,
          'category': 'Work',
          'notes': 'No meetings',
        },
        timestamp: now,
        authorId: 'user_1',
      );

      final events = await db.getRoutineEvents('routine_1');
      expect(events.length, equals(1));
      expect(events.first.title, equals('Deep Work'));
      expect(events.first.startMinutes, equals(540));

      // 3. Update Routine Event
      await store.applyEvent(
        homeId: 'home_1',
        eventType: 'routine_event_updated',
        payload: {
          'id': 'ev_1',
          'routine_id': 'routine_1',
          'title': 'Deep Work & Strategy',
          'start_minutes': 600,
          'end_minutes': 720,
          'category': 'Work',
        },
        timestamp: now,
        authorId: 'user_1',
      );

      final updatedEvents = await db.getRoutineEvents('routine_1');
      expect(updatedEvents.first.title, equals('Deep Work & Strategy'));
      expect(updatedEvents.first.startMinutes, equals(600));

      // 4. Delete Routine deletes both routine and child events
      await store.applyEvent(
        homeId: 'home_1',
        eventType: 'routine_deleted',
        payload: {
          'id': 'routine_1',
        },
        timestamp: now,
        authorId: 'user_1',
      );

      final remainingRoutines = await db.getRoutines('home_1');
      expect(remainingRoutines, isEmpty);
      final remainingEvents = await db.getRoutineEvents('routine_1');
      expect(remainingEvents, isEmpty);
    });
  });

  group('Routine Screen Widget Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Renders RoutineScreen with default seed routines and timeline', (tester) async {
      final now = DateTime.now();

      // Seed a routine and event directly
      await db.into(db.localRoutines).insert(
        LocalRoutinesCompanion.insert(
          id: 'rot_weekday',
          homeId: 'home_1',
          name: 'Weekday (Mon – Fri)',
          daysJson: jsonEncode([1, 2, 3, 4, 5]),
          createdAt: now,
        ),
      );

      await db.into(db.localRoutineEvents).insert(
        LocalRoutineEventsCompanion.insert(
          id: 'rev_1',
          routineId: 'rot_weekday',
          homeId: 'home_1',
          title: 'Morning Yoga',
          startMinutes: 420,
          endMinutes: 480,
          category: const drift.Value('Fitness'),
          createdAt: now,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeHomeIdProvider.overrideWith(() => FakeActiveHomeNotifier('home_1')),
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const RoutineScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Routine title and tab
      expect(find.text('Daily Routines'), findsOneWidget);
      expect(find.text('Weekday (Mon – Fri)'), findsOneWidget);

      // Verify event is displayed on 24h timeline
      expect(find.text('Morning Yoga'), findsOneWidget);
      expect(find.text('7:00 AM – 8:00 AM'), findsOneWidget);

      // Verify Add Event FAB
      expect(find.text('Add Event'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}

class FakeActiveHomeNotifier extends Notifier<String?> implements ActiveHomeNotifier {
  final String? _initial;
  FakeActiveHomeNotifier(this._initial);

  @override
  String? build() => _initial;

  @override
  Future<void> setActiveHome(String? homeId) async => state = homeId;
}
