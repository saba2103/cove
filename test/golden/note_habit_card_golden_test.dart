import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/cove_max_width.dart';
import 'package:cove/core/widgets/cove_section_label.dart';
import 'package:cove/core/widgets/slips/cove_habit_card.dart';
import 'package:cove/core/widgets/slips/cove_note.dart';
import 'package:cove/core/widgets/slips/cove_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _NoteShowcase extends StatelessWidget {
  const _NoteShowcase();

  static final List<CoveNoteItem> _mixedItems = <CoveNoteItem>[
    CoveNoteItem(
      title: 'Dishwasher tablets',
      addedBy: 'added by Ancy',
      isDone: false,
      onChanged: (_) {},
    ),
    CoveNoteItem(
      title: 'Gas cylinder',
      addedBy: 'added by you',
      isDone: false,
      onChanged: (_) {},
    ),
    CoveNoteItem(
      title: 'Filter coffee powder',
      addedBy: 'added by Ancy',
      isDone: true,
      onChanged: (_) {},
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

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
                  label: 'The list · Ink',
                  readout: '2 open · 1 done',
                ),
                const SizedBox(height: CoveSpace.sm),
                CoveNote(
                  key: const ValueKey('note_ink'),
                  variant: CoveSlipVariant.ink,
                  items: _mixedItems,
                ),
                const SizedBox(height: CoveSpace.md),
                const CoveSectionLabel.page(
                  label: 'The list · Paper',
                  readout: '2 open · 1 done',
                ),
                const SizedBox(height: CoveSpace.sm),
                CoveNote(
                  key: const ValueKey('note_paper'),
                  variant: CoveSlipVariant.paper,
                  items: _mixedItems,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HabitCardShowcase extends StatelessWidget {
  final CoveSlipVariant variant;

  const _HabitCardShowcase({required this.variant});

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
                  label: 'Habits · $tag',
                  readout: '23 · 7 · 0 days',
                ),
                const SizedBox(height: CoveSpace.sm),
                CoveHabitCard(
                  key: ValueKey('habit_23_${variant.name}'),
                  variant: variant,
                  title: 'Morning walk',
                  cadence: 'every day · both of you',
                  isDoneToday: true,
                  daysRunning: 23,
                  onToggle: (_) {},
                ),
                const SizedBox(height: CoveSpace.md),
                CoveHabitCard(
                  key: ValueKey('habit_7_${variant.name}'),
                  variant: variant,
                  title: 'Read twenty pages',
                  cadence: 'every day · Saba',
                  isDoneToday: true,
                  daysRunning: 7,
                  onToggle: (_) {},
                ),
                const SizedBox(height: CoveSpace.md),
                CoveHabitCard(
                  key: ValueKey('habit_0_${variant.name}'),
                  variant: variant,
                  title: 'Evening stretch',
                  cadence: 'every day · both of you',
                  isDoneToday: false,
                  daysRunning: 0,
                  onToggle: (_) {},
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
    'CoveNote & CoveHabitCard golden matrix (mixed done/open note, habit card at 0, 7 and 23 days running, paper & ink, both brightnesses)',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await goldenMatrix(
          tester,
          'note',
          const _NoteShowcase(),
        );

        final noteSem = tester.getSemantics(
          find.byKey(const ValueKey('note_ink')),
        );
        expect(
          noteSem.label,
          equals(
            'Note, COVE · GROCERY LIST, 2 open, 1 done: Dishwasher tablets (open), Gas cylinder (open), Filter coffee powder (done)',
          ),
        );

        await goldenMatrix(
          tester,
          'habit_card',
          const _HabitCardShowcase(variant: CoveSlipVariant.ink),
        );

        final habit23Sem = tester.getSemantics(
          find.byKey(const ValueKey('habit_23_ink')),
        );
        expect(
          habit23Sem.label,
          equals('Habit, Morning walk, done today, 23 days running'),
        );

        final habit0Sem = tester.getSemantics(
          find.byKey(const ValueKey('habit_0_ink')),
        );
        expect(
          habit0Sem.label,
          equals('Habit, Evening stretch, not done today, 0 days running'),
        );

        await goldenMatrix(
          tester,
          'habit_card_paper',
          const _HabitCardShowcase(variant: CoveSlipVariant.paper),
        );
      } finally {
        semanticsHandle.dispose();
      }
    },
  );
}
