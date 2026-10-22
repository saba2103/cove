import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';

/// Constrains [child] to [CoveSize.maxContent] horizontally and centres it
/// on any viewport wider than that (Fold inner screen, tablets, web).
class CoveMaxWidth extends StatelessWidget {
  final Widget child;
  final AlignmentGeometry alignment;

  const CoveMaxWidth({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: CoveSize.maxContent),
        child: SizedBox(
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }
}
