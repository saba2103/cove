import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/cove_seed_card.dart';
import 'package:cove/core/widgets/cove_starter_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

const Set<String> _kNoOverflows = <String>{};

Widget _scaffoldWrap(Widget child) => Builder(
      builder: (context) => Scaffold(
        backgroundColor: context.cv.surfaceCanvas,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: CoveSize.maxContent),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(CoveSpace.gutter),
              child: child,
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('4.2a First-Run Primitives Goldens (3 widths × 2 modes)', () {
    testWidgets('first_run_42a_seed_card_with_button', (tester) async {
      await goldenMatrix(
        tester,
        'first_run_42a_seed_card_with_button',
        _scaffoldWrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoveSeedCard(
                art: CoveSeedArtKind.sprout,
                title: 'Start with one small thing',
                body:
                    'Add a dinner expense, a habit you both want to keep, or a '
                    'single item on the grocery list. Today fills itself in '
                    'from whatever the two of you put in Cove.',
                buttonLabel: 'Add the first thing',
                onPressed: () {},
              ),
              const SizedBox(height: CoveSpace.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  CoveSeedArt(CoveSeedArtKind.calendar, size: 32),
                  CoveSeedArt(CoveSeedArtKind.bands, size: 32),
                  CoveSeedArt(CoveSeedArtKind.coin, size: 32),
                  CoveSeedArt(CoveSeedArtKind.arrows, size: 32),
                  CoveSeedArt(CoveSeedArtKind.wave, size: 32),
                  CoveSeedArt(CoveSeedArtKind.key, size: 32),
                ],
              ),
            ],
          ),
        ),
        allowedOverflows: _kNoOverflows,
      );
    });

    testWidgets('first_run_42a_seed_card_without_button_and_alt', (
      tester,
    ) async {
      await goldenMatrix(
        tester,
        'first_run_42a_seed_card_without_button_and_alt',
        _scaffoldWrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CoveSeedCard(
                art: CoveSeedArtKind.wave,
                title: 'Nothing has happened yet',
                body:
                    'When Ancy adds something, ticks something off or marks a '
                    'bill paid, it shows up here — and nowhere else, so '
                    'nothing has to interrupt you.',
                altText:
                    'Cove never sends a notification you did not ask for.',
              ),
              const SizedBox(height: CoveSpace.md),
              CoveSeedCard(
                art: CoveSeedArtKind.key,
                title: 'A home with one person in it',
                body:
                    'Cove only becomes itself when there are two of you. Send '
                    'Ancy a key — everything you add before they join is '
                    'waiting for them.',
                buttonLabel: 'Send a key',
                onPressed: () {},
                altText: 'Or share a code · ',
                altAccentText: 'NEST-4471',
              ),
            ],
          ),
        ),
        allowedOverflows: _kNoOverflows,
      );
    });

    testWidgets('first_run_42a_starter_rows', (tester) async {
      await goldenMatrix(
        tester,
        'first_run_42a_starter_rows',
        _scaffoldWrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoveStarterRow(
                icon: Icons.credit_card_outlined,
                title: 'Log an expense',
                subtitle: 'split a bill or note who paid',
                onTap: () {},
              ),
              const SizedBox(height: CoveSpace.sm),
              CoveStarterRow(
                icon: Icons.auto_awesome_outlined,
                title: 'Start a shared habit',
                subtitle: 'something you both do most days',
                onTap: () {},
              ),
              const SizedBox(height: CoveSpace.sm),
              CoveStarterRow(
                icon: Icons.checklist_rounded,
                title: 'Add to the grocery list',
                subtitle: 'one list, on both phones',
                onTap: () {},
              ),
              const SizedBox(height: CoveSpace.md),
              CoveStarterRow(
                icon: Icons.autorenew_rounded,
                title: 'Rent or maintenance',
                subtitle: 'the one that never changes',
                onTap: () {},
              ),
              const SizedBox(height: CoveSpace.sm),
              CoveStarterRow(
                icon: Icons.credit_card_outlined,
                title: 'An EMI you are paying off',
                subtitle: 'so you can see when it ends',
                onTap: () {},
              ),
              const SizedBox(height: CoveSpace.sm),
              CoveStarterRow(
                icon: Icons.schedule_rounded,
                title: 'A subscription',
                subtitle: 'the ones that renew quietly',
                onTap: () {},
              ),
            ],
          ),
        ),
        allowedOverflows: _kNoOverflows,
      );
    });
  });
}
