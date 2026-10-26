import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/lists/list_controller.dart';
import 'package:cove/features/lists/lists_screen.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

final _kFixedDate = DateTime(2026, 10, 15, 10, 30);
final _kFixedCreatedAt = DateTime(2026, 10, 1, 9, 0);

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

final _kSeedLists = <LocalList>[
  LocalList(
    id: 'list_1',
    homeId: 'home_1',
    name: 'Groceries',
    isArchived: false,
    createdAt: _kFixedCreatedAt,
    createdBy: 'user_alex',
  ),
  LocalList(
    id: 'list_2',
    homeId: 'home_1',
    name: 'Weekend Errands',
    isArchived: false,
    createdAt: _kFixedCreatedAt,
    createdBy: 'user_sarah',
  ),
];

final _kSeedListItems = <LocalListItem>[
  LocalListItem(
    id: 'item_1',
    homeId: 'home_1',
    listId: 'list_1',
    title: 'Sourdough country loaf',
    notes: 'From Subko Cacao',
    dueDate: _kFixedDate,
    isCompleted: false,
    createdAt: _kFixedCreatedAt,
    createdBy: 'user_alex',
  ),
  LocalListItem(
    id: 'item_2',
    homeId: 'home_1',
    listId: 'list_1',
    title: 'Organic oat milk (2 cartons)',
    isCompleted: true,
    completedAt: _kFixedDate,
    completedBy: 'user_sarah',
    createdAt: _kFixedCreatedAt,
    createdBy: 'user_sarah',
  ),
];

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
  Future<int> purgeOrphanedAndArchivedListItems([String? activeHomeId]) async =>
      0;

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

class _FakeActivePartnerNotifier extends ActiveHomePartnerNotifier {
  @override
  bool build() => true;
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => _kAlexProfile;
}

class _FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() => _kSarahPartnerProfile;
}

class _StubListController extends ListController {
  _StubListController(super.ref);

  @override
  Future<void> ensureDefaultLists() async {}
}

List<Override> _createOverrides() {
  final fakeStorage = _FakeSecureStorage();
  final keyStore = HomeKeyStore(storage: fakeStorage);
  final stubDb = _StubAppDatabase();

  return [
    appDatabaseProvider.overrideWithValue(stubDb),
    homeKeyStoreProvider.overrideWithValue(keyStore),
    authProvider.overrideWith(_FakeAuthNotifier.new),
    activeHomeIdProvider.overrideWith(_FakeActiveHomeNotifier.new),
    activeHomeHasPartnerProvider.overrideWith(_FakeActivePartnerNotifier.new),
    userProfileProvider.overrideWith(_FakeUserProfileNotifier.new),
    partnerProfileProvider.overrideWith(_FakePartnerProfileNotifier.new),
    listControllerProvider.overrideWith((ref) => _StubListController(ref)),
    activeHomeListsProvider.overrideWith((ref) => Stream.value(_kSeedLists)),
    activeHomeAllListItemsProvider.overrideWith(
      (ref) => Stream.value(_kSeedListItems),
    ),
    activeHomeListItemsProvider('list_1').overrideWith(
      (ref) => Stream.value(
        _kSeedListItems.where((i) => i.listId == 'list_1').toList(),
      ),
    ),
    activeHomeListItemsProvider('list_2').overrideWith(
      (ref) => Stream.value(
        _kSeedListItems.where((i) => i.listId == 'list_2').toList(),
      ),
    ),
    activeHomeOutboxProvider.overrideWith(
      (ref) => Stream.value(const <LocalOutboxEvent>[]),
    ),
  ];
}

const Set<String> _kKnownLegacyOverflows = {};

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Batch 4.1g Lists Goldens (3 widths × 2 modes)', () {
    testWidgets('lists_41g_lists_screen', (tester) async {
      await goldenMatrix(
        tester,
        'lists_41g_lists_screen',
        ListsScreen(
          initialLists: _kSeedLists,
          initialItems: _kSeedListItems,
        ),
        overrides: _createOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });
  });
}
