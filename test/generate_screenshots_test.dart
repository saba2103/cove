import 'dart:io';
import 'dart:ui' as ui;
import 'package:cove/main.dart';
import 'package:cove/core/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Capture Dark and Light Theme Showcase Screenshots',
      (WidgetTester tester) async {
    // Load local font files directly from disk into FontLoader
    Future<void> loadFontFromFile(String family, String path) async {
      final file = File(path);
      if (file.existsSync()) {
        final loader = FontLoader(family);
        final bytes = file.readAsBytesSync();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
      }
    }

    await loadFontFromFile('GeneralSans', 'assets/fonts/GeneralSans-Regular.ttf');
    await loadFontFromFile('GeneralSans', 'assets/fonts/GeneralSans-Medium.ttf');
    await loadFontFromFile('GeneralSans', 'assets/fonts/GeneralSans-Semibold.ttf');
    await loadFontFromFile('GeneralSans', 'assets/fonts/GeneralSans-Bold.ttf');
    await loadFontFromFile('BodoniModa', 'assets/fonts/BodoniModa-Medium.ttf');

    // Set viewport dimensions (500 x 1050 pt)
    tester.view.physicalSize = const Size(500 * 2, 1050 * 2);
    tester.view.devicePixelRatio = 2.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const artifactDir =
        '/Users/saba/.gemini/antigravity/brain/0ec1480b-ee13-4012-8b4f-09d7fa81bb3d';

    // 1. Dark Theme Screenshot
    final darkKey = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeModeProvider.overrideWith(() => _StaticThemeNotifier(ThemeMode.dark)),
        ],
        child: RepaintBoundary(
          key: darkKey,
          child: const CoveApp(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final darkBoundary =
        darkKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image darkImage = await darkBoundary.toImage(pixelRatio: 2.0);
    final darkByteData =
        await darkImage.toByteData(format: ui.ImageByteFormat.png);
    File('$artifactDir/cove_dark_showcase.png')
        .writeAsBytesSync(darkByteData!.buffer.asUint8List());

    // 2. Light Theme Screenshot
    final lightKey = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeModeProvider.overrideWith(() => _StaticThemeNotifier(ThemeMode.light)),
        ],
        child: RepaintBoundary(
          key: lightKey,
          child: const CoveApp(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final lightBoundary =
        lightKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image lightImage = await lightBoundary.toImage(pixelRatio: 2.0);
    final lightByteData =
        await lightImage.toByteData(format: ui.ImageByteFormat.png);
    File('$artifactDir/cove_light_showcase.png')
        .writeAsBytesSync(lightByteData!.buffer.asUint8List());
  });
}

class _StaticThemeNotifier extends ThemeModeNotifier {
  final ThemeMode initialMode;
  _StaticThemeNotifier(this.initialMode);

  @override
  ThemeMode build() => initialMode;
}
