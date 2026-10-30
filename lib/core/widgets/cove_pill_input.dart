import 'package:flutter/material.dart';
import '../shape/cove_shape.dart';
import '../theme/cove_tokens.dart';

class CovePillInput extends StatefulWidget {
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
      1.0; // (literal) 1dp pill input resting border
  static const double _kFocusedBorderWidth =
      1.5; // (literal) 1.5dp pill input focus ring
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
  State<CovePillInput> createState() => _CovePillInputState();
}

class _CovePillInputState extends State<CovePillInput> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final isScaled = MediaQuery.textScalerOf(context).scale(1.0) > 1.0;

    return Focus(
      onFocusChange: (focused) {
        if (_hasFocus != focused) {
          setState(() => _hasFocus = focused);
        }
      },
      child: Container(
        height: isScaled ? null : CoveSize.hit,
        constraints: isScaled
            ? const BoxConstraints(minHeight: CoveSize.hit)
            : null,
        decoration: CoveShape.decoration(
          CoveRadius.pill,
          color: cv.surfaceRow,
          side: BorderSide(
            color: _hasFocus ? cv.lineFocus : cv.lineControl,
            width: _hasFocus
                ? CovePillInput._kFocusedBorderWidth
                : CovePillInput._kBorderWidth,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: CovePillInput._kHorizontalPadding,
        ),
        child: Row(
          children: [
            if (widget.prefixIcon != null) ...[
              widget.prefixIcon!,
              const SizedBox(width: CoveSpace.sm),
            ],
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                autofocus: widget.autofocus,
                obscureText: widget.obscureText,
                autocorrect: !widget.obscureText,
                enableSuggestions: !widget.obscureText,
                keyboardType: widget.keyboardType,
                textCapitalization: widget.textCapitalization,
                textInputAction: widget.textInputAction,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                style: CoveType.readout.copyWith(
                  color: cv.textPrimary,
                ),
                cursorColor: cv.lineFocus,
                cursorWidth: CovePillInput._kCursorWidth,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintMaxLines: isScaled ? 6 : 1,
                  hintStyle: CoveType.readout.copyWith(
                    color: cv.textTertiary,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: CoveSpace.md,
                  ),
                ),
              ),
            ),
            if (widget.suffix != null) ...[
              const SizedBox(width: CoveSpace.sm),
              widget.suffix!,
            ],
          ],
        ),
      ),
    );
  }
}
