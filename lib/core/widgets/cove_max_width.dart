import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';

/// Constrains [child] to [CoveSize.maxContent] horizontally and centres it
/// on wide viewports (`>= 600dp`: Fold inner screen, tablets, web).
///
/// Below `600dp`, [child] expands to the full available width with the normal
/// gutter.
class CoveMaxWidth extends StatelessWidget {
  static const double kWideViewportThreshold =
      600.0; // (literal) 600dp wide-screen threshold for CoveSize.maxContent

  final Widget child;
  final AlignmentGeometry alignment;

  const CoveMaxWidth({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  /// Returns [CoveSize.maxContent] when the viewport width is at least
  /// [kWideViewportThreshold] (`600dp`), and [double.infinity] otherwise.
  static double maxWidthFor(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= kWideViewportThreshold
        ? CoveSize.maxContent
        : double.infinity;
  }

  /// Returns `BoxConstraints(maxWidth: maxWidthFor(context))`.
  static BoxConstraints constraintsFor(BuildContext context) {
    return BoxConstraints(maxWidth: maxWidthFor(context));
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: constraintsFor(context),
        child: SizedBox(
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }
}
