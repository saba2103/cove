import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/changelog/changelog_models.dart';
import 'package:cove/features/changelog/changelog_screen.dart';
import 'package:cove/features/changelog/whats_fresh_modal.dart';
import 'package:cove/features/changelog/widgets/changelog_preview_mockup.dart';
import 'package:cove/features/home/about_cove_screen.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

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

class _FakeActivePartnerNotifier extends ActiveHomePartnerNotifier {
  @override
  bool build() => true;
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

List<Override> _createOverrides() {
  final stubDb = _StubAppDatabase();

  return [
    appDatabaseProvider.overrideWithValue(stubDb),
    authProvider.overrideWith(_FakeAuthNotifier.new),
    activeHomeIdProvider.overrideWith(_FakeActiveHomeNotifier.new),
    activeHomeProvider.overrideWith((ref) => Stream.value(_kSeedHome1)),
    userHomesProvider.overrideWith(
      (ref) => Stream.value([_kSeedHome1, _kSeedHome2]),
    ),
    activeHomeHasPartnerProvider.overrideWith(_FakeActivePartnerNotifier.new),
    partnerProfileProvider.overrideWith(_FakePartnerProfileNotifier.new),
    userProfileProvider.overrideWith(_FakeUserProfileNotifier.new),
    currencyPreferenceProvider.overrideWith(_FakeCurrencyNotifier.new),
  ];
}

const Set<String> _kKnownLegacyOverflows = {};

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('4.1c before/after golden: about_cove_screen', (tester) async {
    await goldenMatrix(
      tester,
      'about_41c_about_cove_screen',
      const AboutCoveScreen(),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1c before/after golden: changelog_screen', (tester) async {
    await goldenMatrix(
      tester,
      'about_41c_changelog_screen',
      const ChangelogScreen(),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1c before/after golden: whats_fresh_modal', (tester) async {
    await goldenMatrix(
      tester,
      'about_41c_whats_fresh_modal',
      const Scaffold(
        body: WhatsFreshModal(),
      ),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1c before/after golden: changelog_preview_mockup',
      (tester) async {
    await goldenMatrix(
      tester,
      'about_41c_changelog_preview_mockup',
      const Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChangelogPreviewMockup(
                  previewType: ChangelogPreviewType.helicopterView,
                ),
                SizedBox(height: 16),
                ChangelogPreviewMockup(
                  previewType: ChangelogPreviewType.smartDecimals,
                ),
                SizedBox(height: 16),
                ChangelogPreviewMockup(
                  previewType: ChangelogPreviewType.profileStudio,
                ),
              ],
            ),
          ),
        ),
      ),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });
}
