import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_max_width.dart';
import 'package:cove/core/widgets/cove_section_label.dart';
import 'package:cove/features/today/letter/letter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _DayLetterShowcase extends StatelessWidget {
  const _DayLetterShowcase();

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final wednesdayClock = DateTime(2026, 10, 21, 9, 41);
    final todayDate = DateTime(2026, 10, 21);
    final tomorrowDate = DateTime(2026, 10, 22);

    final firstRunSpans = composeDayLetter(
      DayLetterInput.firstRun(
        clock: wednesdayClock,
        currencySymbol: '₹',
      ),
    );

    final quietDaySpans = composeDayLetter(
      DayLetterInput(
        clock: wednesdayClock,
        currencySymbol: '₹',
        events: [
          DayLetterEvent(
            id: 'ev-amma',
            title: 'Call with Amma',
            startTime: DateTime(2026, 10, 21, 19, 0),
          ),
        ],
        habits: const [
          DayLetterHabit(
            id: 'hab-walk',
            title: 'Morning walk',
            doneByYou: true,
            doneByPartner: true,
          ),
          DayLetterHabit(
            id: 'hab-read',
            title: 'Read twenty pages',
            doneByYou: false,
            doneByPartner: false,
          ),
        ],
        expenses: const [
          DayLetterExpense(
            id: 'exp-gifts',
            title: 'Diwali gifts — Amma, Appa',
            amount: 2491,
          ),
          DayLetterExpense(
            id: 'exp-groceries',
            title: 'Namdhari’s — the big run',
            amount: 2640,
          ),
          DayLetterExpense(
            id: 'exp-auto',
            title: 'Auto to the market',
            amount: 500,
          ),
        ],
        commitmentsDue: [
          DayLetterCommitment(
            id: 'com-ac',
            title: 'AC — the instalment',
            amount: 3974,
            dueDate: tomorrowDate,
          ),
          DayLetterCommitment(
            id: 'com-car',
            title: 'Car insurance',
            amount: 4900,
            dueDate: tomorrowDate,
          ),
        ],
        openLists: const [
          DayLetterList(
            id: 'list-grocery',
            name: 'grocery',
            openCount: 2,
          ),
        ],
      ),
    );

    final busyDaySpans = composeDayLetter(
      DayLetterInput(
        clock: wednesdayClock,
        currencySymbol: '₹',
        events: [
          DayLetterEvent(
            id: 'ev-1',
            title: 'Dentist — Dr. Nair',
            startTime: DateTime(2026, 10, 21, 7, 30),
          ),
          DayLetterEvent(
            id: 'ev-2',
            title: 'Architect review',
            startTime: DateTime(2026, 10, 21, 11, 0),
          ),
          DayLetterEvent(
            id: 'ev-3',
            title: 'Call with Amma',
            startTime: DateTime(2026, 10, 21, 19, 0),
          ),
        ],
        habits: const [
          DayLetterHabit(
            id: 'hab-1',
            title: 'Morning walk',
            doneByYou: true,
            doneByPartner: true,
          ),
          DayLetterHabit(
            id: 'hab-2',
            title: 'Stretch',
            doneByYou: true,
            doneByPartner: true,
          ),
        ],
        expenses: const [
          DayLetterExpense(
            id: 'exp-1',
            title: 'Tanishq gold coin',
            amount: 125000,
          ),
          DayLetterExpense(id: 'exp-2', title: 'Filter coffee', amount: 180),
          DayLetterExpense(id: 'exp-3', title: 'Metro top-up', amount: 200),
        ],
        tickedTaskCount: 2,
        commitmentsDue: [
          DayLetterCommitment(
            id: 'com-today',
            title: 'Broadband bill',
            amount: 1499,
            dueDate: todayDate,
          ),
          DayLetterCommitment(
            id: 'com-tomorrow',
            title: 'AC — the instalment',
            amount: 3974,
            dueDate: tomorrowDate,
          ),
        ],
        openLists: const [
          DayLetterList(id: 'l-1', name: 'grocery', openCount: 2),
          DayLetterList(id: 'l-2', name: 'hardware', openCount: 3),
        ],
      ),
    );

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
                const CoveSectionLabel.page(
                  label: 'Fixture 1 · First run',
                  readout: 'empty home',
                ),
                const SizedBox(height: CoveSpace.sm),
                CoveLetter(
                  key: const ValueKey('letter_first_run'),
                  spans: firstRunSpans,
                ),
                const SizedBox(height: CoveSpace.section),
                const CoveSectionLabel.page(
                  label: 'Fixture 2 · Wednesday',
                  readout: 'all six sentences',
                ),
                const SizedBox(height: CoveSpace.sm),
                CoveLetter(
                  key: const ValueKey('letter_quiet_day'),
                  spans: quietDaySpans,
                ),
                const SizedBox(height: CoveSpace.section),
                const CoveSectionLabel.page(
                  label: 'Fixture 3 · Busy day',
                  readout: 'lakh & several lists',
                ),
                const SizedBox(height: CoveSpace.sm),
                CoveLetter(
                  key: const ValueKey('letter_busy_day'),
                  spans: busyDaySpans,
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
    'CoveLetter golden matrix (three fixtures across phone, cover, and wide widths)',
    (tester) async {
      await goldenMatrix(
        tester,
        'day_letter',
        const _DayLetterShowcase(),
      );
    },
  );

  testWidgets(
    'CoveLetter styles links with accent.fill underline, dispatches tap targets, and styles italic spans in Libre Bodoni Italic text.secondary',
    (tester) async {
      final tappedTargets = <LetterTarget>[];
      final spans = composeDayLetter(
        DayLetterInput(
          clock: DateTime(2026, 10, 21, 9, 41),
          currencySymbol: '₹',
          events: [
            DayLetterEvent(
              id: 'ev-amma',
              title: 'Call with Amma',
              startTime: DateTime(2026, 10, 21, 19, 0),
            ),
          ],
          openLists: const [
            DayLetterList(
              id: 'list-grocery',
              name: 'grocery',
              openCount: 2,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CoveTheme.darkTheme,
          home: Scaffold(
            body: CoveLetter(
              key: const ValueKey('interactive_letter'),
              spans: spans,
              onTapTarget: tappedTargets.add,
            ),
          ),
        ),
      );

      final richText = tester.widget<RichText>(
        find.descendant(
          of: find.byKey(const ValueKey('interactive_letter')),
          matching: find.byType(RichText),
        ),
      );
      final rootSpan = richText.text as TextSpan;
      final letterRoot = rootSpan.children != null &&
              rootSpan.children!.length == 1 &&
              (rootSpan.children!.single as TextSpan).children != null
          ? rootSpan.children!.single as TextSpan
          : rootSpan;
      final children = letterRoot.children!.cast<TextSpan>();

      // Find the link span ("Call with Amma")
      final linkSpan = children.firstWhere(
        (s) => s.text == 'Call with Amma',
      );
      expect(linkSpan.style?.decoration, equals(TextDecoration.underline));
      expect(
        linkSpan.style?.decorationColor,
        equals(CoveTokens.dark.accentFill),
      );
      expect(linkSpan.style?.color, equals(CoveTokens.dark.textPrimary));
      expect(linkSpan.recognizer, isA<TapGestureRecognizer>());

      // Invoke tap on the link recognizer
      (linkSpan.recognizer as TapGestureRecognizer).onTap!();
      expect(
        tappedTargets,
        equals(const <LetterTarget>[LetterTarget.event('ev-amma')]),
      );

      // Find the italic span ("Two lines are still on the grocery list.")
      final italicSpan = children.firstWhere(
        (s) => s.text == 'Two lines are still on the grocery list.',
      );
      expect(italicSpan.style?.fontFamily, equals('LibreBodoni'));
      expect(italicSpan.style?.fontStyle, equals(FontStyle.italic));
      expect(italicSpan.style?.color, equals(CoveTokens.dark.textSecondary));
    },
  );
}
