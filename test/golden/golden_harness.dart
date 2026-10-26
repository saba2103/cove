// Shared harness for Cove goldens.
//
// Every screen gets four goldens: dark and light, at phone width and at the
// Fold's cover width. Page content is capped at CoveSize.maxContent and centred,
// so a fifth "wide" golden proves the cap holds on the Fold's inner screen.
//
// Fonts are loaded from disk — never from the network — so goldens are identical
// on your machine, Ancy's and CI.
import 'dart:io';
import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:google_fonts/google_fonts.dart';

/// Default fixed clock for all golden tests: 2026-10-15 10:30 (a Thursday
/// morning, matching the fixture's `_kFixedDate`).
final Clock kDefaultGoldenClock = Clock.fixed(DateTime(2026, 10, 15, 10, 30));

/// Widths Cove must survive. Named for what they are, not for a device.
class CoveWidth {
  static const cover = Size(320, 780);   // Fold 7 folded — the narrowest real case
  static const phone = Size(411, 914);   // Pixel 6 — the anchor
  static const wide  = Size(840, 900);   // Fold 7 open — proves the maxContent cap
}

String _resolveFlutterRoot() {
  final envRoot = Platform.environment['FLUTTER_ROOT'];
  if (envRoot != null && envRoot.isNotEmpty) {
    return envRoot;
  }
  // Fallback when invoked via `<FLUTTER_ROOT>/bin/cache/dart-sdk/bin/dart test`
  final execDir = File(Platform.resolvedExecutable).parent;
  if (execDir.path.endsWith('/bin/cache/dart-sdk/bin') ||
      execDir.path.endsWith(r'\bin\cache\dart-sdk\bin')) {
    return execDir.parent.parent.parent.parent.path;
  }
  fail(
    'Unable to resolve FLUTTER_ROOT from environment or Platform.resolvedExecutable '
    '(${Platform.resolvedExecutable}). Cannot load MaterialIcons-Regular.otf for goldens.',
  );
}

Future<void> loadCoveFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;

  final flutterRoot = _resolveFlutterRoot();
  final materialIconsPath =
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final materialIconsFile = File(materialIconsPath);
  if (!materialIconsFile.existsSync()) {
    fail(
      'MaterialIcons-Regular.otf not found at "$materialIconsPath" '
      '(resolved from FLUTTER_ROOT="$flutterRoot"). '
      'Refusing to generate or compare goldens with tofu icon boxes.',
    );
  }
  final materialLoader = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(ByteData.sublistView(materialIconsFile.readAsBytesSync())),
    );
  await materialLoader.load();

  const families = <String, List<String>>{
    'PlusJakartaSans': [
      'assets/fonts/PlusJakartaSans-Regular.ttf',
      'assets/fonts/PlusJakartaSans-Medium.ttf',
      'assets/fonts/PlusJakartaSans-SemiBold.ttf',
      'assets/fonts/PlusJakartaSans-Bold.ttf',
    ],
    'LibreBodoni': [
      'assets/fonts/LibreBodoni-Regular.ttf',
      'assets/fonts/LibreBodoni-Italic.ttf',
      'assets/fonts/LibreBodoni-Medium.ttf',
    ],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    var hasAny = false;
    for (final path in entry.value) {
      final file = File(path);
      if (!file.existsSync()) continue;
      hasAny = true;
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
    if (hasAny) {
      await loader.load();
    }
  }
}

/// Wraps [child] in the same centred 540dp constraint that `AppShell` applies
/// on non-web builds.
Widget wrapInAppShellConstraint(Widget child) => Builder(
      builder: (context) => ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: child,
          ),
        ),
      ),
    );

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
  Widget Function(Widget)? wrap,
  Set<String> allowedOverflows = const {},
  Clock? clock,
  EdgeInsets insets = EdgeInsets.zero,
}) async {
  await loadCoveFonts();
  await withClock(clock ?? kDefaultGoldenClock, () async {
    for (final size in widths) {
      final w = size == CoveWidth.cover ? 'cover' : size == CoveWidth.wide ? 'wide' : 'phone';
      final pairKey = '$name.$w';
      for (final mode in modes) {
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          final isOverflow =
              details.exceptionAsString().contains('A RenderFlex overflowed by');
          if (isOverflow && allowedOverflows.contains(pairKey)) {
            return;
          }
          originalOnError?.call(details);
        };
        try {
          tester.view
            ..physicalSize = size * 2
            ..devicePixelRatio = 2.0;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(ProviderScope(
            overrides: overrides,
            child: MediaQuery(
              // Goldens pin textScaler. A separate 200% test covers WCAG 1.4.4.
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.0),
                padding: insets,
                viewPadding: insets,
              ),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: coveThemeFor(mode),
                builder: (context, navChild) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: size,
                    textScaler: const TextScaler.linear(1.0),
                    padding: insets,
                    viewPadding: insets,
                  ),
                  child: navChild ?? const SizedBox.shrink(),
                ),
                home: wrap != null ? wrap(child) : child,
              ),
            ),
          ));
          await tester.pumpAndSettle();
          final m = mode == Brightness.dark ? 'dark' : 'light';
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$name.$w.$m.png'),
          );
        } finally {
          FlutterError.onError = originalOnError;
        }
      }
    }
  });
}

/// Resolves the Cove theme for [b] with both [CoveTokens] and legacy [CoveColors].
ThemeData coveThemeFor(Brightness b) =>
    b == Brightness.dark ? CoveTheme.darkTheme : CoveTheme.lightTheme;
