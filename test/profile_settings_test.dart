import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_pill_button.dart';
import 'package:cove/features/profile/delete_data_dialog.dart';
import 'package:cove/features/profile/home_metadata_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/profile_screen.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testProfile = const UserProfileState(
    displayName: 'Alex Rivers',
    email: 'alex.rivers@gmail.com',
    hasCustomName: true,
  );

  final testHome = LocalHome(
    id: 'home-haven',
    name: 'Haven',
    description: 'Our quiet brownstone in Brooklyn',
    icon: 'cottage',
    currency: 'USD',
    createdAt: DateTime(2023, 1, 1),
    createdBy: 'user-alex',
  );

  final testHomes = [
    testHome,
    LocalHome(
      id: 'home-cabin',
      name: 'Upstate Cabin',
      description: 'Weekend retreat in Catskills',
      icon: 'cabin',
      currency: 'USD',
      createdAt: DateTime(2024, 6, 1),
      createdBy: 'user-alex',
    ),
  ];

  final now = DateTime.now();
  final anniversaryDate = DateTime(now.year - 3, now.month - 4, now.day);
  final testHomeMetadata = HomeMetadataState(
    homeId: 'home-haven',
    anniversaryDate: anniversaryDate,
    formattedTogetherDuration: HomeMetadataState.formatDuration(anniversaryDate),
  );

  final testBackupStatus = BackupStatusState(
    lastBackupTime: DateTime.now().subtract(const Duration(hours: 14)),
    pendingEventCount: 14,
    pendingBytesKb: 8.2,
    backupTimeWindow: '02:00 AM',
  );

  Widget createSubject({
    ThemeMode themeMode = ThemeMode.dark,
    UserProfileState? profile,
    LocalHome? home,
    List<LocalHome>? homes,
    HomeMetadataState? metadata,
    BackupStatusState? backup,
  }) {
    return ProviderScope(
      child: MaterialApp(
        theme: CoveTheme.lightTheme,
        darkTheme: CoveTheme.darkTheme,
        themeMode: themeMode,
        home: Scaffold(
          body: ProfileScreen(
            initialProfile: profile ?? testProfile,
            initialHome: home ?? testHome,
            initialHomes: homes ?? testHomes,
            initialHomeMetadata: metadata ?? testHomeMetadata,
            initialBackupStatus: backup ?? testBackupStatus,
          ),
        ),
      ),
    );
  }

  void setupViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('HomeMetadataState Duration Formatting', () {
    test('returns null for null date or future date', () {
      expect(HomeMetadataState.formatDuration(null), isNull);
      final future = DateTime.now().add(const Duration(days: 30));
      expect(HomeMetadataState.formatDuration(future), isNull);
    });

    test('returns month format for duration under one year', () {
      final now = DateTime.now();
      final fiveMonthsAgo = DateTime(now.year, now.month - 5, now.day);
      final result = HomeMetadataState.formatDuration(fiveMonthsAgo);
      expect(result, contains('Together for 5 months'));
    });

    test('returns year format for exact whole years', () {
      final now = DateTime.now();
      final twoYearsAgo = DateTime(now.year - 2, now.month, now.day);
      final result = HomeMetadataState.formatDuration(twoYearsAgo);
      expect(result, contains('Together for 2 years'));
    });

    test('returns combined year and month format', () {
      final now = DateTime.now();
      final threeYearsFourMonths = DateTime(now.year - 3, now.month - 4, now.day);
      final result = HomeMetadataState.formatDuration(threeYearsFourMonths);
      expect(result, contains('Together for 3 years, 4 months'));
    });
  });

  group('UserProfileState copyWith', () {
    test('updates custom display name and avatar URL', () {
      final state = const UserProfileState(
        displayName: 'Sam',
        email: 'sam@cove.local',
      );
      final updated = state.copyWith(
        displayName: 'Sammy',
        avatarUrl: 'https://example.com/avatar.jpg',
        hasCustomName: true,
        hasCustomAvatar: true,
      );
      expect(updated.displayName, 'Sammy');
      expect(updated.avatarUrl, 'https://example.com/avatar.jpg');
      expect(updated.hasCustomName, isTrue);
      expect(updated.hasCustomAvatar, isTrue);

      final cleared = updated.copyWith(clearAvatar: true);
      expect(cleared.avatarUrl, isNull);
      expect(cleared.hasCustomAvatar, isFalse);
    });
  });

  group('ProfileScreen Rendering & Functionality', () {
    testWidgets('renders Profile section with display name, initials, and email', (tester) async {
      setupViewport(tester);

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Alex Rivers'), findsAtLeastNWidgets(1));
      expect(find.text('alex.rivers@gmail.com'), findsOneWidget);
      expect(find.text('A'), findsWidgets); // Initials avatar
    });

    testWidgets('renders About Us section with Home name, description and anniversary duration', (tester) async {
      setupViewport(tester);

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.text('ABOUT US'), findsOneWidget);
      expect(find.text('Haven'), findsWidgets);
      expect(find.text('Our quiet brownstone in Brooklyn'), findsOneWidget);
      expect(find.textContaining('Together for 3 years, 4 months'), findsOneWidget);
    });

    testWidgets('renders Preferences with 3-way Theme switcher, currency and 5 notification toggles', (tester) async {
      setupViewport(tester);

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Currency & Locale'), findsOneWidget);
      expect(find.text('PARTNER NOTIFICATIONS'), findsOneWidget);
      expect(find.text('Shared Lists'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Commitments'), findsOneWidget);
      expect(find.text('Habits & Rhythms'), findsOneWidget);
      expect(find.text('Shared Calendar'), findsOneWidget);
    });

    testWidgets('renders Backup & Restore section with status and Back up now button', (tester) async {
      setupViewport(tester);

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.text('BACKUP & RESTORE'), findsOneWidget);
      expect(find.text('Last Backup'), findsOneWidget);
      expect(find.textContaining('Backed up'), findsOneWidget);
      expect(find.text('Ready for Next Backup'), findsOneWidget);
      expect(find.text('Backup Window'), findsOneWidget);
      expect(find.text('Back Up Now'), findsOneWidget);

      await tester.tap(find.text('Back Up Now'));
      await tester.pumpAndSettle();
      expect(find.text('Backing up...'), findsNothing); // Completes cleanly
    });

    testWidgets('renders Household section with members and Switch Home when multiple homes', (tester) async {
      setupViewport(tester);

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.text('HOUSEHOLD'), findsOneWidget);
      expect(find.text('Switch Home'), findsOneWidget);
      expect(find.text('Invite Partner QR'), findsOneWidget);
      expect(find.text('Alex Rivers (You)'), findsOneWidget);
      expect(find.text('Partner'), findsOneWidget);
      expect(find.text('Leave Home'), findsOneWidget);
    });

    testWidgets('Leave Home dialog shows calm leaving a group explanation without data wipe', (tester) async {
      setupViewport(tester);

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Leave Home'));
      await tester.pumpAndSettle();

      expect(find.text('Leave Haven?'), findsOneWidget);
      expect(
        find.textContaining('You will remove the encryption key and access to this Home from this device.'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Remove partner dialog confirms partner removal mental model', (tester) async {
      setupViewport(tester);

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Tap 'Remove' text button for Partner
      final removeBtn = find.text('Remove');
      expect(removeBtn, findsOneWidget);
      await tester.tap(removeBtn);
      await tester.pumpAndSettle();

      expect(find.text('Remove Partner?'), findsOneWidget);
      expect(
        find.textContaining('matching the mental model of leaving a group.'),
        findsOneWidget,
      );

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Delete Local Data requires typing DELETE before enabling action', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => DeleteDataDialog.show(context),
                  child: const Text('Open Danger'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Danger'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Local Data'), findsOneWidget);
      expect(find.text('Type "DELETE" below to confirm:'), findsOneWidget);

      // Verify button is disabled initially
      final deleteBtnFinder = find.widgetWithText(CovePillButton, 'Delete Everything');
      expect(deleteBtnFinder, findsOneWidget);
      var button = tester.widget<CovePillButton>(deleteBtnFinder);
      expect(button.onPressed, isNull);

      // Enter lowercase "delete" - should remain disabled
      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pumpAndSettle();
      button = tester.widget<CovePillButton>(deleteBtnFinder);
      expect(button.onPressed, isNull);

      // Enter exact uppercase "DELETE" - should become enabled
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pumpAndSettle();
      button = tester.widget<CovePillButton>(deleteBtnFinder);
      expect(button.onPressed, isNotNull);

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('renders cleanly in both Light and Dark themes', (tester) async {
      setupViewport(tester);

      // Dark Theme
      await tester.pumpWidget(createSubject(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);

      // Light Theme
      await tester.pumpWidget(createSubject(themeMode: ThemeMode.light));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
