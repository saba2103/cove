import 'dart:io';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_brand_mark.dart';
import 'package:cove/core/widgets/cove_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CoveSplashScreen & App Identity Tests', () {
    testWidgets('1. Splash screen renders Cove brand mark, Bodoni title, and serene tagline',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CoveTheme.darkTheme,
          home: const CoveSplashScreen(),
        ),
      );

      // Fast forward past entrance animations
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(CoveBrandMark), findsOneWidget);
      expect(find.text('Cove'), findsOneWidget);
      expect(find.text('A quiet operating system for two'), findsOneWidget);
      // Default splash doesn't show spinner to stay calm
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('2. Splash screen shows progress indicator when showProgress is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CoveTheme.darkTheme,
          home: const CoveSplashScreen(
            message: 'Syncing your home...',
            showProgress: true,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Syncing your home...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('3. Dual-theme verification: renders in both Light and Dark modes',
        (tester) async {
      // Light Mode
      await tester.pumpWidget(
        MaterialApp(
          theme: CoveTheme.lightTheme,
          home: const CoveSplashScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.text('Cove'), findsOneWidget);

      // Dark Mode
      await tester.pumpWidget(
        MaterialApp(
          theme: CoveTheme.darkTheme,
          home: const CoveSplashScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.text('Cove'), findsOneWidget);
    });

    testWidgets('4. minDuration triggers onFinished callback accurately',
        (tester) async {
      bool finished = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: CoveTheme.darkTheme,
          home: CoveSplashScreen(
            minDuration: const Duration(milliseconds: 500),
            onFinished: () {
              finished = true;
            },
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(finished, isFalse);

      await tester.pump(const Duration(milliseconds: 350));
      expect(finished, isTrue);
    });

    test('5. AndroidManifest.xml uses capitalized "Cove" as application label', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      expect(content.contains('android:label="Cove"'), isTrue);
      expect(content.contains('android:label="cove"'), isFalse);
    });

    test('6. Adaptive icon files exist in mipmap-anydpi-v26 and res/values/colors.xml', () {
      expect(File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml').existsSync(), isTrue);
      expect(File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml').existsSync(), isTrue);
      expect(File('android/app/src/main/res/values/colors.xml').existsSync(), isTrue);
      expect(File('android/app/src/main/res/drawable/splash_emblem.png').existsSync(), isTrue);
      expect(File('android/app/src/main/res/drawable/launch_background.xml').existsSync(), isTrue);
      expect(File('android/app/src/main/res/drawable-v21/launch_background.xml').existsSync(), isTrue);
    });
  });
}
