import 'package:flutter/material.dart';

import '../../../core/shape/cove_shape.dart';
import '../../../core/theme/cove_tokens.dart';

/// A single option in [AddChoiceList] (`design/specs/14-add-flow.md` §3 **choice**).
@immutable
class AddChoiceOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final Color? swatchColor;
  final Widget? leading;

  const AddChoiceOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.swatchColor,
    this.leading,
  });
}

/// Option list for **choice** steps (`design/specs/14-add-flow.md` §3 **choice**).
///
/// - Each row has [CoveRadius.inline] (`16dp`) and is at least [CoveSize.row]
///   (`52dp` `>= 48dp`) tall.
/// - Supports a leading colour swatch ([AddChoiceOption.swatchColor] for
///   categories), custom [AddChoiceOption.leading] mark (e.g. card chip), or
///   a trailing/secondary line in `textTertiary` (`"twelve times a year"`).
class AddChoiceList<T> extends StatelessWidget {
  final List<AddChoiceOption<T>> options;
  final T? selectedValue;
  final ValueChanged<T> onSelected;

  static const double _kSwatchDiameter = 14.0; // (literal) 14dp category colour dot
  static const double _kSelectedBorder = 1.5; // (literal) 1.5dp selected border
  static const double _kNormalBorder = 1.0; // (literal) 1dp option border

  const AddChoiceList({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: CoveSpace.sm),
          _ChoiceOptionRow<T>(
            option: options[i],
            selected: selectedValue == options[i].value,
            onTap: () => onSelected(options[i].value),
          ),
        ],
      ],
    );
  }
}

class _ChoiceOptionRow<T> extends StatelessWidget {
  final AddChoiceOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceOptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final hasSubtitle =
        option.subtitle != null && option.subtitle!.trim().isNotEmpty;
    final semanticLabel =
        hasSubtitle ? '${option.label}, ${option.subtitle}' : option.label;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticLabel,
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
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.gutter,
              vertical: CoveSpace.md,
            ),
            decoration: CoveShape.decoration(
              CoveRadius.inline,
              color: selected ? cv.accentWash : cv.surfaceRow,
              side: BorderSide(
                color: selected ? cv.accentFill : cv.lineStrong,
                width: selected
                    ? AddChoiceList._kSelectedBorder
                    : AddChoiceList._kNormalBorder,
              ),
            ),
            child: Row(
              children: [
                if (option.swatchColor != null) ...[
                  Container(
                    width: AddChoiceList._kSwatchDiameter,
                    height: AddChoiceList._kSwatchDiameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: option.swatchColor,
                    ),
                  ),
                  const SizedBox(width: CoveSpace.md),
                ] else if (option.leading != null) ...[
                  option.leading!,
                  const SizedBox(width: CoveSpace.md),
                ],
                Expanded(
                  child: Text(
                    option.label,
                    style: CoveType.rowTitle.copyWith(
                      color: selected ? cv.textPrimary : cv.textSecondary,
                    ),
                  ),
                ),
                if (hasSubtitle) ...[
                  const SizedBox(width: CoveSpace.md),
                  Flexible(
                    child: Text(
                      option.subtitle!,
                      textAlign: TextAlign.right,
                      style: CoveType.rowSub.copyWith(
                        color: cv.textTertiary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
