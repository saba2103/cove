import 'package:flutter/material.dart';

import '../../theme/cove_tokens.dart';
import '../cove_checkbox.dart';
import 'cove_slip.dart';

/// A single ruled item row inside a [CoveNote] (`design/specs/10-paper-objects.md`).
@immutable
class CoveNoteItem {
  final String title;
  final String? addedBy;
  final bool isDone;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTap;

  const CoveNoteItem({
    required this.title,
    this.addedBy,
    this.isDone = false,
    this.onChanged,
    this.onTap,
  });
}

/// A ruled notepad list slip (`design/specs/10-paper-objects.md`).
///
/// Built on [CoveSlip] to the contract in `design/specs/10-paper-objects.md`:
/// - Top corners [kTopCornerRadius] (`4dp`), bottom corners [CoveRadius.card]
///   (`20dp`) — the top edge reads as torn from a pad.
/// - Ruled horizontal lines every [kRuledLineSpacing] (`32dp`) in the rule
///   colour, running under the caps line and every item.
/// - Items: [CoveCheckbox] + title in [CoveType.slipTitle], with `addedBy`
///   beneath in tertiary text. Done items strike through and drop to
///   secondary (`palette.secondary`).
/// - Exposes its state as semantics (WCAG 4.1.2).
class CoveNote extends StatelessWidget implements CoveSlipObject {
  @override
  final CoveSlipVariant variant;
  final String capsLabel;
  final List<CoveNoteItem> items;
  final VoidCallback? onTap;
  final String? semanticLabel;

  static const double kTopCornerRadius =
      4.0; // (literal) top corners 4dp — torn from a pad
  static const double kRuledLineSpacing =
      32.0; // (literal) ruled lines every 32dp
  static const double kRuledLineThickness =
      1.0; // (literal) 1dp ruled line stroke

  const CoveNote({
    super.key,
    required this.variant,
    required this.items,
    this.capsLabel = 'COVE · GROCERY LIST',
    this.onTap,
    this.semanticLabel,
  });

  String _buildDefaultSemantics() {
    final doneCount = items.where((i) => i.isDone).length;
    final openCount = items.length - doneCount;
    final itemSummary = items
        .map((i) => '${i.title} (${i.isDone ? 'done' : 'open'})')
        .join(', ');
    if (itemSummary.isEmpty) {
      return 'Note, $capsLabel, empty';
    }
    return 'Note, $capsLabel, $openCount open, $doneCount done: $itemSummary';
  }

  @override
  Widget build(BuildContext context) {
    final palette = CoveSlipPalette.resolve(context, variant);

    return CoveSlip(
      variant: variant,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(kTopCornerRadius),
        bottom: Radius.circular(CoveRadius.card),
      ),
      backgroundPainter: _CoveNoteRuledLinesPainter(
        ruleColor: palette.rule,
      ),
      onTap: onTap,
      semanticLabel: semanticLabel ?? _buildDefaultSemantics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            capsLabel.toUpperCase(),
            style: CoveType.capsSlip.copyWith(color: palette.tertiary),
          ),
          const SizedBox(height: CoveSpace.md),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: CoveSpace.md),
            _CoveNoteItemView(
              item: items[i],
              palette: palette,
            ),
          ],
        ],
      ),
    );
  }
}

class _CoveNoteItemView extends StatelessWidget {
  final CoveNoteItem item;
  final CoveSlipPalette palette;

  const _CoveNoteItemView({
    required this.item,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final hasAddedBy = item.addedBy != null && item.addedBy!.trim().isNotEmpty;
    final titleColor = item.isDone ? palette.secondary : palette.title;

    final Widget rowContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CoveCheckbox(
              value: item.isDone,
              onChanged: item.onChanged,
            ),
            const SizedBox(width: CoveSpace.md),
            Expanded(
              child: Text(
                item.title,
                style: CoveType.slipTitle.copyWith(
                  color: titleColor,
                  decoration: item.isDone
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: palette.secondary,
                ),
              ),
            ),
          ],
        ),
        if (hasAddedBy) ...[
          const SizedBox(height: CoveSpace.xs),
          Text(
            item.addedBy!,
            style: CoveType.readout.copyWith(color: palette.tertiary),
          ),
        ],
      ],
    );

    if (item.onTap == null && item.onChanged == null) {
      return rowContent;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.onTap ??
          (item.onChanged != null ? () => item.onChanged!(!item.isDone) : null),
      child: rowContent,
    );
  }
}

class _CoveNoteRuledLinesPainter extends CustomPainter {
  final Color ruleColor;

  const _CoveNoteRuledLinesPainter({
    required this.ruleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ruleColor
      ..strokeWidth = CoveNote.kRuledLineThickness
      ..style = PaintingStyle.stroke;

    var y = CoveNote.kRuledLineSpacing;
    while (y < size.height) {
      canvas.drawLine(Offset(0.0, y), Offset(size.width, y), paint);
      y += CoveNote.kRuledLineSpacing;
    }
  }

  @override
  bool shouldRepaint(_CoveNoteRuledLinesPainter oldDelegate) =>
      oldDelegate.ruleColor != ruleColor;
}
