import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/cove_tokens.dart';

/// Active selection mode of [AddClockFace] (`design/specs/14-add-flow.md` §3 **time**).
enum AddClockMode {
  hour,
  minute,
}

/// Digital `08 : 00` boxes + `AM`/`PM` pair + 12-position circular clock face
/// (`design/specs/14-add-flow.md` §3 **time**, matching `10-event-3-time.png`
/// and `11-event-3b-minutes.png`).
///
/// - Hour mode first; picking an hour automatically switches to minute mode
///   (5-minute steps: `00..55`).
/// - For an event (`showAllDay: true`), renders an `All day` chip beneath the
///   clock face.
/// - Every interactive target (hour box, minute box, `AM`, `PM`, the 12 clock
///   positions, and `All day`) is at least `48 × 48dp` ([CoveSize.hit]), even
///   at `320dp` cover width.
class AddClockFace extends StatefulWidget {
  /// 24-hour value (`0..23`).
  final int hour;

  /// Minute value (`0..59`, snapped to 5-minute steps on the dial).
  final int minute;

  /// Callback when hour or minute changes (`hour` in `0..23`, `minute` in `0..59`).
  final void Function(int hour, int minute) onChanged;

  /// Whether to show the `All day` chip below the dial (events only).
  final bool showAllDay;

  /// Current `All day` state when [showAllDay] is `true`.
  final bool isAllDay;

  /// Callback when the `All day` chip is toggled.
  final ValueChanged<bool>? onAllDayChanged;

  /// Initial mode (`AddClockMode.hour` by default; tests/goldens can pass
  /// `AddClockMode.minute` to render the minute dial directly).
  final AddClockMode initialMode;

  /// Optional callback when the active mode changes.
  final ValueChanged<AddClockMode>? onModeChanged;

  static const double kMaxDialDiameter = 256.0; // (literal) max clock dial diameter
  static const double kMinDialDiameter = 216.0; // (literal) compact dial diameter at 320dp
  static const double _kBoxMinWidth = 76.0; // (literal) 76dp digital readout box width
  static const double _kBoxHeight = 60.0; // (literal) 60dp digital readout box height
  static const double _kMeridiemVisualHeight = 32.0; // (literal) visual pill height inside 48dp hit target
  static const double _kSelectedBorder = 1.5; // (literal) 1.5dp active border
  static const double _kNormalBorder = 1.0; // (literal) 1dp inactive border
  static const double _kHandWidth = 2.0; // (literal) 2dp clock hand stroke
  static const double _kCenterDotRadius = 4.0; // (literal) 4dp centre pivot dot
  static const double _kThumbRadius = 20.0; // (literal) 20dp (40dp diameter) selected thumb circle
  static const double _kRingInset = 32.0; // (literal) inset from dial edge to number ring centre

  const AddClockFace({
    super.key,
    required this.hour,
    required this.minute,
    required this.onChanged,
    this.showAllDay = false,
    this.isAllDay = false,
    this.onAllDayChanged,
    this.initialMode = AddClockMode.hour,
    this.onModeChanged,
  })  : assert(hour >= 0 && hour <= 23),
        assert(minute >= 0 && minute <= 59);

  @override
  State<AddClockFace> createState() => _AddClockFaceState();
}

class _AddClockFaceState extends State<AddClockFace> {
  late AddClockMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void didUpdateWidget(covariant AddClockFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMode != widget.initialMode) {
      _mode = widget.initialMode;
    }
  }

  bool get _isPm => widget.hour >= 12;

  int get _hour12 {
    final h = widget.hour % 12;
    return h == 0 ? 12 : h;
  }

  int get _snappedMinuteIndex => ((widget.minute / 5).round()) % 12;

  void _setMode(AddClockMode nextMode) {
    if (_mode == nextMode) return;
    setState(() => _mode = nextMode);
    widget.onModeChanged?.call(nextMode);
  }

  void _setMeridiem(bool pm) {
    if (pm == _isPm) return;
    final h12 = widget.hour % 12;
    final nextHour = pm ? h12 + 12 : h12;
    if (widget.isAllDay) {
      widget.onAllDayChanged?.call(false);
    }
    widget.onChanged(nextHour, widget.minute);
  }

  void _selectPosition(int index) {
    if (widget.isAllDay) {
      widget.onAllDayChanged?.call(false);
    }
    if (_mode == AddClockMode.hour) {
      final h12 = index == 0 ? 12 : index;
      final base = h12 == 12 ? 0 : h12;
      final nextHour = _isPm ? base + 12 : base;
      widget.onChanged(nextHour, widget.minute);
      _setMode(AddClockMode.minute);
    } else {
      final nextMinute = (index * 5) % 60;
      widget.onChanged(widget.hour, nextMinute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final hourLabel = _hour12.toString().padLeft(2, '0');
    final minuteLabel = widget.minute.toString().padLeft(2, '0');
    final selectedIndex = _mode == AddClockMode.hour
        ? (_hour12 % 12)
        : _snappedMinuteIndex;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Digital readout: [08] : [00] + AM/PM
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DigitalBox(
              label: hourLabel,
              semanticLabel: 'Hour $hourLabel',
              active: !widget.isAllDay && _mode == AddClockMode.hour,
              onTap: () {
                if (widget.isAllDay) {
                  widget.onAllDayChanged?.call(false);
                }
                _setMode(AddClockMode.hour);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CoveSpace.sm),
              child: Text(
                ':',
                style: CoveType.title.copyWith(color: cv.textTertiary),
              ),
            ),
            _DigitalBox(
              label: minuteLabel,
              semanticLabel: 'Minute $minuteLabel',
              active: !widget.isAllDay && _mode == AddClockMode.minute,
              onTap: () {
                if (widget.isAllDay) {
                  widget.onAllDayChanged?.call(false);
                }
                _setMode(AddClockMode.minute);
              },
            ),
            const SizedBox(width: CoveSpace.sm),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MeridiemButton(
                  label: 'AM',
                  selected: !widget.isAllDay && !_isPm,
                  onTap: () => _setMeridiem(false),
                ),
                _MeridiemButton(
                  label: 'PM',
                  selected: !widget.isAllDay && _isPm,
                  onTap: () => _setMeridiem(true),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: CoveSpace.lg),

        // 2. 12-position circular clock face
        LayoutBuilder(
          builder: (context, constraints) {
            final dialSize = math.max(
              AddClockFace.kMinDialDiameter,
              math.min(
                AddClockFace.kMaxDialDiameter,
                constraints.maxWidth - CoveSpace.gutter,
              ),
            );
            final center = dialSize / 2.0;
            final ringRadius = center - AddClockFace._kRingInset;

            return SizedBox(
              width: dialSize,
              height: dialSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ClockDialPainter(
                        selectedIndex: selectedIndex,
                        ringRadius: ringRadius,
                        dialColor: cv.surfaceRow,
                        accentColor: cv.accentFill,
                        showHand: !widget.isAllDay,
                      ),
                    ),
                  ),
                  for (var i = 0; i < 12; i++)
                    _buildClockPosition(
                      context: context,
                      index: i,
                      selectedIndex: selectedIndex,
                      center: center,
                      ringRadius: ringRadius,
                    ),
                ],
              ),
            );
          },
        ),

        // 3. Optional All day chip for events (§3)
        if (widget.showAllDay) ...[
          const SizedBox(height: CoveSpace.md),
          Semantics(
            container: true,
            button: true,
            toggled: widget.isAllDay,
            label: 'All day',
            onTap: widget.onAllDayChanged != null
                ? () => widget.onAllDayChanged!(!widget.isAllDay)
                : null,
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onAllDayChanged != null
                    ? () => widget.onAllDayChanged!(!widget.isAllDay)
                    : null,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: CoveSize.hit,
                    minHeight: CoveSize.hit,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.gutter,
                    vertical: CoveSpace.sm,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isAllDay ? cv.accentWash : cv.surfaceRow,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(CoveRadius.pill),
                    ),
                    border: Border.all(
                      color: widget.isAllDay ? cv.accentFill : cv.lineStrong,
                      width: widget.isAllDay
                          ? AddClockFace._kSelectedBorder
                          : AddClockFace._kNormalBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'All day',
                        style: CoveType.rowTitle.copyWith(
                          color: widget.isAllDay
                              ? cv.accentText
                              : cv.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildClockPosition({
    required BuildContext context,
    required int index,
    required int selectedIndex,
    required double center,
    required double ringRadius,
  }) {
    final cv = context.cv;
    final angle = -math.pi / 2 + (index * 2 * math.pi / 12);
    final x = center + ringRadius * math.cos(angle);
    final y = center + ringRadius * math.sin(angle);
    final isSelected = !widget.isAllDay && index == selectedIndex;

    final String label;
    final String semantic;
    if (_mode == AddClockMode.hour) {
      final h = index == 0 ? 12 : index;
      label = '$h';
      semantic = '$h o\'clock';
    } else {
      final m = (index * 5).toString().padLeft(2, '0');
      label = m;
      semantic = '$m minutes';
    }

    return Positioned(
      left: x - CoveSize.hit / 2.0,
      top: y - CoveSize.hit / 2.0,
      width: CoveSize.hit,
      height: CoveSize.hit,
      child: Semantics(
        container: true,
        button: true,
        selected: isSelected,
        label: semantic,
        onTap: () => _selectPosition(index),
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectPosition(index),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: (isSelected ? CoveType.rowTitle : CoveType.body).copyWith(
                  color: isSelected ? cv.textOnAccent : cv.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DigitalBox extends StatelessWidget {
  final String label;
  final String semanticLabel;
  final bool active;
  final VoidCallback onTap;

  const _DigitalBox({
    required this.label,
    required this.semanticLabel,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Semantics(
      container: true,
      button: true,
      selected: active,
      label: semanticLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: AddClockFace._kBoxMinWidth,
              minHeight: AddClockFace._kBoxHeight,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.md,
              vertical: CoveSpace.xs,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? cv.accentWash : cv.surfaceRow,
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.inline),
              ),
              border: active
                  ? Border.all(
                      color: cv.accentFill,
                      width: AddClockFace._kSelectedBorder,
                    )
                  : null,
            ),
            child: Text(
              label,
              style: CoveType.slipFigure.copyWith(
                color: active ? cv.accentText : cv.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MeridiemButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MeridiemButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: CoveSize.hit,
              minHeight: CoveSize.hit,
            ),
            child: Center(
              child: Container(
                height: AddClockFace._kMeridiemVisualHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: CoveSpace.md,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? cv.accentWash : cv.surfaceRow,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(CoveRadius.inline),
                  ),
                  border: Border.all(
                    color: selected ? cv.accentFill : cv.lineStrong,
                    width: selected
                        ? AddClockFace._kSelectedBorder
                        : AddClockFace._kNormalBorder,
                  ),
                ),
                child: Text(
                  label,
                  style: CoveType.capsCard.copyWith(
                    color: selected ? cv.accentText : cv.textTertiary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClockDialPainter extends CustomPainter {
  final int selectedIndex;
  final double ringRadius;
  final Color dialColor;
  final Color accentColor;
  final bool showHand;

  const _ClockDialPainter({
    required this.selectedIndex,
    required this.ringRadius,
    required this.dialColor,
    required this.accentColor,
    required this.showHand,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2.0, size.height / 2.0);
    final radius = size.width / 2.0;

    final dialPaint = Paint()
      ..color = dialColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, dialPaint);

    if (!showHand) return;

    final angle = -math.pi / 2 + (selectedIndex * 2 * math.pi / 12);
    final target = Offset(
      center.dx + ringRadius * math.cos(angle),
      center.dy + ringRadius * math.sin(angle),
    );

    final handPaint = Paint()
      ..color = accentColor
      ..strokeWidth = AddClockFace._kHandWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, target, handPaint);

    final dotPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, AddClockFace._kCenterDotRadius, dotPaint);
    canvas.drawCircle(target, AddClockFace._kThumbRadius, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _ClockDialPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.ringRadius != ringRadius ||
        oldDelegate.dialColor != dialColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.showHand != showHand;
  }
}
