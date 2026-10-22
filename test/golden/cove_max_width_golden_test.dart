import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/cove_max_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _CoveMaxWidthDemo extends StatelessWidget {
  const _CoveMaxWidthDemo();

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: CoveMaxWidth(
        child: Container(
          key: const ValueKey('max_width_box'),
          margin: const EdgeInsets.symmetric(vertical: CoveSpace.section),
          padding: const EdgeInsets.all(CoveSpace.gutter),
          decoration: BoxDecoration(
            color: cv.surfaceCard,
            borderRadius: const BorderRadius.all(
              Radius.circular(CoveRadius.card),
            ),
            border: Border.all(color: cv.lineHairline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MAX CONTENT COLUMN',
                style: CoveType.capsPage.copyWith(color: cv.accentText),
              ),
              const SizedBox(height: CoveSpace.sm),
              Text(
                'Centred at 420 dp',
                style: CoveType.title.copyWith(color: cv.textPrimary),
              ),
              const SizedBox(height: CoveSpace.sm),
              Text(
                'Page content never exceeds CoveSize.maxContent and sits centred on the Fold inner screen, tablets, and web.',
                style: CoveType.body.copyWith(color: cv.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'CoveMaxWidth constrains child to CoveSize.maxContent and centres at wide width',
    (tester) async {
      await goldenMatrix(
        tester,
        'cove_max_width',
        const _CoveMaxWidthDemo(),
        widths: const [CoveWidth.wide],
      );

      final rect = tester.getRect(find.byKey(const ValueKey('max_width_box')));
      expect(rect.width, equals(CoveSize.maxContent));
      expect(
        rect.left,
        equals((CoveWidth.wide.width - CoveSize.maxContent) / 2),
      );
    },
  );
}
