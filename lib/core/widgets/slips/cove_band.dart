import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shape/cove_shape.dart';
import '../../theme/cove_tokens.dart';
import 'cove_slip.dart';

/// A routine band slip (`design/specs/14-add-flow.md` §9).
///
/// Built on [CoveSlip] to the contract in `design/specs/14-add-flow.md` §9:
/// - `COVE · ROUTINE` caps ([capsLabel]), [title] in [CoveType.slipTitle].
/// - A 24-hour track, radius [CoveRadius.inline], the day's span in a soft
///   tint. The routine sits on it as a hatched block from [startMinutes] to
///   [endMinutes], in `accentFill`, positioned by real minutes. Under the
///   track, ticks `12 AM · 6 · 12 PM · 6 · 12`.
/// - Minimum block width so a 15-minute routine stays visible: [kMinBlockWidth]
///   (`8dp`).
/// - A row of seven day dots, Monday first, filled for the routine's [days].
/// - Caption: e.g. `'8:00 – 8:30 AM'`.
/// - Supports optional [stamp], [visibility] line, and [fieldTaps] (§8).
class CoveBand extends StatelessWidget implements CoveSlipObject {
  @override
  final CoveSlipVariant variant;
  final String title;
  final int startMinutes;
  final int endMinutes;
  final Set<int> days; // 1 = Mon .. 7 = Sun
  final String capsLabel;
  final String? caption;
  final String? owner;
  final String? stamp;
  final bool stampLanded;
  final CoveSlipVisibility? visibility;
  final CoveSlipFieldTaps? fieldTaps;
  final VoidCallback? onTap;
  final String? semanticLabel;

  static const double kTrackHeight = 36.0; // (literal) 36dp 24-hour routine track
  static const double kMinBlockWidth =
      8.0; // (literal) 8dp minimum block width so a 15-min routine stays visible
  static const double kBlockRadius = 6.0; // (literal) hatched block corner radius
  static const double kBlockBorderWidth = 1.0; // (literal) 1dp block outline
  static const double kHatchSpacing = 6.0; // (literal) 6dp diagonal hatch spacing
  static const double kHatchStrokeWidth = 1.5; // (literal) 1.5dp diagonal hatch stroke
  static const double kDayDotSize = 24.0; // (literal) 24dp weekday dot diameter
  static const double kDayDotBorder = 1.0; // (literal) 1dp outline on inactive day dot
  static const int kMinutesPerDay = 1440; // (literal) 24 * 60 minutes

  static const List<String> _dayLetters = <String>[
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  static const List<String> _tickLabels = <String>[
    '12 AM',
    '6',
    '12 PM',
    '6',
    '12',
  ];

  CoveBand({
    super.key,
    required this.variant,
    required this.title,
    required this.startMinutes,
    required this.endMinutes,
    required Set<int> days,
    this.capsLabel = 'COVE · ROUTINE',
    this.caption,
    this.owner,
    this.stamp,
    this.stampLanded = true,
    this.visibility,
    this.fieldTaps,
    this.onTap,
    this.semanticLabel,
  }) : days = Set<int>.unmodifiable(
          (days.where((d) => d >= 1 && d <= 7).toList()..sort()),
        );

  /// Formats [startMinutes] and [endMinutes] (`0..1439`) as `'8:00 – 8:30 AM'`.
  static String formatTimeRange(int startMinutes, int endMinutes) {
    final s = startMinutes.clamp(0, 1439);
    final e = endMinutes.clamp(0, 1439);

    final sHour24 = s ~/ 60;
    final sMin = s % 60;
    final eHour24 = e ~/ 60;
    final eMin = e % 60;

    final sMeridiem = sHour24 >= 12 ? 'PM' : 'AM';
    final eMeridiem = eHour24 >= 12 ? 'PM' : 'AM';

    final sHour12 = sHour24 % 12 == 0 ? 12 : sHour24 % 12;
    final eHour12 = eHour24 % 12 == 0 ? 12 : eHour24 % 12;

    final sTime = '$sHour12:${sMin.toString().padLeft(2, '0')}';
    final eTime = '$eHour12:${eMin.toString().padLeft(2, '0')}';

    if (sMeridiem == eMeridiem) {
      return '$sTime – $eTime $eMeridiem';
    }
    return '$sTime $sMeridiem – $eTime $eMeridiem';
  }

  String get resolvedCaption =>
      caption ?? formatTimeRange(startMinutes, endMinutes);

  /// Computes the rendered hatched block rectangle within a [trackSize] track,
  /// enforcing [kMinBlockWidth] (`8dp`).
  static Rect resolveBlockRect(
    Size trackSize,
    int startMinutes,
    int endMinutes,
  ) {
    final clampedStart = startMinutes.clamp(0, kMinutesPerDay);
    final clampedEnd = endMinutes.clamp(clampedStart, kMinutesPerDay);

    final startFrac = clampedStart / kMinutesPerDay;
    final endFrac = clampedEnd / kMinutesPerDay;

    final rawWidth = (endFrac - startFrac) * trackSize.width;
    final blockWidth = math.min(
      trackSize.width,
      math.max(kMinBlockWidth, rawWidth),
    );
    final left = math.min(
      startFrac * trackSize.width,
      math.max(0.0, trackSize.width - blockWidth),
    );
    return Rect.fromLTWH(left, 0.0, blockWidth, trackSize.height);
  }

  String _buildDefaultSemantics() {
    final dayCount = days.length;
    final daysSummary = dayCount == 7
        ? 'every day'
        : (days.length == 5 &&
                days.containsAll(const <int>[1, 2, 3, 4, 5]))
            ? 'weekdays'
            : '$dayCount days a week';
    return 'Routine, $title, $resolvedCaption, $daysSummary';
  }

  @override
  Widget build(BuildContext context) {
    final palette = CoveSlipPalette.resolve(context, variant);
    final stripeColor = variant == CoveSlipVariant.paper
        ? CoveTokens.light.paperFrom
        : CoveTokens.dark.slipInkFrom;

    return CoveSlip(
      variant: variant,
      onTap: onTap,
      stamp: stamp,
      stampLanded: stampLanded,
      visibility: visibility,
      fieldTaps: fieldTaps,
      semanticLabel: semanticLabel ?? _buildDefaultSemantics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header: COVE · ROUTINE caps + title in slipTitle
          CoveSlipFieldTapTarget(
            field: CoveSlipField.title,
            fieldTaps: fieldTaps,
            child: CoveSlip.buildHeader(
              palette: palette,
              capsLabel: capsLabel,
              title: title,
            ),
          ),
          const SizedBox(height: CoveSpace.md),

          // 2. 24-hour track + hatched block + 12 AM · 6 · 12 PM · 6 · 12 ticks
          CoveSlipFieldTapTarget(
            field: CoveSlipField.duration,
            fieldTaps: fieldTaps,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  key: const ValueKey('cove_band_track'),
                  height: kTrackHeight,
                  child: CustomPaint(
                    painter: _CoveBandTrackPainter(
                      startMinutes: startMinutes,
                      endMinutes: endMinutes,
                      trackFillColor: palette.hairline,
                      trackBorderColor: palette.rule,
                      blockFillColor: palette.accentFill,
                      hatchStripeColor: stripeColor,
                    ),
                  ),
                ),
                const SizedBox(height: CoveSpace.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final tick in _tickLabels)
                      Text(
                        tick,
                        style: CoveType.capsSlip.copyWith(
                          color: palette.tertiary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: CoveSpace.sm),

          // 3. Seven day dots, Monday first
          CoveSlipFieldTapTarget(
            field: CoveSlipField.days,
            fieldTaps: fieldTaps,
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: CoveSpace.sm,
                vertical: CoveSpace.sm,
              ),
              decoration: CoveShape.decoration(
                CoveRadius.inline,
                color: palette.hairline,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: CoveSpace.xs),
                    _BandDayDot(
                      letter: _dayLetters[i],
                      active: days.contains(i + 1),
                      palette: palette,
                      activeTextColor: stripeColor,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: CoveSpace.md),

          // 4. Caption: 8:00 – 8:30 AM [· owner]
          Center(
            child: (owner != null && owner!.trim().isNotEmpty)
                ? Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      CoveSlipFieldTapTarget(
                        field: CoveSlipField.time,
                        fieldTaps: fieldTaps,
                        alignment: Alignment.center,
                        child: Text(
                          resolvedCaption,
                          textAlign: TextAlign.center,
                          style: CoveType.readout.copyWith(
                            color: palette.secondary,
                          ),
                        ),
                      ),
                      Text(
                        ' · ',
                        style: CoveType.readout.copyWith(
                          color: palette.tertiary,
                        ),
                      ),
                      CoveSlipFieldTapTarget(
                        field: CoveSlipField.owner,
                        fieldTaps: fieldTaps,
                        alignment: Alignment.center,
                        child: Text(
                          owner!.trim(),
                          textAlign: TextAlign.center,
                          style: CoveType.readout.copyWith(
                            color: palette.secondary,
                          ),
                        ),
                      ),
                    ],
                  )
                : CoveSlipFieldTapTarget(
                    field: CoveSlipField.time,
                    fieldTaps: fieldTaps,
                    alignment: Alignment.center,
                    child: Text(
                      resolvedCaption,
                      textAlign: TextAlign.center,
                      style: CoveType.readout.copyWith(
                        color: palette.secondary,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BandDayDot extends StatelessWidget {
  final String letter;
  final bool active;
  final CoveSlipPalette palette;
  final Color activeTextColor;

  const _BandDayDot({
    required this.letter,
    required this.active,
    required this.palette,
    required this.activeTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CoveBand.kDayDotSize,
      height: CoveBand.kDayDotSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? palette.accentFill : Colors.transparent,
        border: active
            ? null
            : Border.all(
                color: palette.mark,
                width: CoveBand.kDayDotBorder,
              ),
      ),
      child: Text(
        letter,
        textAlign: TextAlign.center,
        style: CoveType.capsSlip.copyWith(
          color: active ? activeTextColor : palette.tertiary,
        ),
      ),
    );
  }
}

class _CoveBandTrackPainter extends CustomPainter {
  final int startMinutes;
  final int endMinutes;
  final Color trackFillColor;
  final Color trackBorderColor;
  final Color blockFillColor;
  final Color hatchStripeColor;

  const _CoveBandTrackPainter({
    required this.startMinutes,
    required this.endMinutes,
    required this.trackFillColor,
    required this.trackBorderColor,
    required this.blockFillColor,
    required this.hatchStripeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final trackRect = Offset.zero & size;
    final trackPath = smoothCornerPath(trackRect, radius: CoveRadius.inline);

    // 1. Track background & hairline border
    final trackFillPaint = Paint()
      ..color = trackFillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(trackPath, trackFillPaint);

    final trackBorderPaint = Paint()
      ..color = trackBorderColor
      ..strokeWidth = CoveBand.kBlockBorderWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      smoothCornerPath(
        trackRect.deflate(CoveBand.kBlockBorderWidth / 2.0),
        radius: CoveRadius.inline - CoveBand.kBlockBorderWidth / 2.0,
      ),
      trackBorderPaint,
    );

    // 2. Hatched routine block positioned by real minutes (min width 8dp)
    final blockRect = CoveBand.resolveBlockRect(size, startMinutes, endMinutes);
    final blockPath = smoothCornerPath(
      blockRect,
      radius: CoveBand.kBlockRadius,
    );

    canvas.save();
    canvas.clipPath(trackPath);

    final blockFillPaint = Paint()
      ..color = blockFillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(blockPath, blockFillPaint);

    // Diagonal hatch lines inside the block
    canvas.save();
    canvas.clipPath(blockPath);
    final hatchPaint = Paint()
      ..color = hatchStripeColor
      ..strokeWidth = CoveBand.kHatchStrokeWidth
      ..style = PaintingStyle.stroke;

    final span = blockRect.width + blockRect.height;
    var offset = -blockRect.height;
    while (offset < span) {
      canvas.drawLine(
        Offset(blockRect.left + offset, blockRect.bottom),
        Offset(
          blockRect.left + offset + blockRect.height,
          blockRect.top,
        ),
        hatchPaint,
      );
      offset += CoveBand.kHatchSpacing;
    }
    canvas.restore();

    final blockOutlinePaint = Paint()
      ..color = blockFillColor
      ..strokeWidth = CoveBand.kBlockBorderWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      smoothCornerPath(
        blockRect.deflate(CoveBand.kBlockBorderWidth / 2.0),
        radius: CoveBand.kBlockRadius - CoveBand.kBlockBorderWidth / 2.0,
      ),
      blockOutlinePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CoveBandTrackPainter oldDelegate) =>
      oldDelegate.startMinutes != startMinutes ||
      oldDelegate.endMinutes != endMinutes ||
      oldDelegate.trackFillColor != trackFillColor ||
      oldDelegate.trackBorderColor != trackBorderColor ||
      oldDelegate.blockFillColor != blockFillColor ||
      oldDelegate.hatchStripeColor != hatchStripeColor;
}
