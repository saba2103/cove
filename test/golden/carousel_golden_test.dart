import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/utils/cove_currency_formatter.dart';
import 'package:cove/core/widgets/cove_carousel.dart';
import 'package:cove/core/widgets/cove_max_width.dart';
import 'package:cove/core/widgets/cove_section_label.dart';
import 'package:cove/core/widgets/slips/cove_habit_card.dart';
import 'package:cove/core/widgets/slips/cove_slip.dart';
import 'package:cove/core/widgets/slips/cove_ticket.dart';
import 'package:cove/core/widgets/slips/cove_voucher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _CarouselShowcase extends StatelessWidget {
  const _CarouselShowcase();

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final variant = Theme.of(context).brightness == Brightness.dark
        ? CoveSlipVariant.ink
        : CoveSlipVariant.paper;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: CoveSpace.md),
        child: CoveMaxWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
                child: CoveSectionLabel.page(
                  label: 'One item · Full width, no pager',
                  readout: '1 of 1',
                ),
              ),
              const SizedBox(height: CoveSpace.sm),
              CoveCarousel(
                key: const ValueKey('carousel_one'),
                children: [
                  CoveVoucher(
                    key: const ValueKey('carousel_one_item_0'),
                    variant: variant,
                    title: 'AC — the instalment',
                    amount: '₹${formatCoveAmount(3974)}',
                    dueDay: '22',
                    dueMonth: 'OCT',
                    dueMonthSemantic: 'October',
                    state: CoveVoucherState.due,
                  ),
                ],
              ),
              const SizedBox(height: CoveSpace.md),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
                child: CoveSectionLabel.page(
                  label: 'Two items · 82% width, next peeks',
                  readout: '1 of 2',
                ),
              ),
              const SizedBox(height: CoveSpace.sm),
              CoveCarousel(
                key: const ValueKey('carousel_two'),
                children: [
                  CoveHabitCard(
                    key: const ValueKey('carousel_two_item_0'),
                    variant: variant,
                    title: 'Morning walk',
                    cadence: 'every day · both of you',
                    isDoneToday: true,
                    daysRunning: 23,
                  ),
                  CoveHabitCard(
                    key: const ValueKey('carousel_two_item_1'),
                    variant: variant,
                    title: 'Read twenty pages',
                    cadence: 'every night · you',
                    isDoneToday: false,
                    daysRunning: 7,
                  ),
                ],
              ),
              const SizedBox(height: CoveSpace.md),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
                child: CoveSectionLabel.page(
                  label: 'Five items · Pager on second item',
                  readout: '2 of 5',
                ),
              ),
              const SizedBox(height: CoveSpace.sm),
              CoveCarousel(
                key: const ValueKey('carousel_five'),
                initialIndex: 1,
                children: [
                  CoveTicket(
                    key: const ValueKey('carousel_five_item_0'),
                    variant: variant,
                    title: 'Dentist — Dr. Nair',
                    date: 'Wed, 21 Oct · Indiranagar',
                    owner: 'Both of you',
                    hour: '09:00',
                    meridiem: 'AM',
                  ),
                  CoveTicket(
                    key: const ValueKey('carousel_five_item_1'),
                    variant: variant,
                    title: 'Architect review',
                    date: 'Wed, 21 Oct · Ulsoor Lake',
                    owner: 'You',
                    hour: '11:30',
                    meridiem: 'AM',
                  ),
                  CoveTicket(
                    key: const ValueKey('carousel_five_item_2'),
                    variant: variant,
                    title: 'CA tax filing check-in',
                    date: 'Wed, 21 Oct · Video call',
                    owner: 'Ananya',
                    hour: '02:00',
                    meridiem: 'PM',
                  ),
                  CoveTicket(
                    key: const ValueKey('carousel_five_item_3'),
                    variant: variant,
                    title: 'Pick up curtains',
                    date: 'Wed, 21 Oct · Commercial St',
                    owner: 'Both of you',
                    hour: '05:15',
                    meridiem: 'PM',
                  ),
                  CoveTicket(
                    key: const ValueKey('carousel_five_item_4'),
                    variant: variant,
                    title: 'Call with Amma',
                    date: 'Wed, 21 Oct · 30m',
                    owner: 'Ananya',
                    hour: '07:30',
                    meridiem: 'PM',
                  ),
                ],
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
    'CoveCarousel golden matrix (one, two, and five items across phone, cover, and wide widths)',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await goldenMatrix(
          tester,
          'carousel',
          const _CarouselShowcase(),
        );

        // Verify layout geometry at phone (390) and cover (320) widths.
        for (final viewportWidth in <double>[390.0, 320.0]) {
          await tester.binding.setSurfaceSize(Size(viewportWidth, 844.0));
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: CoveTheme.darkTheme,
              home: const _CarouselShowcase(),
            ),
          );
          await tester.pump();

          final expectedContentWidth = viewportWidth - (CoveSpace.gutter * 2);
          final expectedMultiItemWidth =
              expectedContentWidth * CoveCarousel.kItemWidthRatio;

          // 1. One-item carousel: full content width, aligned to gutter, no pager dots.
          final oneRect = tester.getRect(
            find.byKey(const ValueKey('carousel_one_item_0')),
          );
          expect(oneRect.left, closeTo(CoveSpace.gutter, 0.01));
          expect(oneRect.width, closeTo(expectedContentWidth, 0.01));

          // 2. Two-item carousel: 82% of content width, first item aligned to gutter,
          //    12dp gap (`CoveSpace.md`), second item peeks inside viewport.
          final twoItem0Rect = tester.getRect(
            find.byKey(const ValueKey('carousel_two_item_0')),
          );
          final twoItem1Rect = tester.getRect(
            find.byKey(const ValueKey('carousel_two_item_1')),
          );
          expect(twoItem0Rect.left, closeTo(CoveSpace.gutter, 0.01));
          expect(twoItem0Rect.width, closeTo(expectedMultiItemWidth, 0.01));
          expect(
            twoItem1Rect.left - twoItem0Rect.right,
            closeTo(CoveSpace.md, 0.01),
          );
          expect(twoItem1Rect.left, lessThan(viewportWidth));
          expect(twoItem1Rect.right, greaterThan(viewportWidth));
        }
      } finally {
        await tester.binding.setSurfaceSize(null);
        semanticsHandle.dispose();
      }
    },
  );

  testWidgets(
    'CoveCarousel announces "2 of 3" to assistive tech and respects Reduce Motion',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        int? reportedIndex;
        Widget buildSubject({required bool disableAnimations}) {
          return MaterialApp(
            theme: CoveTheme.darkTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: disableAnimations),
              child: child!,
            ),
            home: Scaffold(
              body: CoveCarousel(
                key: const ValueKey('carousel_three'),
                onIndexChanged: (i) => reportedIndex = i,
                children: const [
                  SizedBox(height: 120, child: Text('Slide A')),
                  SizedBox(height: 120, child: Text('Slide B')),
                  SizedBox(height: 120, child: Text('Slide C')),
                ],
              ),
            ),
          );
        }

        await tester.pumpWidget(buildSubject(disableAnimations: false));
        await tester.pump();

        // Initial semantics announcement: "1 of 3", increasedValue: "2 of 3"
        final sem1 = tester.getSemantics(
          find.byKey(const ValueKey('carousel_three')),
        );
        expect(sem1.value, equals('1 of 3'));
        expect(sem1.increasedValue, equals('2 of 3'));
        expect(
          sem1.getSemanticsData().hasAction(SemanticsAction.increase),
          isTrue,
        );

        // Pager dot sizes: active dot is 20x6dp, inactive dots are 6x6dp
        expect(
          tester.getSize(find.byKey(const ValueKey('cove_carousel_dot_0'))),
          equals(const Size(20.0, 6.0)),
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('cove_carousel_dot_1'))),
          equals(const Size(6.0, 6.0)),
        );

        // Pager dots are wrapped in IgnorePointer and are not tap targets
        await tester.tap(
          find.byKey(const ValueKey('cove_carousel_dot_2')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        expect(reportedIndex, isNull);

        // Trigger assistive-tech "next" action -> announces "2 of 3"
        tester.semantics.performAction(
          find.semantics.byValue('1 of 3'),
          SemanticsAction.increase,
        );
        await tester.pumpAndSettle();

        expect(reportedIndex, equals(1));
        final sem2 = tester.getSemantics(
          find.byKey(const ValueKey('carousel_three')),
        );
        expect(sem2.value, equals('2 of 3'));
        expect(sem2.increasedValue, equals('3 of 3'));
        expect(sem2.decreasedValue, equals('1 of 3'));

        // Active dot is now index 1 (20x6dp)
        expect(
          tester.getSize(find.byKey(const ValueKey('cove_carousel_dot_1'))),
          equals(const Size(20.0, 6.0)),
        );

        // Now enable Reduce Motion and advance to "3 of 3": jumps without animation
        await tester.pumpWidget(buildSubject(disableAnimations: true));
        await tester.pump();

        tester.semantics.performAction(
          find.semantics.byValue('2 of 3'),
          SemanticsAction.increase,
        );
        // Single pump (no settle needed when Reduce Motion is active)
        await tester.pump();

        expect(reportedIndex, equals(2));
        final sem3 = tester.getSemantics(
          find.byKey(const ValueKey('carousel_three')),
        );
        expect(sem3.value, equals('3 of 3'));
      } finally {
        semanticsHandle.dispose();
      }
    },
  );
}
