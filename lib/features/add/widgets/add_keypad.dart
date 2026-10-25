import 'package:flutter/material.dart';

import '../../../core/theme/cove_tokens.dart';
import '../../../core/utils/cove_currency_formatter.dart';

/// 3 × 4 numeric keypad and hero figure for the Add flow (`design/specs/14-add-flow.md` §3).
///
/// - Displays the large hero figure (`₹` small + formatted Indian amount in
///   [CoveType.heroFigure], or a plain integer when [showCurrencySymbol] is
///   `false` for EMI installment counts).
/// - Optional [subtitle] below the figure (e.g., `"Last time at Toit, ₹1,280"`).
/// - Optional [carriedLine] pill below the figure when repeating via Again (§6).
/// - 3 × 4 keypad: `1–9`, `00`, `0`, delete. Each key is [CoveSize.row] (`52dp`)
///   tall (`>= 48dp`) and shrinks horizontally to fit `320dp` cover width.
/// - Enforces at most [maxDigits] digits (default `7`). Whole numbers only.
class AddKeypad extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final bool showCurrencySymbol;
  final int maxDigits;
  final String? subtitle;
  final String? carriedLine;

  static const int kDefaultMaxDigits = 7; // (literal) max 7 digits per spec §3
  static const double _kBackspaceIconSize = 20.0; // (literal) 20dp backspace glyph
  static const double _kCarriedIconSize = 16.0; // (literal) 16dp repeat icon

  const AddKeypad({
    super.key,
    required this.value,
    required this.onChanged,
    this.showCurrencySymbol = true,
    this.maxDigits = kDefaultMaxDigits,
    this.subtitle,
    this.carriedLine,
  });

  void _appendDigits(String digits) {
    final currentStr = value <= 0 ? '' : value.toString();
    if (currentStr.length >= maxDigits) return;
    final remaining = maxDigits - currentStr.length;
    final toAdd =
        digits.length > remaining ? digits.substring(0, remaining) : digits;
    final nextStr = '$currentStr$toAdd';
    final nextVal = int.tryParse(nextStr) ?? 0;
    onChanged(nextVal);
  }

  void _backspace() {
    if (value <= 0) {
      onChanged(0);
      return;
    }
    final currentStr = value.toString();
    if (currentStr.length <= 1) {
      onChanged(0);
      return;
    }
    final nextStr = currentStr.substring(0, currentStr.length - 1);
    onChanged(int.tryParse(nextStr) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final hasValue = value > 0;
    final formattedValue = showCurrencySymbol
        ? formatCoveAmount(hasValue ? value : 0)
        : (hasValue ? value : 0).toString();
    final figureColor = hasValue ? cv.accentText : cv.textTertiary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Hero figure
        Semantics(
          container: true,
          label: showCurrencySymbol ? '₹$formattedValue' : formattedValue,
          child: ExcludeSemantics(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  if (showCurrencySymbol) ...[
                    Text(
                      '₹',
                      style: CoveType.title.copyWith(color: cv.textTertiary),
                    ),
                    const SizedBox(width: CoveSpace.xs),
                  ],
                  Flexible(
                    child: Text(
                      formattedValue,
                      maxLines: 1,
                      style: CoveType.heroFigure.copyWith(color: figureColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: CoveSpace.sm),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: CoveType.rowSub.copyWith(color: cv.textTertiary),
          ),
        ],

        if (carriedLine != null && carriedLine!.isNotEmpty) ...[
          const SizedBox(height: CoveSpace.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.md,
              vertical: CoveSpace.md,
            ),
            decoration: BoxDecoration(
              color: cv.surfaceCard,
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.inline),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.autorenew,
                  size: _kCarriedIconSize,
                  color: cv.accentText,
                ),
                const SizedBox(width: CoveSpace.sm),
                Expanded(
                  child: Text(
                    carriedLine!,
                    style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: CoveSpace.lg),

        // 2. 3 × 4 keypad
        _buildRow(context, [
          _KeypadKey(
            label: '1',
            onTap: () => _appendDigits('1'),
          ),
          _KeypadKey(
            label: '2',
            onTap: () => _appendDigits('2'),
          ),
          _KeypadKey(
            label: '3',
            onTap: () => _appendDigits('3'),
          ),
        ]),
        const SizedBox(height: CoveSpace.xs),
        _buildRow(context, [
          _KeypadKey(
            label: '4',
            onTap: () => _appendDigits('4'),
          ),
          _KeypadKey(
            label: '5',
            onTap: () => _appendDigits('5'),
          ),
          _KeypadKey(
            label: '6',
            onTap: () => _appendDigits('6'),
          ),
        ]),
        const SizedBox(height: CoveSpace.xs),
        _buildRow(context, [
          _KeypadKey(
            label: '7',
            onTap: () => _appendDigits('7'),
          ),
          _KeypadKey(
            label: '8',
            onTap: () => _appendDigits('8'),
          ),
          _KeypadKey(
            label: '9',
            onTap: () => _appendDigits('9'),
          ),
        ]),
        const SizedBox(height: CoveSpace.xs),
        _buildRow(context, [
          _KeypadKey(
            label: '00',
            onTap: () => _appendDigits('00'),
          ),
          _KeypadKey(
            label: '0',
            filled: true,
            onTap: () => _appendDigits('0'),
          ),
          _KeypadKey(
            label: 'Delete',
            icon: Icons.backspace_outlined,
            onTap: _backspace,
          ),
        ]),
      ],
    );
  }

  Widget _buildRow(BuildContext context, List<Widget> keys) {
    return Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: CoveSpace.sm),
          Expanded(child: keys[i]),
        ],
      ],
    );
  }
}

class _KeypadKey extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool filled;
  final VoidCallback onTap;

  const _KeypadKey({
    required this.label,
    this.icon,
    this.filled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: CoveSize.hit,
              minHeight: CoveSize.row,
            ),
            height: CoveSize.row,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? cv.surfaceRow : Colors.transparent,
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.inline),
              ),
            ),
            child: icon != null
                ? Icon(
                    icon,
                    size: AddKeypad._kBackspaceIconSize,
                    color: cv.textSecondary,
                  )
                : Text(
                    label,
                    textAlign: TextAlign.center,
                    style: CoveType.title.copyWith(color: cv.textPrimary),
                  ),
          ),
        ),
      ),
    );
  }
}
