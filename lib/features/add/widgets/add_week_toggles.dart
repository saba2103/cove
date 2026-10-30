import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/shape/cove_shape.dart';
import '../../../core/theme/cove_tokens.dart';

/// Seven weekday toggles (`M T W T F S S`, Monday first) for routines and
/// custom-day habits (`design/specs/14-add-flow.md` §3 **week**).
///
/// - Monday first (`1 = Monday .. 7 = Sunday`).
/// - Enforces at least one active day: tapping the last remaining active day
///   leaves it on.
/// - Displays a summary hint beneath (`"Every day"`, `"5 days a week"`, etc.).
/// - At cover width (`< CoveSize.compactThreshold`), keeps `48dp` targets and
///   scrolls horizontally with the first selected day scrolled into view.
class AddWeekToggles extends StatefulWidget {
  final Set<int> selectedDays;
  final ValueChanged<Set<int>> onChanged;
  final bool showHint;

  static const List<String> _dayLetters = <String>[
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  static const List<String> _daySemantics = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const double _kSelectedBorder = 1.5; // (literal) 1.5dp selected border
  static const double _kNormalBorder = 1.0; // (literal) 1dp toggle border

  const AddWeekToggles({
    super.key,
    required this.selectedDays,
    required this.onChanged,
    this.showHint = true,
  });

  static String describeDays(Set<int> days) {
    final count = days.length;
    if (count == 7) return 'Every day';
    if (count == 1) return '1 day a week';
    return '$count days a week';
  }

  @override
  State<AddWeekToggles> createState() => _AddWeekTogglesState();
}

class _AddWeekTogglesState extends State<AddWeekToggles> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollFirstSelected());
  }

  void _scrollFirstSelected() {
    if (!mounted || !_scrollController.hasClients) return;
    if (widget.selectedDays.isEmpty) return;
    final sorted = widget.selectedDays.toList()..sort();
    final firstIndex = (sorted.first - 1).clamp(0, 6);
    const itemExtent = CoveSize.hit + CoveSpace.sm;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;
    _scrollController.jumpTo((firstIndex * itemExtent).clamp(0.0, maxScroll));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleDay(int weekday) {
    final next = Set<int>.from(widget.selectedDays);
    if (next.contains(weekday)) {
      // Spec §3: "At least one must be on."
      if (next.length <= 1) return;
      next.remove(weekday);
    } else {
      next.add(weekday);
    }
    final sorted = next.toList()..sort();
    widget.onChanged(Set<int>.from(sorted));
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1.0);
            final cellExtent = textScale > 1.0
                ? (CoveSize.hit * math.min(textScale, 1.5)).ceilToDouble()
                : CoveSize.hit;
            final minRequiredWidth = 7 * cellExtent + 6 * CoveSpace.xs;
            final isCompact =
                MediaQuery.sizeOf(context).width < CoveSize.compactThreshold ||
                    constraints.maxWidth < minRequiredWidth;

            if (isCompact) {
              return SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 7; i++) ...[
                      if (i > 0) const SizedBox(width: CoveSpace.sm),
                      SizedBox(
                        width: cellExtent,
                        height: cellExtent,
                        child: _buildDayToggle(context, i + 1),
                      ),
                    ],
                  ],
                ),
              );
            }

            return Row(
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: CoveSpace.xs),
                  Expanded(
                    child: SizedBox(
                      height: cellExtent,
                      child: _buildDayToggle(context, i + 1),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        if (widget.showHint) ...[
          const SizedBox(height: CoveSpace.md),
          Text(
            AddWeekToggles.describeDays(widget.selectedDays),
            textAlign: TextAlign.center,
            style: CoveType.rowSub.copyWith(color: cv.textTertiary),
          ),
        ],
      ],
    );
  }

  Widget _buildDayToggle(BuildContext context, int weekday) {
    final cv = context.cv;
    final isSelected = widget.selectedDays.contains(weekday);
    final letter = AddWeekToggles._dayLetters[weekday - 1];
    final semanticName = AddWeekToggles._daySemantics[weekday - 1];

    return Semantics(
      container: true,
      button: true,
      toggled: isSelected,
      label: semanticName,
      onTap: () => _toggleDay(weekday),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _toggleDay(weekday),
          child: Container(
            constraints: const BoxConstraints(
              minWidth: CoveSize.hit,
              minHeight: CoveSize.hit,
            ),
            alignment: Alignment.center,
            decoration: CoveShape.decoration(
              CoveRadius.inline,
              color: isSelected ? cv.accentWash : cv.surfaceRow,
              side: BorderSide(
                color: isSelected ? cv.accentFill : cv.lineHairline,
                width: isSelected
                    ? AddWeekToggles._kSelectedBorder
                    : AddWeekToggles._kNormalBorder,
              ),
            ),
            child: Text(
              letter,
              style: CoveType.capsCard.copyWith(
                color: isSelected ? cv.accentText : cv.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
