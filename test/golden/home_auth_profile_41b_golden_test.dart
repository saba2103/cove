import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/auth/sign_in_screen.dart';
import 'package:cove/features/backup/drive_backup_controller.dart';
import 'package:cove/features/backup/drive_backup_section.dart';
import 'package:cove/features/backup/drive_backup_sheets.dart';
import 'package:cove/features/home/create_home_screen.dart';
import 'package:cove/features/home/home_switcher_sheet.dart';
import 'package:cove/features/home/join_home_screen.dart';
import 'package:cove/features/home/onboarding_choice_screen.dart';
import 'package:cove/features/profile/currency_selector_sheet.dart';
import 'package:cove/features/profile/delete_data_dialog.dart';
import 'package:cove/features/profile/edit_home_dialog.dart';
import 'package:cove/features/profile/edit_partner_profile_dialog.dart';
import 'package:cove/features/profile/edit_profile_dialog.dart';
import 'package:cove/features/profile/home_metadata_controller.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_backup_remote.dart';
import 'golden_harness.dart';

final _kFixedDate = DateTime(2026, 10, 15, 10, 30);
final _kFixedCreatedAt = DateTime(2026, 1, 10, 9, 0);
final _kFixedAnniversary = DateTime(2023, 6, 15);

const _kAlexUser = CoveUser(
  id: 'user_alex',
  email: 'alex@cove.test',
  displayName: 'Alex',
);

const _kAlexProfile = UserProfileState(
  displayName: 'Alex',
  email: 'alex@cove.test',
  hasCustomName: true,
);

const _kSarahPartnerProfile = PartnerProfileState(
  displayName: 'Sarah',
  userId: 'user_sarah',
);

final _kSeedHome1 = LocalHome(
  id: 'home_1',
  name: 'Our Home',
  description: 'Alex & Sarah Sanctuary',
  icon: 'cottage',
  currency: 'INR',
  monthlyBudget: 85000.0,
  anniversaryDate: _kFixedAnniversary,
  createdAt: _kFixedCreatedAt,
  createdBy: 'user_alex',
);

final _kSeedHome2 = LocalHome(
  id: 'home_2',
  name: 'Weekend Cabin',
  description: 'Alibaug Getaway',
  icon: 'cabin',
  currency: 'INR',
  createdAt: _kFixedCreatedAt,
  createdBy: 'user_alex',
);

final _kSeedBackupState = DriveBackupState(
  isLoaded: true,
  isConnected: true,
  accountEmail: 'alex@cove.test',
  hasPassphrase: true,
  lastBackupAt: _kFixedDate,
  lastBackupSizeBytes: 48 * 1024,
  autoEnabled: true,
  autoTime: const TimeOfDay(hour: 2, minute: 0),
  autoWifiOnly: true,
  autoLastRunAt: _kFixedDate,
);

class _FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _map = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _map[key] = value;
    } else {
      _map.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _map[key];
}

class _StubAppDatabase extends Fake implements AppDatabase {
  @override
  Future<void> close() async {}
}

class _FakeAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  @override
  AsyncValue<CoveUser?> build() => const AsyncData(_kAlexUser);

  @override
  Future<void> signInWithGoogle() async {}

  @override
  void signInWithDemoUser([
    String name = 'Alex',
    String email = 'alex@cove.local',
  ]) {}

  @override
  Future<void> signOut() async {}
}

class _FakeActiveHomeNotifier extends Notifier<String?>
    implements ActiveHomeNotifier {
  @override
  String? build() => 'home_1';

  @override
  void setActiveHome(String homeId) => state = homeId;
}

class _FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() => _kSarahPartnerProfile;
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => _kAlexProfile;
}

class _FakeCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() =>
      const CurrencyOption(code: 'INR', symbol: '₹', name: 'Indian Rupee');
}

class _FakeHomeMetadataNotifier extends HomeMetadataNotifier {
  @override
  HomeMetadataState build() => HomeMetadataState(
        homeId: 'home_1',
        anniversaryDate: _kFixedAnniversary,
        formattedTogetherDuration: 'Together for 3 years, 4 months',
      );
}

List<Override> _createOverrides() {
  final fakeStorage = _FakeSecureStorage();
  final keyStore = HomeKeyStore(storage: fakeStorage);
  final stubDb = _StubAppDatabase();

  return [
    appDatabaseProvider.overrideWithValue(stubDb),
    homeKeyStoreProvider.overrideWithValue(keyStore),
    backupRemoteProvider.overrideWithValue(FakeBackupRemote()),
    backupSchedulerProvider.overrideWithValue(FakeBackupScheduler()),
    authProvider.overrideWith(_FakeAuthNotifier.new),
    activeHomeIdProvider.overrideWith(_FakeActiveHomeNotifier.new),
    activeHomeProvider.overrideWith((ref) => Stream.value(_kSeedHome1)),
    userHomesProvider.overrideWith(
      (ref) => Stream.value([_kSeedHome1, _kSeedHome2]),
    ),
    partnerProfileProvider.overrideWith(_FakePartnerProfileNotifier.new),
    userProfileProvider.overrideWith(_FakeUserProfileNotifier.new),
    currencyPreferenceProvider.overrideWith(_FakeCurrencyNotifier.new),
    homeMetadataProvider.overrideWith(_FakeHomeMetadataNotifier.new),
  ];
}

Widget _sheetHost(Widget sheet) => Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: sheet,
      ),
    );

class _EditHomeDialogHost extends ConsumerWidget {
  const _EditHomeDialogHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(activeHomeProvider).value;
    if (home == null) return const SizedBox.shrink();
    return _sheetHost(const EditHomeDialog());
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('4.1b before/after golden: onboarding_choice_screen',
      (tester) async {
    await goldenMatrix(
      tester,
      'home_41b_onboarding_choice_screen',
      const OnboardingChoiceScreen(),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
    );
  });

  testWidgets('4.1b before/after golden: join_home_screen', (tester) async {
    await goldenMatrix(
      tester,
      'home_41b_join_home_screen',
      const JoinHomeScreen(initialShowManualInput: true),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
    );
  });

  testWidgets('4.1b before/after golden: create_home_screen', (tester) async {
    await goldenMatrix(
      tester,
      'home_41b_create_home_screen',
      const CreateHomeScreen(),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
    );
  });

  testWidgets('4.1b before/after golden: home_switcher_sheet', (tester) async {
    await goldenMatrix(
      tester,
      'home_41b_home_switcher_sheet',
      _sheetHost(const HomeSwitcherSheet()),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
    );
  });

  testWidgets('4.1b before/after golden: sign_in_screen', (tester) async {
    await goldenMatrix(
      tester,
      'home_41b_sign_in_screen',
      const SignInScreen(),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
      allowedOverflows: const {'home_41b_sign_in_screen.cover'},
    );
  });

  testWidgets('4.1b before/after golden: edit_profile_dialog', (tester) async {
    await goldenMatrix(
      tester,
      'home_41b_edit_profile_dialog',
      _sheetHost(const EditProfileDialog()),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
    );
  });

  testWidgets('4.1b before/after golden: edit_home_dialog', (tester) async {
    await goldenMatrix(
      tester,
      'home_41b_edit_home_dialog',
      const _EditHomeDialogHost(),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
    );
  });

  testWidgets('4.1b before/after golden: edit_partner_profile_dialog',
      (tester) async {
    await goldenMatrix(
      tester,
      'home_41b_edit_partner_profile_dialog',
      _sheetHost(const EditPartnerProfileDialog()),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
    );
  });

  testWidgets('4.1b before/after golden: delete_data_dialog', (tester) async {
    await goldenMatrix(
      tester,
      'home_41b_delete_data_dialog',
      const Scaffold(
        body: Center(
          child: DeleteDataDialog(),
        ),
      ),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
    );
  });

  testWidgets('4.1b before/after golden: currency_selector_sheet',
      (tester) async {
    await goldenMatrix(
      tester,
      'home_41b_currency_selector_sheet',
      _sheetHost(const CurrencySelectorSheet()),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
    );
  });

  testWidgets('4.1b before/after golden: drive_backup_sheets', (tester) async {
    await goldenMatrix(
      tester,
      'home_41b_drive_backup_sheets',
      _sheetHost(const BackupPassphraseSheet()),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
    );
  });

  testWidgets('4.1b before/after golden: drive_backup_section', (tester) async {
    await goldenMatrix(
      tester,
      'home_41b_drive_backup_section',
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: DriveBackupSection(initialState: _kSeedBackupState),
        ),
      ),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
    );
  });
}
