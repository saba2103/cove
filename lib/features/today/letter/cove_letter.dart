import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/cove_tokens.dart';
import 'compose_day_letter.dart';

/// Renders the Day Letter (`List<LetterSpan>`) in [CoveType.letter] (`design/specs/11-day-letter.md`).
///
/// Built to the contract in `design/specs/11-day-letter.md`:
/// - Knows nothing about the day; renders pre-composed [LetterSpan] data.
/// - Plain spans render in [CoveType.letter] (`Libre Bodoni` 400, `21sp`, `36dp`
///   line height) with `text.primary`.
/// - Link spans render in the same text colour with an `accent.fill` underline
///   and invoke [onTapTarget] with their [LetterTarget] when tapped.
/// - Italic spans render in `Libre Bodoni Italic` (`FontStyle.italic`) with
///   `text.secondary` (or `text.tertiary` for the first-run empty-home prompt).
class CoveLetter extends StatefulWidget {
  final List<LetterSpan> spans;
  final ValueChanged<LetterTarget>? onTapTarget;
  final TextAlign textAlign;

  const CoveLetter({
    super.key,
    required this.spans,
    this.onTapTarget,
    this.textAlign = TextAlign.start,
  });

  @override
  State<CoveLetter> createState() => _CoveLetterState();
}

class _CoveLetterState extends State<CoveLetter> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer _createRecognizer(LetterTarget target) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () => widget.onTapTarget?.call(target);
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    if (widget.spans.isEmpty) {
      return const SizedBox.shrink();
    }

    final cv = context.cv;
    final plainStyle = CoveType.letter.copyWith(color: cv.textPrimary);
    final linkStyle = plainStyle.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: cv.accentFill,
    );
    final italicSecondaryStyle = CoveType.letter.copyWith(
      fontStyle: FontStyle.italic,
      color: cv.textSecondary,
    );
    final italicTertiaryStyle = CoveType.letter.copyWith(
      fontStyle: FontStyle.italic,
      color: cv.textTertiary,
    );

    final inlineSpans = <InlineSpan>[];
    for (final span in widget.spans) {
      switch (span.style) {
        case LetterSpanStyle.plain:
          inlineSpans.add(
            TextSpan(
              text: span.text,
              style: plainStyle,
            ),
          );
        case LetterSpanStyle.link:
          final target = span.target;
          inlineSpans.add(
            TextSpan(
              text: span.text,
              style: linkStyle,
              recognizer: target != null ? _createRecognizer(target) : null,
            ),
          );
        case LetterSpanStyle.italic:
          inlineSpans.add(
            TextSpan(
              text: span.text,
              style: span.isTertiary
                  ? italicTertiaryStyle
                  : italicSecondaryStyle,
            ),
          );
      }
    }

    return Text.rich(
      TextSpan(
        style: plainStyle,
        children: inlineSpans,
      ),
      textAlign: widget.textAlign,
    );
  }
}
