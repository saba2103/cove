import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cove/core/theme/cove_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

Future<void> _pumpGolden(
  WidgetTester tester,
  String name,
  Size size,
  Widget Function(BuildContext context, CoveTokens cv) builder,
) async {
  await loadCoveFonts();
  for (final mode in const [Brightness.dark, Brightness.light]) {
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: const TextScaler.linear(1.0),
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: coveThemeFor(mode),
          home: Builder(
            builder: (context) => Scaffold(
              backgroundColor: context.cv.surfaceCanvas,
              body: builder(context, context.cv),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final m = mode == Brightness.dark ? 'dark' : 'light';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.$m.png'),
    );
  }
}

void main() {
  group('4.5a — squircle token, CoveShape, and theme', () {
    test('CoveRadius tokens match the 4.5a table with smoothing = 1.0', () {
      expect(CoveRadius.inline, 20.0);
      expect(CoveRadius.card, 24.0);
      expect(CoveRadius.hero, 32.0);
      expect(CoveRadius.sheet, 40.0);
      expect(CoveRadius.device, 48.0);
      expect(CoveRadius.pill, 999.0);
      expect(CoveRadius.smoothing, 1.0);
    });

    test('CoveTheme uses CoveShape and CoveInputBorder across Material themes', () {
      for (final theme in [CoveTheme.darkTheme, CoveTheme.lightTheme]) {
        expect(theme.cardTheme.shape, isA<SmoothRectangleBorder>());
        expect(theme.dialogTheme.shape, isA<SmoothRectangleBorder>());
        expect(theme.bottomSheetTheme.shape, isA<SmoothRectangleBorder>());
        expect(theme.popupMenuTheme.shape, isA<SmoothRectangleBorder>());
        expect(theme.snackBarTheme.shape, isA<SmoothRectangleBorder>());
        expect(theme.chipTheme.shape, isA<SmoothRectangleBorder>());
        expect(
          theme.elevatedButtonTheme.style?.shape?.resolve({}),
          isA<SmoothRectangleBorder>(),
        );
        expect(
          theme.filledButtonTheme.style?.shape?.resolve({}),
          isA<SmoothRectangleBorder>(),
        );
        expect(
          theme.outlinedButtonTheme.style?.shape?.resolve({}),
          isA<SmoothRectangleBorder>(),
        );
        expect(
          theme.textButtonTheme.style?.shape?.resolve({}),
          isA<SmoothRectangleBorder>(),
        );
        expect(theme.inputDecorationTheme.border, isA<CoveInputBorder>());
        expect(theme.inputDecorationTheme.enabledBorder, isA<CoveInputBorder>());
        expect(theme.inputDecorationTheme.focusedBorder, isA<CoveInputBorder>());
        expect(theme.inputDecorationTheme.errorBorder, isA<CoveInputBorder>());
      }
    });

    testWidgets('CoveShape at each radius (inline, card, hero, sheet, device) in both modes', (
      tester,
    ) async {
      const radii = <(String, double, bool)>[
        ('inline · 20dp', CoveRadius.inline, false),
        ('card · 24dp', CoveRadius.card, false),
        ('hero · 32dp', CoveRadius.hero, false),
        ('sheet (top) · 40dp', CoveRadius.sheet, true),
        ('device · 48dp', CoveRadius.device, false),
      ];

      await _pumpGolden(
        tester,
        'cove_shape_45a.radii',
        const Size(420, 660),
        (context, cv) => Padding(
          padding: const EdgeInsets.all(CoveSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (label, r, topOnly) in radii)
                SizedBox(
                  height: 108,
                  child: DecoratedBox(
                    decoration: topOnly
                        ? CoveShape.topDecoration(
                            r,
                            color: cv.surfaceCard,
                            side: BorderSide(color: cv.lineStrong, width: 1),
                          )
                        : CoveShape.decoration(
                            r,
                            color: cv.surfaceCard,
                            side: BorderSide(color: cv.lineStrong, width: 1),
                          ),
                    child: Center(
                      child: Text(
                        label,
                        style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });

    testWidgets('Zoomed corner proves inside hairline has equal thickness on straight edge and curve', (
      tester,
    ) async {
      await _pumpGolden(
        tester,
        'cove_shape_45a.zoomed_corner',
        const Size(760, 560),
        (context, cv) {
          // Zoom 10x into the top-left corner of a 200x200dp clipped card with an inside hairline.
          // At radius 24dp and smoothing 1.0, the corner curve spans (1 + 1.0) * 24 = 48dp (480px at 10x)
          // from (40, 40) to 520 along both edges; x = 520..760 shows the truly flat top edge in the same frame.
          return SizedBox.expand(
            child: ClipRect(
              child: Transform.scale(
                scale: 10.0,
                alignment: Alignment.topLeft,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: CoveShape.clip(
                      CoveRadius.card,
                      DecoratedBox(
                        decoration: CoveShape.decoration(
                          CoveRadius.card,
                          color: cv.surfaceCard,
                          side: BorderSide(color: cv.accentFill, width: 1),
                        ),
                        child: const SizedBox(width: 200, height: 200),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

      // Programmatically verify that at high magnification (10x, 1dp stroke = 10px),
      // the stroke thickness inside the clip on the straight top edge (at x = 650, well past
      // the ~480px corner smoothing zone ending at x = 520) matches the stroke thickness
      // through the 45-degree corner diagonal.
      final boundaryKey = GlobalKey();
      tester.view
        ..physicalSize = const Size(800, 600)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const strokeColor = Color(0xFFFF0055);
      const fillColor = Color(0xFF1A1F26);
      const bgColor = Color(0xFF000000);

      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ColoredBox(
              color: bgColor,
              child: SizedBox.expand(
                child: ClipRect(
                  child: Transform.scale(
                    scale: 10.0,
                    alignment: Alignment.topLeft,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: CoveShape.clip(
                          CoveRadius.card,
                          DecoratedBox(
                            decoration: CoveShape.decoration(
                              CoveRadius.card,
                              color: fillColor,
                              side: const BorderSide(
                                color: strokeColor,
                                width: 1,
                              ),
                            ),
                            child: const SizedBox(width: 200, height: 200),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boundary =
          boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.0);
        return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      });
      expect(bytes, isNotNull);

      bool isStrokePixel(int x, int y) {
        final offset = (y * 800 + x) * 4;
        final r = bytes!.getUint8(offset);
        return r > 120; // strokeColor has R=255, fill has R=26, bg has R=0
      }

      // Measure vertical thickness along the truly straight top edge at x = 650
      // (at 10x scale with 4dp padding and 24dp radius at 1.0 smoothing, the corner smoothing
      // zone runs from x = 40 to ~520px, so x = 650px is well onto the flat top edge).
      var straightEdgeStrokePx = 0;
      for (var y = 0; y < 120; y++) {
        if (isStrokePixel(650, y)) straightEdgeStrokePx++;
      }

      // Measure diagonal thickness along x == y through the top-left corner curve,
      // converted from 45-degree step count by multiplying by sqrt(2).
      var diagSteps = 0;
      for (var i = 0; i < 200; i++) {
        if (isStrokePixel(i, i)) diagSteps++;
      }
      final curveStrokePx = diagSteps * math.sqrt2;

      expect(straightEdgeStrokePx, inInclusiveRange(9, 11));
      expect((curveStrokePx - straightEdgeStrokePx).abs(), lessThanOrEqualTo(1.6));
    });

    testWidgets('52dp row plate at CoveRadius.inline shows reduced smoothing without reducing radius', (
      tester,
    ) async {
      // Verify the smooth corner path for a 52dp row plate at radius.inline (20dp):
      // maxRadius = 52 / 2 = 26, cornerRadius = 20 (> maxRadius / 2 = 13),
      // so the path stays bounded within the 52dp height while a taller 120dp
      // shape has stronger smoothing (deeper corner cut at x = 18dp from corner).
      final path52 = smoothCornerPath(
        const Rect.fromLTWH(0, 0, 340, CoveSize.row),
        radius: CoveRadius.inline,
      );
      final pathTall = smoothCornerPath(
        const Rect.fromLTWH(0, 0, 340, 120),
        radius: CoveRadius.inline,
      );
      expect(path52.getBounds(), equals(const Rect.fromLTWH(0, 0, 340, CoveSize.row)));
      // At (15, 0.8), the 52dp plate (reduced smoothing, closer to circular arc of r=20)
      // is already inside the shape, whereas the 120dp shape (full 100% squircle smoothing)
      // cuts slightly deeper along the tangent before the corner.
      expect(path52.contains(const Offset(15, 0.8)), isTrue);
      expect(pathTall.contains(const Offset(15, 0.8)), isFalse);

      await _pumpGolden(
        tester,
        'cove_shape_45a.row_plate_52dp',
        const Size(400, 140),
        (context, cv) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
            child: SizedBox(
              height: CoveSize.row,
              width: double.infinity,
              child: DecoratedBox(
                decoration: CoveShape.decoration(
                  CoveRadius.inline,
                  color: cv.surfaceCard,
                  side: BorderSide(color: cv.lineStrong, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: CoveSpace.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '52dp row plate · inline 20dp',
                        style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                      ),
                      Text(
                        'reduced smoothing',
                        style: CoveType.readout.copyWith(color: cv.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  });
}
