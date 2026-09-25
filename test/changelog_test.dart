import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_pill_button.dart';
import 'package:cove/features/changelog/changelog_models.dart';
import 'package:cove/features/changelog/changelog_screen.dart';
import 'package:cove/features/changelog/whats_fresh_modal.dart';
import 'package:cove/features/changelog/widgets/changelog_preview_mockup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Changelog Models & Data Tests', () {
    test('kChangelogItems contains outcome-focused updates with valid dates', () {
      expect(kChangelogItems.length, 14);
      for (final item in kChangelogItems) {
        expect(item.title.isNotEmpty, isTrue);
        expect(item.tagline.isNotEmpty, isTrue);
        expect(item.outcome.isNotEmpty, isTrue);
        expect(item.underTheHood.isNotEmpty, isTrue);
        expect(item.category.isNotEmpty, isTrue);
        expect(item.version.isNotEmpty, isTrue);
        expect(item.date.isNotEmpty, isTrue);
      }
    });

    test('Exactly 3 featured items for the What\'s Fresh onboarding modal', () {
      final featured = kChangelogItems.where((i) => i.isFeatured).toList();
      expect(featured.length, 3);
      expect(featured[0].id, 'emi_tracker_and_closure');
      expect(featured[1].id, 'calendar_first_restructure');
      expect(featured[2].id, 'helicopter_view');
    });
  });

  group('What\'s Fresh Modal Widget Tests', () {
    testWidgets('Modal renders carousel with title, date, preview mockup, outcome, and monospaced box', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: CoveTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => WhatsFreshModal.show(ctx, force: true),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open Modal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Header badge & step counter
      expect(find.text("WHAT'S FRESH · v1.0"), findsOneWidget);
      expect(find.text('1 of 3'), findsOneWidget);

      // Slide 1 title, date & mockup
      expect(find.text('EMI Tracker & Loan Foreclosure'), findsOneWidget);
      expect(find.text('Sep 20, 2026'), findsOneWidget);
      expect(find.byType(ChangelogPreviewMockup), findsOneWidget);
      expect(find.text('UNDER THE HOOD'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Tap Next to advance to Slide 2
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('2 of 3'), findsOneWidget);
      expect(find.text('Calendar-First Sanctuary & Today Home'), findsOneWidget);
      expect(find.text('Sep 19, 2026'), findsOneWidget);

      // Tap Next to advance to Slide 3
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('3 of 3'), findsOneWidget);
      expect(find.text('Commitments Helicopter View'), findsOneWidget);
      expect(find.text('Sep 17, 2026'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);

      // Tap Got it to dismiss
      await tester.tap(find.text('Got it'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(WhatsFreshModal), findsNothing);
    });

    test('WhatsFreshModal version persistence records seen version in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kCoveLastSeenFreshVersionKey), isNull);

      await prefs.setString(kCoveLastSeenFreshVersionKey, kCoveCurrentAppVersion);
      expect(prefs.getString(kCoveLastSeenFreshVersionKey), kCoveCurrentAppVersion);
    });
  });

  group('ChangelogScreen Widget Tests', () {
    testWidgets('ChangelogScreen renders timeline items, dates, intro card, and What\'s Fresh AppBar button', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: CoveTheme.darkTheme,
          home: const ChangelogScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // AppBar title & button
      expect(find.text('Changelog & Updates'), findsOneWidget);
      expect(find.text("What's Fresh"), findsOneWidget);

      // Intro header card
      expect(find.text('Cove Evolution'), findsOneWidget);
      expect(find.textContaining(kCoveCurrentAppVersion), findsOneWidget);

      // Timeline Items
      expect(find.text('RELEASE TIMELINE'), findsOneWidget);
      expect(find.text('Home-Scoped Budget, Currency & Reminders'), findsOneWidget);
      expect(find.text('Contextual Notification Deep Linking'), findsOneWidget);
      expect(find.text('Sep 25, 2026'), findsWidgets);
      expect(find.text('EMI Tracker & Loan Foreclosure'), findsOneWidget);
      expect(find.text('Sep 20, 2026'), findsWidgets);
      expect(find.text('Calendar-First Sanctuary & Today Home'), findsOneWidget);
      expect(find.text('Sep 19, 2026'), findsWidgets);
    });

    testWidgets('Tapping What\'s Fresh button in AppBar opens WhatsFreshModal', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: CoveTheme.darkTheme,
          home: const ChangelogScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final whatsFreshBtn = find.widgetWithText(CovePillButton, "What's Fresh");
      expect(whatsFreshBtn, findsOneWidget);

      await tester.tap(whatsFreshBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Modal is now displayed
      expect(find.byType(WhatsFreshModal), findsOneWidget);
      expect(find.text("WHAT'S FRESH · v1.0"), findsOneWidget);
    });
  });
}
