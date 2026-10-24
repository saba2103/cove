import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/cove_max_width.dart';
import 'package:cove/core/widgets/cove_page_header.dart';
import 'package:cove/core/widgets/cove_section_label.dart';
import 'package:cove/core/widgets/slips/cove_slip.dart';
import 'package:cove/core/widgets/slips/cove_ticket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _TicketShowcase extends StatelessWidget {
  const _TicketShowcase();

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: CoveSpace.section),
        child: CoveMaxWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CovePageHeader(
                title: 'On the calendar',
                readout: 'Tickets',
              ),
              const SizedBox(height: CoveSpace.md),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CoveSpace.gutter,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CoveSectionLabel.page(
                      label: 'Ink variant',
                      readout: 'one today',
                    ),
                    const SizedBox(height: CoveSpace.md),
                    CoveTicket(
                      key: const ValueKey('ticket_ink'),
                      variant: CoveSlipVariant.ink,
                      title: 'Call with Amma',
                      date: 'Wednesday, Oct 21',
                      owner: 'Both of you',
                      hour: '7',
                      meridiem: 'PM',
                      onTap: () {},
                    ),
                    const SizedBox(height: CoveSpace.lg),
                    const CoveSectionLabel.page(
                      label: 'Paper variant',
                      readout: 'detail sheet',
                    ),
                    const SizedBox(height: CoveSpace.md),
                    CoveTicket(
                      key: const ValueKey('ticket_paper'),
                      variant: CoveSlipVariant.paper,
                      title: 'Call with Amma',
                      date: 'Wednesday, Oct 21',
                      owner: 'Both of you',
                      hour: '7',
                      meridiem: 'PM',
                      onTap: () {},
                    ),
                    const SizedBox(height: CoveSpace.lg),
                    const CoveSectionLabel.page(
                      label: 'Alert word on ink & paper',
                      readout: 'conflict',
                    ),
                    const SizedBox(height: CoveSpace.md),
                    const CoveTicket(
                      key: ValueKey('ticket_ink_alert'),
                      variant: CoveSlipVariant.ink,
                      title: 'Dentist appointment',
                      date: 'Thursday, Oct 22',
                      owner: 'Added by Saba',
                      hour: '10:30',
                      meridiem: 'AM',
                      alertText: 'Overlaps with standup',
                    ),
                    const SizedBox(height: CoveSpace.md),
                    const CoveTicket(
                      key: ValueKey('ticket_paper_alert'),
                      variant: CoveSlipVariant.paper,
                      title: 'Dentist appointment',
                      date: 'Thursday, Oct 22',
                      owner: 'Added by Saba',
                      hour: '10:30',
                      meridiem: 'AM',
                      alertText: 'Overlaps with standup',
                    ),
                  ],
                ),
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
    'CoveSlip & CoveTicket golden matrix (paper and ink in both brightnesses, semantics, ink contrast tokens)',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await goldenMatrix(
          tester,
          'ticket',
          const _TicketShowcase(),
        );

        // 1. Verify semantics exposure per design/specs/10-paper-objects.md
        final inkSemantics = tester.getSemantics(
          find.byKey(const ValueKey('ticket_ink')),
        );
        expect(
          inkSemantics.label,
          equals('Ticket, Call with Amma, Wednesday, Oct 21, starts 7 PM, Both of you'),
        );

        final alertSemantics = tester.getSemantics(
          find.byKey(const ValueKey('ticket_ink_alert')),
        );
        expect(
          alertSemantics.label,
          equals(
            'Ticket, Dentist appointment, Thursday, Oct 22, starts 10:30 AM, Added by Saba, Overlaps with standup',
          ),
        );

        // 2. Verify caller-selected variant palette rules in light mode (currently active after goldenMatrix)
        final lightCtx = tester.element(find.byType(Scaffold));
        final inkOnLight = CoveSlipPalette.resolve(lightCtx, CoveSlipVariant.ink);
        final paperOnLight = CoveSlipPalette.resolve(
          lightCtx,
          CoveSlipVariant.paper,
        );

        // Ink never uses text.tertiary or status.alertText
        expect(inkOnLight.tertiary, equals(CoveTokens.light.slipInkText3));
        expect(inkOnLight.tertiary, isNot(equals(CoveTokens.dark.textTertiary)));
        expect(inkOnLight.alertText, equals(CoveTokens.light.slipInkAlertText));
        expect(
          inkOnLight.alertText,
          isNot(equals(CoveTokens.dark.statusAlertText)),
        );
        expect(inkOnLight.edgeColor, isNull);
        expect(inkOnLight.shadows, isEmpty);

        // Paper in light mode has paper.edge hairline + elevationPaper
        expect(paperOnLight.edgeColor, equals(CoveTokens.light.paperEdge));
        expect(paperOnLight.shadows, equals(CoveTokens.light.elevationPaper));

        // 3. Pump dark mode and verify paper has no edge/shadow in dark mode
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: coveThemeFor(Brightness.dark),
            home: const _TicketShowcase(),
          ),
        );
        await tester.pumpAndSettle();

        final darkCtx = tester.element(find.byType(Scaffold));
        final paperOnDark = CoveSlipPalette.resolve(
          darkCtx,
          CoveSlipVariant.paper,
        );
        expect(paperOnDark.edgeColor, isNull);
        expect(paperOnDark.shadows, isEmpty);
      } finally {
        semanticsHandle.dispose();
      }
    },
  );
}
