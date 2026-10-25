import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/cove_avatar.dart';
import 'package:cove/core/widgets/cove_round_button.dart';
import 'package:cove/core/widgets/cove_sheet.dart';
import 'package:cove/core/widgets/slips/cove_slip.dart';
import 'package:cove/features/add/add_draft.dart';
import 'package:cove/features/add/widgets/add_step_pieces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// Shared step-page frame used in the piece showcases so each piece is rendered
/// in its real `CoveSheet` context with `AddProgressSegments`, `AddCrumbs`,
/// question heading, and `AddStepFoot`.
class _StepPieceScaffold extends StatelessWidget {
  final String kindLabel;
  final int currentStep;
  final int totalSteps;
  final List<AddCrumbItem> crumbs;
  final String question;
  final Widget body;

  const _StepPieceScaffold({
    required this.kindLabel,
    required this.currentStep,
    required this.totalSteps,
    this.crumbs = const <AddCrumbItem>[],
    required this.question,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: SingleChildScrollView(
          child: CoveSheet(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top row: Back, KIND · STEP OF TOTAL, Close
                Row(
                  children: [
                    CoveRoundButton(
                      icon: Icons.arrow_back,
                      semanticLabel: 'Back',
                      onPressed: () {},
                    ),
                    const SizedBox(width: CoveSpace.sm),
                    Expanded(
                      child: RichText(
                        maxLines: 1,
                        text: TextSpan(
                          style: CoveType.capsPage.copyWith(
                            color: cv.textPrimary,
                          ),
                          children: [
                            TextSpan(text: kindLabel),
                            TextSpan(
                              text: ' · $currentStep OF $totalSteps',
                              style: CoveType.capsPage.copyWith(
                                color: cv.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    CoveRoundButton(
                      icon: Icons.close,
                      semanticLabel: 'Close',
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: CoveSpace.sm),

                // Progress segments
                AddProgressSegments(
                  currentStep: currentStep,
                  totalSteps: totalSteps,
                ),

                // Crumbs
                if (crumbs.isNotEmpty) ...[
                  const SizedBox(height: CoveSpace.md),
                  AddCrumbs(
                    crumbs: crumbs,
                    onSelectStep: (_) {},
                  ),
                ],

                const SizedBox(height: CoveSpace.lg),

                // Centred display question
                Text(
                  question,
                  textAlign: TextAlign.center,
                  style: CoveType.title.copyWith(color: cv.textPrimary),
                ),
                const SizedBox(height: CoveSpace.lg),

                // Step piece body
                body,

                const SizedBox(height: CoveSpace.lg),

                // Foot
                AddStepFoot(
                  visibility: CoveSlipVisibility.bothCanSee,
                  onToggleVisibility: () {},
                  enabled: true,
                  onPrimaryTap: () {},
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
  final fixedToday = DateTime(2026, 10, 5);

  testWidgets(
    'AddKeypad, AddProgressSegments, and AddStepFoot golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_piece_keypad',
        _StepPieceScaffold(
          kindLabel: 'EXPENSE',
          currentStep: 1,
          totalSteps: 7,
          question: 'How much?',
          body: AddKeypad(
            value: 2140,
            subtitle: 'Last time at Toit, ₹1,280',
            carriedLine: 'Namdhari’s · Groceries · BOB — last time ₹2,140',
            onChanged: (_) {},
          ),
        ),
      );
    },
  );

  testWidgets(
    'AddDayStrip and AddCrumbs golden matrix (3 widths × 2 modes)',
    (tester) async {
      final days = anchoredDays(AddKind.expense, fixedToday);
      await goldenMatrix(
        tester,
        'add_piece_day_strip',
        _StepPieceScaffold(
          kindLabel: 'EXPENSE',
          currentStep: 3,
          totalSteps: 7,
          crumbs: const <AddCrumbItem>[
            AddCrumbItem(stepIndex: 0, label: '₹2,140'),
            AddCrumbItem(stepIndex: 1, label: 'Namdhari’s'),
          ],
          question: 'When?',
          body: AddDayStrip(
            days: days,
            anchorDate: fixedToday,
            today: fixedToday,
            selectedDate: fixedToday,
            onSelected: (_) {},
          ),
        ),
      );
    },
  );

  testWidgets(
    'AddMonthDayGrid golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_piece_month_day_grid',
        _StepPieceScaffold(
          kindLabel: 'COMMITMENT',
          currentStep: 4,
          totalSteps: 7,
          crumbs: const <AddCrumbItem>[
            AddCrumbItem(stepIndex: 0, label: 'Spotify Duo'),
            AddCrumbItem(stepIndex: 1, label: '₹149'),
            AddCrumbItem(stepIndex: 2, label: 'Every month'),
          ],
          question: 'Which day of the month?',
          body: AddMonthDayGrid(
            selectedDay: 1,
            onSelected: (_) {},
          ),
        ),
      );
    },
  );

  testWidgets(
    'AddNextDatePicker golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_piece_next_date_picker',
        _StepPieceScaffold(
          kindLabel: 'COMMITMENT',
          currentStep: 4,
          totalSteps: 7,
          crumbs: const <AddCrumbItem>[
            AddCrumbItem(stepIndex: 0, label: 'Car insurance'),
            AddCrumbItem(stepIndex: 1, label: '₹14,200'),
            AddCrumbItem(stepIndex: 2, label: 'Every year'),
          ],
          question: 'When is the next one due?',
          body: AddNextDatePicker(
            today: fixedToday,
            selectedMonth: 11,
            selectedDay: 15,
            onChanged: (_, _, _) {},
          ),
        ),
      );
    },
  );

  testWidgets(
    'AddClockFace golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_piece_clock_face',
        _StepPieceScaffold(
          kindLabel: 'EVENT',
          currentStep: 3,
          totalSteps: 5,
          crumbs: const <AddCrumbItem>[
            AddCrumbItem(stepIndex: 0, label: 'Dinner with Meera & Rohan'),
            AddCrumbItem(stepIndex: 1, label: 'Thursday'),
          ],
          question: 'What time?',
          body: AddClockFace(
            hour: 20,
            minute: 0,
            showAllDay: true,
            isAllDay: false,
            onChanged: (_, _) {},
            onAllDayChanged: (_) {},
          ),
        ),
      );
    },
  );

  testWidgets(
    'AddWeekToggles golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_piece_week_toggles',
        _StepPieceScaffold(
          kindLabel: 'ROUTINE',
          currentStep: 4,
          totalSteps: 5,
          crumbs: const <AddCrumbItem>[
            AddCrumbItem(stepIndex: 0, label: 'Morning tea'),
            AddCrumbItem(stepIndex: 1, label: '8:00 AM'),
            AddCrumbItem(stepIndex: 2, label: '30 min'),
          ],
          question: 'Which days?',
          body: AddWeekToggles(
            selectedDays: const <int>{1, 2, 3, 4, 5},
            onChanged: (_) {},
          ),
        ),
      );
    },
  );

  testWidgets(
    'AddChoiceList golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_piece_choice_list',
        Builder(
          builder: (context) {
            final cv = context.cv;
            return _StepPieceScaffold(
              kindLabel: 'EXPENSE',
              currentStep: 4,
              totalSteps: 7,
              crumbs: const <AddCrumbItem>[
                AddCrumbItem(stepIndex: 0, label: '₹2,140'),
                AddCrumbItem(stepIndex: 1, label: 'Namdhari’s'),
                AddCrumbItem(stepIndex: 2, label: 'Today'),
              ],
              question: 'Which category?',
              body: AddChoiceList<String>(
                selectedValue: 'groceries',
                onSelected: (_) {},
                options: <AddChoiceOption<String>>[
                  AddChoiceOption<String>(
                    value: 'groceries',
                    label: 'Groceries',
                    swatchColor: cv.categoryGroceries,
                  ),
                  AddChoiceOption<String>(
                    value: 'eating_out',
                    label: 'Eating out',
                    swatchColor: cv.categoryEatingOut,
                  ),
                  AddChoiceOption<String>(
                    value: 'fuel',
                    label: 'Fuel',
                    swatchColor: cv.categoryFuel,
                  ),
                  AddChoiceOption<String>(
                    value: 'home',
                    label: 'Home',
                    swatchColor: cv.categoryHome,
                    subtitle: 'rent, utilities & upkeep',
                  ),
                  AddChoiceOption<String>(
                    value: 'health',
                    label: 'Health',
                    swatchColor: cv.categoryHealth,
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );

  testWidgets(
    'AddPersonPicker golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_piece_person_picker',
        _StepPieceScaffold(
          kindLabel: 'EXPENSE',
          currentStep: 5,
          totalSteps: 7,
          crumbs: const <AddCrumbItem>[
            AddCrumbItem(stepIndex: 0, label: '₹2,140'),
            AddCrumbItem(stepIndex: 1, label: 'Namdhari’s'),
            AddCrumbItem(stepIndex: 2, label: 'Today'),
            AddCrumbItem(stepIndex: 3, label: 'Groceries'),
          ],
          question: 'Who paid?',
          body: AddPersonPicker<String>(
            selectedValue: 'you',
            onSelected: (_) {},
            people: const <AddPersonTileData<String>>[
              AddPersonTileData<String>(
                value: 'you',
                person: CovePerson.a,
                label: 'Saba',
                nameOrInitial: 'S',
              ),
              AddPersonTileData<String>(
                value: 'partner',
                person: CovePerson.b,
                label: 'Ancy',
                nameOrInitial: 'A',
              ),
              AddPersonTileData<String>(
                value: 'both',
                person: CovePerson.both,
                label: 'Both of you',
              ),
            ],
            toggles: <AddToggleRowData>[
              AddToggleRowData(
                id: 'split',
                title: 'Split it half and half',
                icon: Icons.call_split,
                value: true,
                onChanged: (_) {},
              ),
              AddToggleRowData(
                id: 'private',
                title: 'Keep it private',
                subtitle: 'Only you will see it — it stays out of Ancy’s Cove',
                icon: Icons.lock_outline,
                value: false,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      );
    },
  );

  testWidgets(
    'At 320dp cover width no interactive target across any step piece is under 48×48, and callbacks fire',
    (tester) async {
      await loadCoveFonts();
      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.binding.setSurfaceSize(const Size(320, 2600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var amount = 21;
        var selectedDay = fixedToday;
        var monthDay = 5;
        var nextMonth = 10;
        var nextDay = 15;
        var clockHour = 8;
        var clockMinute = 0;
        var isAllDay = false;
        var weekDays = <int>{1, 2, 3, 4, 5};
        var choice = 'a';
        var person = 'you';
        var splitToggle = true;
        var tappedCrumb = -1;
        var tappedNext = 0;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 2600),
                  textScaler: TextScaler.linear(1.0),
                ),
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: coveThemeFor(Brightness.dark),
                  home: Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CoveSpace.gutter,
                        vertical: CoveSpace.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AddProgressSegments(
                            currentStep: 2,
                            totalSteps: 7,
                          ),
                          const SizedBox(height: CoveSpace.sm),
                          AddCrumbs(
                            crumbs: const <AddCrumbItem>[
                              AddCrumbItem(stepIndex: 0, label: '₹2,140'),
                              AddCrumbItem(
                                stepIndex: 1,
                                label:
                                    'A very long answer that wraps across lines and never ellipsizes at 320dp',
                              ),
                            ],
                            onSelectStep: (idx) =>
                                setState(() => tappedCrumb = idx),
                          ),
                          const SizedBox(height: CoveSpace.md),
                          AddKeypad(
                            value: amount,
                            onChanged: (v) => setState(() => amount = v),
                          ),
                          const SizedBox(height: CoveSpace.md),
                          AddDayStrip(
                            days: anchoredDays(AddKind.expense, fixedToday),
                            anchorDate: fixedToday.subtract(
                              const Duration(days: 2),
                            ),
                            today: fixedToday,
                            selectedDate: selectedDay,
                            showNoParticularDay: true,
                            onSelectNoParticularDay: () {},
                            onSelected: (d) => setState(() => selectedDay = d),
                          ),
                          const SizedBox(height: CoveSpace.md),
                          AddMonthDayGrid(
                            selectedDay: monthDay,
                            onSelected: (d) => setState(() => monthDay = d),
                          ),
                          const SizedBox(height: CoveSpace.md),
                          AddNextDatePicker(
                            today: fixedToday,
                            selectedMonth: nextMonth,
                            selectedDay: nextDay,
                            onChanged: (m, d, _) => setState(() {
                              nextMonth = m;
                              nextDay = d;
                            }),
                          ),
                          const SizedBox(height: CoveSpace.md),
                          AddClockFace(
                            hour: clockHour,
                            minute: clockMinute,
                            showAllDay: true,
                            isAllDay: isAllDay,
                            onChanged: (h, m) => setState(() {
                              clockHour = h;
                              clockMinute = m;
                            }),
                            onAllDayChanged: (v) =>
                                setState(() => isAllDay = v),
                          ),
                          const SizedBox(height: CoveSpace.md),
                          AddWeekToggles(
                            selectedDays: weekDays,
                            onChanged: (s) => setState(() => weekDays = s),
                          ),
                          const SizedBox(height: CoveSpace.md),
                          AddChoiceList<String>(
                            selectedValue: choice,
                            onSelected: (v) => setState(() => choice = v),
                            options: const <AddChoiceOption<String>>[
                              AddChoiceOption<String>(
                                value: 'a',
                                label: 'Every month',
                                subtitle: 'twelve times a year',
                              ),
                              AddChoiceOption<String>(
                                value: 'b',
                                label: 'Every quarter',
                                subtitle: 'four times a year',
                              ),
                            ],
                          ),
                          const SizedBox(height: CoveSpace.md),
                          AddPersonPicker<String>(
                            selectedValue: person,
                            onSelected: (v) => setState(() => person = v),
                            people: const <AddPersonTileData<String>>[
                              AddPersonTileData<String>(
                                value: 'you',
                                person: CovePerson.a,
                                label: 'Saba',
                              ),
                              AddPersonTileData<String>(
                                value: 'partner',
                                person: CovePerson.b,
                                label: 'Ancy',
                              ),
                              AddPersonTileData<String>(
                                value: 'both',
                                person: CovePerson.both,
                                label: 'Both of you',
                              ),
                            ],
                            toggles: <AddToggleRowData>[
                              AddToggleRowData(
                                id: 'split',
                                title: 'Split it half and half',
                                value: splitToggle,
                                onChanged: (v) =>
                                    setState(() => splitToggle = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: CoveSpace.md),
                          AddStepFoot(
                            visibility: CoveSlipVisibility.bothCanSee,
                            onToggleVisibility: () {},
                            enabled: true,
                            onPrimaryTap: () =>
                                setState(() => tappedNext += 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        // 1. Assert EVERY active GestureDetector (with onTap != null) has size >= 48×48dp at 320dp
        final detectors = find.byType(GestureDetector);
        var activeDetectors = 0;
        for (final element in detectors.evaluate()) {
          final gd = element.widget as GestureDetector;
          if (gd.onTap == null) continue;
          activeDetectors++;
          final box = element.renderObject! as RenderBox;
          expect(
            box.size.width,
            greaterThanOrEqualTo(CoveSize.hit),
            reason:
                'Interactive target width ${box.size.width} < 48dp on ${element.widget}',
          );
          expect(
            box.size.height,
            greaterThanOrEqualTo(CoveSize.hit),
            reason:
                'Interactive target height ${box.size.height} < 48dp on ${element.widget}',
          );
        }
        expect(activeDetectors, greaterThan(60));

        // 2. Test crumb tap and verify long crumb never ellipsizes
        final longCrumbText = tester.widget<Text>(
          find.textContaining('A very long answer that wraps across lines'),
        );
        expect(longCrumbText.maxLines, isNull);
        expect(longCrumbText.overflow, isNull);
        await tester.tap(find.bySemanticsLabel('Change ₹2,140'));
        await tester.pump();
        expect(tappedCrumb, equals(0));

        // 3. Test keypad: tap '00' -> 21 becomes 2100, then 'Delete' -> 210
        await tester.tap(find.bySemanticsLabel('00'));
        await tester.pump();
        expect(amount, equals(2100));
        await tester.tap(find.bySemanticsLabel('Delete'));
        await tester.pump();
        expect(amount, equals(210));

        // 4. Test clock face: tapping '9 o'clock' sets hour to 9 and switches to minute mode ('05 minutes' appears)
        await tester.tap(find.bySemanticsLabel("9 o'clock"));
        await tester.pump();
        expect(clockHour, equals(9));
        expect(find.bySemanticsLabel('05 minutes'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('15 minutes'));
        await tester.pump();
        expect(clockMinute, equals(15));

        // 5. Test toggle row and step foot
        await tester.tap(find.text('Split it half and half'));
        await tester.pump();
        expect(splitToggle, isFalse);

        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pump();
        expect(tappedNext, equals(1));
      } finally {
        semanticsHandle.dispose();
      }
    },
  );
}
