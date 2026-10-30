// Shared harness for Cove Phase 5 accessibility tests (5.0+).
//
// Pumps every screen, sheet, and Add step at phone width (411x914, DPR 2.0) in
// both Brightness.light and Brightness.dark, with the overflow guard kept ON,
// and runs Flutter's three accessibility guideline matchers:
//   - androidTapTargetGuideline (48x48dp)
//   - labeledTapTargetGuideline
//   - textContrastGuideline
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden/golden_harness.dart';

export '../golden/golden_harness.dart'
    show
        CoveWidth,
        coveThemeFor,
        kDefaultGoldenClock,
        loadCoveFonts,
        wrapInAppShellConstraint;

/// The three Flutter accessibility guidelines audited across every surface.
enum A11yGuidelineKind {
  androidTapTarget(
    id: 'androidTapTargetGuideline',
    shortLabel: '48×48 tap target',
  ),
  labeledTapTarget(
    id: 'labeledTapTargetGuideline',
    shortLabel: 'labeled tap target',
  ),
  textContrast(
    id: 'textContrastGuideline',
    shortLabel: 'text contrast',
  );

  final String id;
  final String shortLabel;

  const A11yGuidelineKind({
    required this.id,
    required this.shortLabel,
  });

  AccessibilityGuideline get guideline {
    switch (this) {
      case A11yGuidelineKind.androidTapTarget:
        return androidTapTargetGuideline;
      case A11yGuidelineKind.labeledTapTarget:
        return labeledTapTargetGuideline;
      case A11yGuidelineKind.textContrast:
        return textContrastGuideline;
    }
  }
}

/// Key identifying a single `(Brightness, A11yGuidelineKind)` check on a surface.
typedef A11yCheckKey = (Brightness, A11yGuidelineKind);

/// Descriptor for a single screen, sheet, dialog, or Add-flow step audited in
/// `test/a11y/`.
class A11ySurface {
  final String id;
  final String title;
  final String category;
  final Widget Function() build;
  final List<Override> Function() overrides;
  final Widget Function(Widget)? wrap;
  final Clock? clock;
  final EdgeInsets insets;

  /// Optional fixed pump duration instead of `pumpAndSettle()` for surfaces
  /// with repeating animations (e.g. `CoveSplashScreen`).
  final Duration? customPumpDuration;

  /// Optional interaction callback after initial pump (e.g. opening an internal
  /// modal sheet or dialog).
  final Future<void> Function(WidgetTester tester)? afterPump;

  /// Explicit `skip:` reasons keyed by `(Brightness, A11yGuidelineKind)`.
  /// Any entry absent from this map runs actively in CI.
  final Map<A11yCheckKey, String> skips;

  const A11ySurface({
    required this.id,
    required this.title,
    required this.category,
    required this.build,
    required this.overrides,
    this.wrap,
    this.clock,
    this.insets = EdgeInsets.zero,
    this.customPumpDuration,
    this.afterPump,
    this.skips = const <A11yCheckKey, String>{},
  });
}

bool _fontsLoadedInIsolate = false;

Future<void> ensureA11yFontsLoaded() async {
  if (_fontsLoadedInIsolate) return;
  await loadCoveFonts();
  _fontsLoadedInIsolate = true;
}

/// Pumps [surface] at `CoveWidth.phone` (`411x914`) in [mode] with the overflow
/// guard active (`FlutterError.onError` is never suppressed).
Future<void> pumpA11ySurface(
  WidgetTester tester,
  A11ySurface surface,
  Brightness mode,
) async {
  await ensureA11yFontsLoaded();
  const size = CoveWidth.phone; // 411x914dp

  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await withClock(surface.clock ?? kDefaultGoldenClock, () async {
    final child = surface.build();
    await tester.pumpWidget(
      ProviderScope(
        overrides: surface.overrides(),
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: const TextScaler.linear(1.0),
            padding: surface.insets,
            viewPadding: surface.insets,
          ),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: coveThemeFor(mode),
            builder: (context, navChild) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: size,
                textScaler: const TextScaler.linear(1.0),
                padding: surface.insets,
                viewPadding: surface.insets,
              ),
              child: navChild ?? const SizedBox.shrink(),
            ),
            home: surface.wrap != null ? surface.wrap!(child) : child,
          ),
        ),
      ),
    );

    if (surface.customPumpDuration != null) {
      await tester.pump(surface.customPumpDuration);
    } else {
      await tester.pumpAndSettle();
    }

    if (surface.afterPump != null) {
      await surface.afterPump!(tester);
    }
  });
}

/// Registers `(light, dark) x (androidTapTarget, labeledTapTarget, textContrast)`
/// `testWidgets` cases for every surface in [surfaces].
void registerA11ySurfaceTests(
  String groupTitle,
  List<A11ySurface> surfaces,
) {
  group(groupTitle, () {
    for (final surface in surfaces) {
      for (final mode in const <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        final modeName = mode == Brightness.dark ? 'dark' : 'light';
        for (final kind in A11yGuidelineKind.values) {
          final skipReason = surface.skips[(mode, kind)];
          testWidgets(
            '${surface.id} [$modeName] — ${kind.id}',
            (tester) async {
              final semanticsHandle = tester.ensureSemantics();
              try {
                await pumpA11ySurface(tester, surface, mode);
                await expectLater(
                  tester,
                  meetsGuideline(kind.guideline),
                  skip: skipReason,
                );
                if (surface.customPumpDuration != null) {
                  await tester.pumpWidget(const SizedBox.shrink());
                }
              } finally {
                semanticsHandle.dispose();
              }
            },
          );
        }
      }
    }
  });
}
