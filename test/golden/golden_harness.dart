// Shared harness for Cove goldens.
//
// Every screen gets four goldens: dark and light, at phone width and at the
// Fold's cover width. Page content is capped at CoveSize.maxContent and centred,
// so a fifth "wide" golden proves the cap holds on the Fold's inner screen.
//
// Fonts are loaded from disk — never from the network — so goldens are identical
// on your machine, Ancy's and CI.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:google_fonts/google_fonts.dart';

/// Widths Cove must survive. Named for what they are, not for a device.
class CoveWidth {
  static const cover = Size(320, 780);   // Fold 7 folded — the narrowest real case
  static const phone = Size(411, 914);   // Pixel 6 — the anchor
  static const wide  = Size(840, 900);   // Fold 7 open — proves the maxContent cap
}

Future<void> loadCoveFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final f in const [
    ['PlusJakartaSans', 'assets/fonts/PlusJakartaSans-Regular.ttf'],
    ['PlusJakartaSans', 'assets/fonts/PlusJakartaSans-Medium.ttf'],
    ['PlusJakartaSans', 'assets/fonts/PlusJakartaSans-SemiBold.ttf'],
    ['PlusJakartaSans', 'assets/fonts/PlusJakartaSans-Bold.ttf'],
    ['BodoniModa', 'assets/fonts/BodoniModa-Medium.ttf'],
  ]) {
    final file = File(f[1]);
    if (!file.existsSync()) continue;
    final loader = FontLoader(f[0])
      ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
  }
}

/// Pumps [child] and writes one golden per (width x brightness) pair.
///
///   await goldenMatrix(tester, 'expenses', const ExpensesScreen());
///
/// Produces test/golden/goldens/expenses.{cover,phone,wide}.{dark,light}.png
Future<void> goldenMatrix(
  WidgetTester tester,
  String name,
  Widget child, {
  List<Size> widths = const [CoveWidth.phone, CoveWidth.cover, CoveWidth.wide],
  List<Brightness> modes = const [Brightness.dark, Brightness.light],
  List<Override> overrides = const [],
}) async {
  await loadCoveFonts();
  for (final size in widths) {
    for (final mode in modes) {
      tester.view
        ..physicalSize = size * 2
        ..devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: MediaQuery(
          // Goldens pin textScaler. A separate 200% test covers WCAG 1.4.4.
          data: MediaQueryData(size: size, textScaler: const TextScaler.linear(1.0)),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: coveThemeFor(mode),
            home: child,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final w = size == CoveWidth.cover ? 'cover' : size == CoveWidth.wide ? 'wide' : 'phone';
      final m = mode == Brightness.dark ? 'dark' : 'light';
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name.$w.$m.png'),
      );
    }
  }
}

/// Replace with the real factory once lib/core/theme/cove_theme.dart reads CoveTokens.
ThemeData coveThemeFor(Brightness b) => throw UnimplementedError(
    'Wire this to cove_theme.dart in Phase 1, step 3.');
