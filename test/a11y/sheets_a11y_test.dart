import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a11y_fixtures.dart';
import 'a11y_harness.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  registerA11ySurfaceTests(
    'Phase 5 A11y — Sheets, Modals & Dialogs (411dp, light & dark)',
    buildSheetA11ySurfaces(),
  );
}
