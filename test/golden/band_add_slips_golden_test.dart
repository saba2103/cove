import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/utils/cove_currency_formatter.dart';
import 'package:cove/core/widgets/cove_avatar.dart';
import 'package:cove/core/widgets/cove_max_width.dart';
import 'package:cove/core/widgets/cove_section_label.dart';
import 'package:cove/core/widgets/slips/cove_add_mark.dart';
import 'package:cove/core/widgets/slips/cove_band.dart';
import 'package:cove/core/widgets/slips/cove_habit_card.dart';
import 'package:cove/core/widgets/slips/cove_note.dart';
import 'package:cove/core/widgets/slips/cove_receipt.dart';
import 'package:cove/core/widgets/slips/cove_slip.dart';
import 'package:cove/core/widgets/slips/cove_ticket.dart';
import 'package:cove/core/widgets/slips/cove_voucher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _BandAndAddMarkShowcase extends StatelessWidget {
  final CoveSlipVariant variant;

  const _BandAndAddMarkShowcase({required this.variant});

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final tag = variant == CoveSlipVariant.ink ? 'Ink' : 'Paper';

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: CoveSpace.md),
        child: CoveMaxWidth(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CoveSectionLabel.page(
                  label: '15 min · Weekdays · $tag',
                  readout: '8:00 – 8:15 AM',
                ),
                const SizedBox(height: CoveSpace.xs),
                CoveBand(
                  key: ValueKey('band_15m_weekdays_${variant.name}'),
                  variant: variant,
                  title: 'Morning stretch',
                  startMinutes: 8 * 60,
                  endMinutes: 8 * 60 + 15,
                  days: const <int>{1, 2, 3, 4, 5},
                  caption: '8:00 – 8:15 AM',
                ),
                const SizedBox(height: CoveSpace.md),
                CoveSectionLabel.page(
                  label: '2 hours · Every day · $tag',
                  readout: '6:00 – 8:00 PM',
                ),
                const SizedBox(height: CoveSpace.xs),
                CoveBand(
                  key: ValueKey('band_2h_everyday_${variant.name}'),
                  variant: variant,
                  title: 'Evening wind-down',
                  startMinutes: 18 * 60,
                  endMinutes: 20 * 60,
                  days: const <int>{1, 2, 3, 4, 5, 6, 7},
                  caption: '6:00 – 8:00 PM',
                ),
                const SizedBox(height: CoveSpace.md),
                const CoveSectionLabel.page(
                  label: 'Add paper marks',
                  readout: '6 kinds',
                ),
                const SizedBox(height: CoveSpace.xs),
                Wrap(
                  spacing: CoveSpace.md,
                  runSpacing: CoveSpace.sm,
                  children: [
                    for (final kind in AddKind.values)
                      Container(
                        padding: const EdgeInsets.all(CoveSpace.xs),
                        decoration: BoxDecoration(
                          color: cv.surfaceCard,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(CoveRadius.card),
                          ),
                          border: Border.all(color: cv.lineHairline),
                        ),
                        child: CoveAddMark(
                          kind,
                          key: ValueKey('add_mark_${kind.name}'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlipsGroupAShowcase extends StatelessWidget {
  final String? stamp;
  final CoveSlipVisibility? visibility;

  const _SlipsGroupAShowcase({this.stamp, this.visibility});

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: CoveSpace.sm),
        child: CoveMaxWidth(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CoveReceipt(
                  key: const ValueKey('showcase_receipt'),
                  variant: CoveSlipVariant.paper,
                  recordId: 'exp-add-preview',
                  title: 'Thursday',
                  items: <CoveReceiptItem>[
                    CoveReceiptItem(
                      payer: CovePerson.a,
                      nameOrInitial: 'S',
                      title: 'Blue Tokai coffee beans',
                      subtitle: 'Groceries · UPI',
                      amount: '₹${formatCoveAmount(540)}',
                    ),
                  ],
                  totalAmount: '₹${formatCoveAmount(540)}',
                  footerDate: 'TODAY, OCT 22',
                  stamp: stamp,
                  visibility: visibility,
                ),
                const SizedBox(height: CoveSpace.sm),
                CoveTicket(
                  key: const ValueKey('showcase_ticket'),
                  variant: CoveSlipVariant.paper,
                  title: 'Dinner at Koshy’s',
                  location: 'St. Mark’s Road',
                  date: 'Today, 22 Oct',
                  owner: 'Both of you',
                  hour: '8:00',
                  meridiem: 'PM',
                  stamp: stamp,
                  visibility: visibility,
                ),
                const SizedBox(height: CoveSpace.sm),
                CoveNote(
                  key: const ValueKey('showcase_note'),
                  variant: CoveSlipVariant.paper,
                  capsLabel: 'COVE · TO-DO',
                  items: const <CoveNoteItem>[
                    CoveNoteItem(
                      title: 'Pick up dry cleaning',
                      addedBy: 'Due Tomorrow, 23 Oct',
                      isDone: false,
                    ),
                  ],
                  stamp: stamp,
                  visibility: visibility,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlipsGroupBShowcase extends StatelessWidget {
  final String? stamp;
  final CoveSlipVisibility? visibility;

  const _SlipsGroupBShowcase({this.stamp, this.visibility});

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: CoveSpace.sm),
        child: CoveMaxWidth(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CoveHabitCard(
                  key: const ValueKey('showcase_habit'),
                  variant: CoveSlipVariant.paper,
                  title: 'Read 20 pages',
                  cadence: 'Every day · 7 of 7',
                  isDoneToday: false,
                  daysRunning: 0,
                  stamp: stamp,
                  visibility: visibility,
                ),
                const SizedBox(height: CoveSpace.sm),
                CoveVoucher(
                  key: const ValueKey('showcase_voucher'),
                  variant: CoveSlipVariant.paper,
                  title: 'BESCOM electricity',
                  amount: '₹${formatCoveAmount(1820)}',
                  dueDay: '05',
                  dueMonth: 'NOV',
                  dueMonthSemantic: 'November',
                  state: CoveVoucherState.due,
                  paidFrom: 'Auto-debit · HDFC',
                  whose: 'Shared · 50 / 50',
                  stamp: stamp,
                  visibility: visibility,
                ),
                const SizedBox(height: CoveSpace.sm),
                CoveBand(
                  key: const ValueKey('showcase_band'),
                  variant: CoveSlipVariant.paper,
                  title: 'Morning stretch',
                  startMinutes: 8 * 60,
                  endMinutes: 8 * 60 + 30,
                  days: const <int>{1, 2, 3, 4, 5},
                  caption: '8:00 – 8:30 AM',
                  stamp: stamp,
                  visibility: visibility,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'CoveBand (15m & 2h, weekdays & everyday) and CoveAddMark golden matrix',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await goldenMatrix(
          tester,
          'band_paper',
          const _BandAndAddMarkShowcase(variant: CoveSlipVariant.paper),
        );

        final trackBox = tester.renderObject<RenderBox>(
          find.descendant(
            of: find.byKey(const ValueKey('band_15m_weekdays_paper')),
            matching: find.byKey(const ValueKey('cove_band_track')),
          ),
        );
        final blockRect = CoveBand.resolveBlockRect(
          trackBox.size,
          8 * 60,
          8 * 60 + 15,
        );
        expect(blockRect.width, greaterThanOrEqualTo(CoveBand.kMinBlockWidth));

        // Semantics readout for CoveBand
        final bandSem = tester.getSemantics(
          find.byKey(const ValueKey('band_15m_weekdays_paper')),
        );
        expect(
          bandSem.label,
          equals('Routine, Morning stretch, 8:00 – 8:15 AM, weekdays'),
        );

        await goldenMatrix(
          tester,
          'band_ink',
          const _BandAndAddMarkShowcase(variant: CoveSlipVariant.ink),
        );
      } finally {
        semanticsHandle.dispose();
      }
    },
  );

  testWidgets(
    'Each slip with the ADDED stamp across 3 widths × 2 modes',
    (tester) async {
      await goldenMatrix(
        tester,
        'slips_added_stamp_a',
        const _SlipsGroupAShowcase(stamp: 'ADDED'),
      );
      expect(find.text('ADDED'), findsNWidgets(3));

      await goldenMatrix(
        tester,
        'slips_added_stamp_b',
        const _SlipsGroupBShowcase(stamp: 'ADDED'),
      );
      expect(find.text('ADDED'), findsNWidgets(3));
    },
  );

  testWidgets(
    'Each slip with BOTH CAN SEE IT and ONLY YOU CAN SEE IT visibility lines across 3 widths × 2 modes',
    (tester) async {
      await goldenMatrix(
        tester,
        'slips_visibility_both_a',
        const _SlipsGroupAShowcase(visibility: CoveSlipVisibility.bothCanSee),
      );
      expect(find.text('BOTH CAN SEE IT'), findsNWidgets(3));

      await goldenMatrix(
        tester,
        'slips_visibility_both_b',
        const _SlipsGroupBShowcase(visibility: CoveSlipVisibility.bothCanSee),
      );
      expect(find.text('BOTH CAN SEE IT'), findsNWidgets(3));

      await goldenMatrix(
        tester,
        'slips_visibility_private_a',
        const _SlipsGroupAShowcase(
          visibility: CoveSlipVisibility.onlyYouCanSee,
        ),
      );
      expect(find.text('ONLY YOU CAN SEE IT'), findsNWidgets(3));

      await goldenMatrix(
        tester,
        'slips_visibility_private_b',
        const _SlipsGroupBShowcase(
          visibility: CoveSlipVisibility.onlyYouCanSee,
        ),
      );
      expect(find.text('ONLY YOU CAN SEE IT'), findsNWidgets(3));
    },
  );

  testWidgets(
    'Field taps on all six slips expose "Change {field}" semantics, meet 48dp hit targets at 320dp, and invoke callbacks',
    (tester) async {
      await loadCoveFonts();
      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.binding.setSurfaceSize(const Size(320, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final tapped = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: coveThemeFor(Brightness.dark),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(CoveSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CoveReceipt(
                      variant: CoveSlipVariant.paper,
                      recordId: 'r-1',
                      title: 'Today',
                      items: const <CoveReceiptItem>[
                        CoveReceiptItem(
                          payer: CovePerson.a,
                          nameOrInitial: 'S',
                          title: 'Groceries',
                          subtitle: 'Food · UPI',
                          amount: '₹450',
                        ),
                      ],
                      totalAmount: '₹450',
                      footerDate: 'TODAY, OCT 22',
                      visibility: CoveSlipVisibility.bothCanSee,
                      fieldTaps: <CoveSlipField, VoidCallback>{
                        CoveSlipField.title: () => tapped.add('receipt.title'),
                        CoveSlipField.amount: () =>
                            tapped.add('receipt.amount'),
                        CoveSlipField.category: () =>
                            tapped.add('receipt.category'),
                        CoveSlipField.paidBy: () =>
                            tapped.add('receipt.paidBy'),
                        CoveSlipField.date: () => tapped.add('receipt.date'),
                        CoveSlipField.visibility: () =>
                            tapped.add('receipt.visibility'),
                      },
                    ),
                    const SizedBox(height: CoveSpace.md),
                    CoveTicket(
                      variant: CoveSlipVariant.paper,
                      title: 'Dentist',
                      location: 'Indiranagar',
                      date: 'Tomorrow, 23 Oct',
                      owner: 'Just you',
                      hour: '10:30',
                      meridiem: 'AM',
                      visibility: CoveSlipVisibility.onlyYouCanSee,
                      fieldTaps: <CoveSlipField, VoidCallback>{
                        CoveSlipField.title: () => tapped.add('ticket.title'),
                        CoveSlipField.location: () =>
                            tapped.add('ticket.location'),
                        CoveSlipField.date: () => tapped.add('ticket.date'),
                        CoveSlipField.owner: () => tapped.add('ticket.owner'),
                        CoveSlipField.time: () => tapped.add('ticket.time'),
                      },
                    ),
                    const SizedBox(height: CoveSpace.md),
                    CoveNote(
                      variant: CoveSlipVariant.paper,
                      capsLabel: 'COVE · TO-DO',
                      items: const <CoveNoteItem>[
                        CoveNoteItem(
                          title: 'Call plumber',
                          addedBy: 'Due Today',
                          isDone: false,
                        ),
                      ],
                      fieldTaps: <CoveSlipField, VoidCallback>{
                        CoveSlipField.list: () => tapped.add('note.list'),
                        CoveSlipField.title: () => tapped.add('note.title'),
                        CoveSlipField.date: () => tapped.add('note.date'),
                      },
                    ),
                    const SizedBox(height: CoveSpace.md),
                    CoveHabitCard(
                      variant: CoveSlipVariant.paper,
                      title: 'Meditate',
                      cadence: 'Every day · 7 of 7',
                      isDoneToday: false,
                      daysRunning: 0,
                      fieldTaps: <CoveSlipField, VoidCallback>{
                        CoveSlipField.title: () => tapped.add('habit.title'),
                        CoveSlipField.cadence: () =>
                            tapped.add('habit.cadence'),
                      },
                    ),
                    const SizedBox(height: CoveSpace.md),
                    CoveVoucher(
                      variant: CoveSlipVariant.paper,
                      title: 'Netflix',
                      amount: '₹649',
                      dueDay: '28',
                      dueMonth: 'OCT',
                      dueMonthSemantic: 'October',
                      state: CoveVoucherState.due,
                      paidFrom: 'Credit card',
                      whose: 'Shared · 50 / 50',
                      fieldTaps: <CoveSlipField, VoidCallback>{
                        CoveSlipField.title: () => tapped.add('voucher.title'),
                        CoveSlipField.amount: () =>
                            tapped.add('voucher.amount'),
                        CoveSlipField.paidFrom: () =>
                            tapped.add('voucher.paidFrom'),
                        CoveSlipField.owner: () => tapped.add('voucher.owner'),
                        CoveSlipField.dueDate: () =>
                            tapped.add('voucher.dueDate'),
                      },
                    ),
                    const SizedBox(height: CoveSpace.md),
                    CoveBand(
                      key: const ValueKey('band_320'),
                      variant: CoveSlipVariant.paper,
                      title: 'Quick stretch',
                      startMinutes: 7 * 60,
                      endMinutes: 7 * 60 + 15,
                      days: const <int>{1, 2, 3, 4, 5},
                      caption: '7:00 – 7:15 AM',
                      fieldTaps: <CoveSlipField, VoidCallback>{
                        CoveSlipField.title: () => tapped.add('band.title'),
                        CoveSlipField.duration: () =>
                            tapped.add('band.duration'),
                        CoveSlipField.days: () => tapped.add('band.days'),
                        CoveSlipField.time: () => tapped.add('band.time'),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify 15-minute routine block width at 320dp is >= 8dp
        final trackBox320 = tester.renderObject<RenderBox>(
          find.descendant(
            of: find.byKey(const ValueKey('band_320')),
            matching: find.byKey(const ValueKey('cove_band_track')),
          ),
        );
        final block320 = CoveBand.resolveBlockRect(
          trackBox320.size,
          7 * 60,
          7 * 60 + 15,
        );
        expect(block320.width, greaterThanOrEqualTo(CoveBand.kMinBlockWidth));

        // Every active CoveSlipFieldTapTarget rendered has >= 48dp height and width
        final tapTargets = find.byType(CoveSlipFieldTapTarget);
        expect(tapTargets, findsWidgets);
        var activeCount = 0;
        for (final element in tapTargets.evaluate()) {
          final widget = element.widget as CoveSlipFieldTapTarget;
          if (widget.fieldTaps?[widget.field] == null) continue;
          activeCount++;
          final box = element.renderObject! as RenderBox;
          expect(
            box.size.height,
            greaterThanOrEqualTo(CoveSize.hit),
            reason: 'Field ${widget.field} height < 48dp',
          );
          expect(
            box.size.width,
            greaterThanOrEqualTo(CoveSize.hit),
            reason: 'Field ${widget.field} width < 48dp',
          );
        }
        expect(activeCount, greaterThan(15));

        // Verify semantics labels "Change {field}" exist
        expect(find.bySemanticsLabel('Change title'), findsWidgets);
        expect(find.bySemanticsLabel('Change amount'), findsWidgets);
        expect(find.bySemanticsLabel('Change category'), findsOneWidget);
        expect(find.bySemanticsLabel('Change visibility'), findsOneWidget);
        expect(find.bySemanticsLabel('Change location'), findsOneWidget);
        expect(find.bySemanticsLabel('Change list'), findsOneWidget);
        expect(find.bySemanticsLabel('Change cadence'), findsOneWidget);
        expect(find.bySemanticsLabel('Change duration'), findsOneWidget);
        expect(find.bySemanticsLabel('Change days'), findsOneWidget);

        // Tap targets invoke their callbacks
        await tester.tap(find.bySemanticsLabel('Change category'));
        await tester.tap(find.bySemanticsLabel('Change location'));
        await tester.tap(find.bySemanticsLabel('Change list'));
        await tester.tap(find.bySemanticsLabel('Change cadence'));
        await tester.tap(find.bySemanticsLabel('Change duration'));
        await tester.tap(find.bySemanticsLabel('Change days'));
        expect(
          tapped,
          containsAll(<String>[
            'receipt.category',
            'ticket.location',
            'note.list',
            'habit.cadence',
            'band.duration',
            'band.days',
          ]),
        );
      } finally {
        semanticsHandle.dispose();
      }
    },
  );
}
