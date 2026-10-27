import 'package:flutter/material.dart';
import '../shape/cove_shape.dart';
import '../theme/cove_tokens.dart';

class CovePillInput extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffix;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  /// Hides typed characters (passwords, passphrases). Disables autocorrect.
  final bool obscureText;

  static const double _kBorderWidth =
      1.0; // (literal) 1dp pill input hairline border
  static const double _kHorizontalPadding =
      16.0; // (literal) 16dp pill input horizontal inset
  static const double _kCursorWidth =
      1.5; // (literal) 1.5dp text cursor width

  const CovePillInput({
    super.key,
    this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffix,
    this.focusNode,
    this.textInputAction = TextInputAction.done,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.autofocus = false,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Container(
      height: CoveSize.hit,
      decoration: CoveShape.decoration(
        CoveRadius.pill,
        color: cv.surfaceRow,
        side: BorderSide(
          color: cv.lineHairline,
          width: _kBorderWidth,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: _kHorizontalPadding),
      child: Row(
        children: [
          if (prefixIcon != null) ...[
            prefixIcon!,
            const SizedBox(width: CoveSpace.sm),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              obscureText: obscureText,
              autocorrect: !obscureText,
              enableSuggestions: !obscureText,
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              textInputAction: textInputAction,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: CoveType.readout.copyWith(
                color: cv.textPrimary,
              ),
              cursorColor: cv.accentFill,
              cursorWidth: _kCursorWidth,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: CoveType.readout.copyWith(
                  color: cv.textTertiary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: CoveSpace.md,
                ),
              ),
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: CoveSpace.sm),
            suffix!,
          ],
        ],
      ),
    );
  }
}
