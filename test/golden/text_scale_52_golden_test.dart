// Phase 5.2 — Text at 200% (WCAG 1.4.4 Resize Text, WCAG 1.4.10 Reflow).
//
// 1. Pumps every screen at `TextScaler.linear(1.3)` and `TextScaler.linear(2.0)`
//    across `320dp` (`CoveWidth.cover`) and `411dp` (`CoveWidth.phone`) in both
//    `Brightness.dark` and `Brightness.light`, keeps the overflow guard ON,
//    asserts zero clipped `RenderParagraph`s and zero `didExceedMaxLines`
//    ellipsis truncation, and matches golden PNGs under
//    `test/golden/goldens/text_scale_52/`.
// 2. Runs the same overflow, clipped-text, and ellipsis guard across all
//    remaining screen variants, all 35 sheets/modals/dialogs, and all 44 Add
//    flow steps across `{1.3x, 2.0x} × {320dp, 411dp} × {dark, light}` (920
//    total combinations).
// 3. Explicitly verifies all five reflow behaviours required by 5.2:
//    - metric grids (`CoveMetricGrid`) stack to one column
//    - side-by-side rows (`CoveRow`, `AddPersonPicker`) stack
//    - the floating bar (`CoveFloatingBar`) drops to icons only
//    - the Add keypad (`AddKeypad`) keys grow taller
//    - slips (`CoveReceipt`, `CoveTicket`, `CoveVoucher`, `CoveHabitCard`,
//      `CoveNote`) let their text wrap without ellipsis.
import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/utils/cove_currency_formatter.dart';
import 'package:cove/core/widgets/cove_avatar.dart';
import 'package:cove/core/widgets/cove_floating_bar.dart';
import 'package:cove/core/widgets/cove_metric_card.dart';
import 'package:cove/core/widgets/cove_row.dart';
import 'package:cove/core/widgets/slips/cove_habit_card.dart';
import 'package:cove/core/widgets/slips/cove_note.dart';
import 'package:cove/core/widgets/slips/cove_receipt.dart';
import 'package:cove/core/widgets/slips/cove_slip.dart';
import 'package:cove/core/widgets/slips/cove_ticket.dart';
import 'package:cove/core/widgets/slips/cove_voucher.dart';
import 'package:cove/features/add/widgets/add_keypad.dart';
import 'package:cove/features/add/widgets/add_person_picker.dart';
import 'package:cove/features/today/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../a11y/a11y_fixtures.dart';
import '../a11y/a11y_harness.dart';

/// Every distinct screen in Cove (+ floating bar hosts and Add keypad screen)
/// captured as goldens across `{1.3x, 2.0x} × {320dp, 411dp} × {dark, light}`.
const Set<String> _kGoldenScreenIds = <String>{
  'today_screen',
  'today_screen_floating_bar',
  'calendar_screen',
  'calendar_month_view',
  'expenses_screen',
  'expenses_screen_floating_bar',
  'subscriptions_screen',
  'emi_tracker_screen',
  'commitments_helicopter_screen',
  'routine_screen',
  'lists_screen',
  'habits_screen',
  'activity_screen',
  'home_settings_screen',
  'profile_screen',
  'about_cove_screen',
  'changelog_screen',
  'reminders_screen',
  'roadmap_screen',
  'sign_in_screen',
  'onboarding_choice_screen',
  'create_home_screen',
  'join_home_screen',
  'missing_home_key_screen',
  'cove_splash_screen',
  'add_expense_1_amount',
};

const List<(String, Size)> _kWidths = <(String, Size)>[
  ('cover', CoveWidth.cover), // 320x780dp
  ('phone', CoveWidth.phone), // 411x914dp
];

const List<(String, double)> _kScales = <(String, double)>[
  ('1_3x', 1.3),
  ('2_0x', 2.0),
];

const List<Brightness> _kModes = <Brightness>[
  Brightness.dark,
  Brightness.light,
];

/// Walks all live [RenderParagraph] nodes in the render tree and fails if any
/// label is truncated by `maxLines` / `ellipsis` (`didExceedMaxLines`) or
/// clipped inside its layout box or a non-scrollable ancestor clip.
void _assertNoTextClipOrEllipsis(
  WidgetTester tester, {
  required String contextLabel,
}) {
  final issues = <String>[];

  void visit(RenderObject node) {
    if (node is RenderParagraph && node.hasSize) {
      final plain = node.text.toPlainText().replaceAll('\n', '↵').trim();
      if (plain.isNotEmpty) {
        final boxSize = node.size;
        final textSize = node.textSize;
        if (boxSize.width > 0.1 && boxSize.height > 0.1) {
          if (node.didExceedMaxLines) {
            issues.add(
              'ELLIPSIS/MAXLINES on "$plain" '
              '(box=${boxSize.width.toStringAsFixed(1)}x${boxSize.height.toStringAsFixed(1)}, '
              'maxLines=${node.maxLines}, overflow=${node.overflow})',
            );
          } else if (textSize.width > boxSize.width + 1.0 ||
              textSize.height > boxSize.height + 1.0) {
            issues.add(
              'TEXT_CLIP on "$plain" '
              '(text=${textSize.width.toStringAsFixed(1)}x${textSize.height.toStringAsFixed(1)} > '
              'box=${boxSize.width.toStringAsFixed(1)}x${boxSize.height.toStringAsFixed(1)})',
            );
          } else {
            RenderObject? parent = node.parent;
            while (parent != null) {
              if (parent is RenderAbstractViewport) break;
              if (parent is RenderClipRect ||
                  parent is RenderClipRRect ||
                  parent is RenderClipPath) {
                if (parent is RenderBox && parent.hasSize) {
                  final topLeft = node.localToGlobal(
                    Offset.zero,
                    ancestor: parent,
                  );
                  final bottomRight = node.localToGlobal(
                    Offset(boxSize.width, boxSize.height),
                    ancestor: parent,
                  );
                  final pSize = parent.size;
                  if (bottomRight.dx > pSize.width + 1.5 || topLeft.dx < -1.5) {
                    issues.add(
                      'CLIP_X on "$plain" '
                      '(${topLeft.dx.toStringAsFixed(1)}..${bottomRight.dx.toStringAsFixed(1)} '
                      'in ${pSize.width.toStringAsFixed(1)})',
                    );
                    break;
                  }
                }
              }
              parent = parent.parent;
            }
          }
        }
      }
    }
    node.visitChildren(visit);
  }

  visit(tester.binding.renderViews.first);
  expect(issues, isEmpty, reason: '$contextLabel:\n${issues.join('\n')}');
}

/// Pumps [surface] at [size], [scale], and [mode] with the overflow guard ON.
Future<void> _pumpScaledSurface(
  WidgetTester tester, {
  required A11ySurface surface,
  required Size size,
  required double scale,
  required Brightness mode,
}) async {
  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2.0;

  await withClock(surface.clock ?? kDefaultGoldenClock, () async {
    final child = surface.build();
    await tester.pumpWidget(
      ProviderScope(
        overrides: surface.overrides(),
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            padding: surface.insets,
            viewPadding: surface.insets,
          ),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: coveThemeFor(mode),
            builder: (context, navChild) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: size,
                textScaler: TextScaler.linear(scale),
                padding: surface.insets,
                viewPadding: surface.insets,
              ),
              child: navChild ?? const SizedBox.shrink(),
            ),
            home: surface.wrap != null ? surface.wrap!(child) : child,
          ),
        ),
      ),
    );

    if (surface.customPumpDuration != null ||
        surface.id == 'restore_backup_sheet') {
      await tester.pump(
        surface.customPumpDuration ?? const Duration(milliseconds: 500),
      );
    } else {
      await tester.pumpAndSettle();
    }

    if (surface.afterPump != null) {
      await surface.afterPump!(tester);
    }
  });
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  final screenSurfaces = buildScreenA11ySurfaces();
  final sheetSurfaces = buildSheetA11ySurfaces();
  final addFlowSurfaces = buildAddFlowA11ySurfaces();
  final allSurfaces = <A11ySurface>[
    ...screenSurfaces,
    ...sheetSurfaces,
    ...addFlowSurfaces,
  ];

  final goldenSurfaces = allSurfaces
      .where((s) => _kGoldenScreenIds.contains(s.id))
      .toList(growable: false);
  final nonGoldenSurfaces = allSurfaces
      .where((s) => !_kGoldenScreenIds.contains(s.id))
      .toList(growable: false);

  group(
    'Phase 5.2 — Screen Goldens & Overflow Guard (1.3x & 2.0x × 320dp & 411dp × dark & light)',
    () {
      for (final surface in goldenSurfaces) {
        testWidgets('${surface.id} (8 scaled goldens)', (tester) async {
          await ensureA11yFontsLoaded();
          addTearDown(tester.view.reset);

          for (final (widthTag, size) in _kWidths) {
            for (final (scaleTag, scale) in _kScales) {
              for (final mode in _kModes) {
                final modeTag = mode == Brightness.dark ? 'dark' : 'light';
                final label =
                    '${surface.id} @ $widthTag @ ${scale}x @ $modeTag';

                await _pumpScaledSurface(
                  tester,
                  surface: surface,
                  size: size,
                  scale: scale,
                  mode: mode,
                );

                _assertNoTextClipOrEllipsis(tester, contextLabel: label);

                await expectLater(
                  find.byType(MaterialApp),
                  matchesGoldenFile(
                    'goldens/text_scale_52/${surface.id}.$widthTag.$scaleTag.$modeTag.png',
                  ),
                );

                await tester.pumpWidget(const SizedBox.shrink());
                await tester.pump();
              }
            }
          }
        });
      }
    },
  );

  group(
    'Phase 5.2 — Overflow, Clip & Ellipsis Runs Across Remaining Variants, Sheets & Add Steps',
    () {
      testWidgets(
        'remaining screen variants hold at 1.3x and 2.0x (320dp & 411dp, both modes)',
        (tester) async {
          await ensureA11yFontsLoaded();
          addTearDown(tester.view.reset);

          final remainingScreens = nonGoldenSurfaces
              .where((s) => s.category == 'Screens')
              .toList(growable: false);

          for (final surface in remainingScreens) {
            for (final (widthTag, size) in _kWidths) {
              for (final (_, scale) in _kScales) {
                for (final mode in _kModes) {
                  await _pumpScaledSurface(
                    tester,
                    surface: surface,
                    size: size,
                    scale: scale,
                    mode: mode,
                  );
                  _assertNoTextClipOrEllipsis(
                    tester,
                    contextLabel:
                        '${surface.id} @ $widthTag @ ${scale}x @ ${mode.name}',
                  );
                  await tester.pumpWidget(const SizedBox.shrink());
                  await tester.pump();
                }
              }
            }
          }
        },
      );

      testWidgets(
        'all 35 sheets, modals & dialogs hold at 1.3x and 2.0x (320dp & 411dp, both modes)',
        (tester) async {
          await ensureA11yFontsLoaded();
          addTearDown(tester.view.reset);

          for (final surface in sheetSurfaces) {
            for (final (widthTag, size) in _kWidths) {
              for (final (_, scale) in _kScales) {
                for (final mode in _kModes) {
                  await _pumpScaledSurface(
                    tester,
                    surface: surface,
                    size: size,
                    scale: scale,
                    mode: mode,
                  );
                  _assertNoTextClipOrEllipsis(
                    tester,
                    contextLabel:
                        '${surface.id} @ $widthTag @ ${scale}x @ ${mode.name}',
                  );
                  await tester.pumpWidget(const SizedBox.shrink());
                  await tester.pump();
                }
              }
            }
          }
        },
      );

      testWidgets(
        'all remaining Add flow steps hold at 1.3x and 2.0x (320dp & 411dp, both modes)',
        (tester) async {
          await ensureA11yFontsLoaded();
          addTearDown(tester.view.reset);

          final remainingAddSteps = nonGoldenSurfaces
              .where((s) => s.category == 'Add Flow')
              .toList(growable: false);

          for (final surface in remainingAddSteps) {
            for (final (widthTag, size) in _kWidths) {
              for (final (_, scale) in _kScales) {
                for (final mode in _kModes) {
                  await _pumpScaledSurface(
                    tester,
                    surface: surface,
                    size: size,
                    scale: scale,
                    mode: mode,
                  );
                  _assertNoTextClipOrEllipsis(
                    tester,
                    contextLabel:
                        '${surface.id} @ $widthTag @ ${scale}x @ ${mode.name}',
                  );
                  await tester.pumpWidget(const SizedBox.shrink());
                  await tester.pump();
                }
              }
            }
          }
        },
      );
    },
  );

  group('Phase 5.2 — Explicit WCAG 1.4.4 / 1.4.10 Reflow Rules', () {
    testWidgets('metric grids stack to one column at 1.3x and 2.0x', (
      tester,
    ) async {
      await ensureA11yFontsLoaded();
      addTearDown(tester.view.reset);

      final todaySurface = screenSurfaces.firstWhere(
        (s) => s.id == 'today_screen',
      );

      // At 1.0x (411dp), top two CoveMetricCards sit side-by-side (2 columns).
      await _pumpScaledSurface(
        tester,
        surface: todaySurface,
        size: CoveWidth.phone,
        scale: 1.0,
        mode: Brightness.dark,
      );
      final cards1x = find.descendant(
        of: find.byType(TodayScreen),
        matching: find.byType(CoveMetricCard),
      );
      expect(cards1x, findsAtLeastNWidgets(2));
      expect(
        tester.getTopLeft(cards1x.at(0)).dy,
        closeTo(tester.getTopLeft(cards1x.at(1)).dy, 0.5),
      );

      // At 1.3x and 2.0x (both 320dp and 411dp), CoveMetricCards stack to 1 column.
      for (final (_, size) in _kWidths) {
        for (final (_, scale) in _kScales) {
          await _pumpScaledSurface(
            tester,
            surface: todaySurface,
            size: size,
            scale: scale,
            mode: Brightness.dark,
          );
          final cardsScaled = find.descendant(
            of: find.byType(TodayScreen),
            matching: find.byType(CoveMetricCard),
          );
          expect(cardsScaled, findsAtLeastNWidgets(2));
          final firstRect = tester.getRect(cardsScaled.at(0));
          final secondRect = tester.getRect(cardsScaled.at(1));
          expect(firstRect.left, closeTo(secondRect.left, 0.5));
          expect(firstRect.width, closeTo(secondRect.width, 0.5));
          expect(secondRect.top, greaterThanOrEqualTo(firstRect.bottom - 0.5));
        }
      }
    });

    testWidgets('side-by-side rows stack when scaled at narrow width', (
      tester,
    ) async {
      await ensureA11yFontsLoaded();
      addTearDown(tester.view.reset);

      // 1. CoveRow stacks wide trailing amount below title at 320dp @ 2.0x.
      tester.view
        ..physicalSize = CoveWidth.cover * 2
        ..devicePixelRatio = 2.0;

      const rowTitle = 'Quarterly Sanctuary Solar & Maintenance Reserve';
      final rowAmount = '₹${formatCoveAmount(124850.5)}';

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: CoveWidth.cover,
            textScaler: TextScaler.linear(2.0),
          ),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: coveThemeFor(Brightness.dark),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: CoveWidth.cover,
                textScaler: const TextScaler.linear(2.0),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(CoveSpace.gutter),
                child: CoveRow(
                  avatar: const CoveAvatar.row(
                    person: CovePerson.a,
                    nameOrInitial: 'Alex',
                  ),
                  title: rowTitle,
                  subtitle: 'Home & Utilities · SBI Home Finance',
                  amount: rowAmount,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      _assertNoTextClipOrEllipsis(tester, contextLabel: 'CoveRow @ 320dp 2.0x');
      final titleRect = tester.getRect(find.text(rowTitle));
      final amountRect = tester.getRect(find.text(rowAmount));
      expect(amountRect.top, greaterThanOrEqualTo(titleRect.bottom - 0.5));

      // 2. AddPersonPicker tiles stack into one column at 320dp @ 2.0x.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: CoveWidth.cover,
            textScaler: TextScaler.linear(2.0),
          ),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: coveThemeFor(Brightness.dark),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: CoveWidth.cover,
                textScaler: const TextScaler.linear(2.0),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(CoveSpace.gutter),
                child: AddPersonPicker<String>(
                  people: const <AddPersonTileData<String>>[
                    AddPersonTileData<String>(
                      value: 'saba',
                      person: CovePerson.a,
                      label: 'Saba',
                      nameOrInitial: 'Saba',
                    ),
                    AddPersonTileData<String>(
                      value: 'ancy',
                      person: CovePerson.b,
                      label: 'Ancy',
                      nameOrInitial: 'Ancy',
                    ),
                  ],
                  selectedValue: 'saba',
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final sabaRect = tester.getRect(find.text('Saba'));
      final ancyRect = tester.getRect(find.text('Ancy'));
      expect(ancyRect.top, greaterThanOrEqualTo(sabaRect.bottom - 0.5));
    });

    testWidgets('the floating bar drops to icons only when text is scaled', (
      tester,
    ) async {
      await ensureA11yFontsLoaded();
      addTearDown(tester.view.reset);

      final barSurface = screenSurfaces.firstWhere(
        (s) => s.id == 'today_screen_floating_bar',
      );

      // At 1.0x, destination text labels are visible inside CoveFloatingBar.
      await _pumpScaledSurface(
        tester,
        surface: barSurface,
        size: CoveWidth.phone,
        scale: 1.0,
        mode: Brightness.dark,
      );
      for (final label in const <String>['Home', 'Money', 'Tasks', 'Calendar']) {
        expect(
          find.descendant(
            of: find.byType(CoveFloatingBar),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }

      // At 1.3x and 2.0x, CoveFloatingBar drops text labels (icons + Add orb stay).
      for (final (_, scale) in _kScales) {
        await _pumpScaledSurface(
          tester,
          surface: barSurface,
          size: CoveWidth.cover,
          scale: scale,
          mode: Brightness.dark,
        );
        for (final label in const <String>[
          'Home',
          'Money',
          'Tasks',
          'Calendar',
        ]) {
          expect(
            find.descendant(
              of: find.byType(CoveFloatingBar),
              matching: find.text(label),
            ),
            findsNothing,
          );
        }
        expect(find.byKey(const ValueKey('cove_bar_add_orb')), findsOneWidget);
      }
    });

    testWidgets('the Add keypad keys grow taller at 1.3x and 2.0x', (
      tester,
    ) async {
      await ensureA11yFontsLoaded();
      addTearDown(tester.view.reset);

      Future<double> measureDigitFiveHeight(double scale) async {
        tester.view
          ..physicalSize = CoveWidth.cover * 2
          ..devicePixelRatio = 2.0;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: CoveWidth.cover,
              textScaler: TextScaler.linear(scale),
            ),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: coveThemeFor(Brightness.dark),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: CoveWidth.cover,
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AddKeypad(value: 2140, onChanged: (_) {}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        _assertNoTextClipOrEllipsis(
          tester,
          contextLabel: 'AddKeypad @ ${scale}x',
        );
        final keyDetector = find
            .ancestor(
              of: find.text('5'),
              matching: find.byType(GestureDetector),
            )
            .first;
        return tester.getSize(keyDetector).height;
      }

      final h10 = await measureDigitFiveHeight(1.0);
      final h13 = await measureDigitFiveHeight(1.3);
      final h20 = await measureDigitFiveHeight(2.0);

      expect(h10, closeTo(CoveSize.row, 0.5));
      expect(h13, greaterThan(h10));
      expect(h20, greaterThan(h13));
    });

    testWidgets('slips let their text wrap without ellipsis at 200% text', (
      tester,
    ) async {
      await ensureA11yFontsLoaded();
      addTearDown(tester.view.reset);

      tester.view
        ..physicalSize = CoveWidth.cover * 2
        ..devicePixelRatio = 2.0;

      const longReceiptTitle =
          'Organic Farmers Market Produce & Artisanal Sourdough Run';
      const longTicketTitle =
          'Anniversary Dinner Reservation With Candlelight Terrace Table';
      const longVoucherTitle =
          'Annual Rooftop Solar Panel & Inverter Maintenance Plan';
      const longHabitTitle =
          'Twenty Minutes of Quiet Evening Reading Without Screens';
      const longNoteTitle =
          'Pick Up Refillable Brass Coffee Canister & Filter Paper';

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: CoveWidth.cover,
            textScaler: TextScaler.linear(2.0),
          ),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: coveThemeFor(Brightness.dark),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: CoveWidth.cover,
                textScaler: const TextScaler.linear(2.0),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(CoveSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CoveReceipt(
                      variant: CoveSlipVariant.ink,
                      recordId: 'receipt-52-wrap',
                      title: 'Thursday Evening Market Run',
                      items: <CoveReceiptItem>[
                        CoveReceiptItem(
                          payer: CovePerson.a,
                          nameOrInitial: 'Saba',
                          title: longReceiptTitle,
                          subtitle: 'Groceries · UPI Shared Account',
                          amount: '₹${formatCoveAmount(2640)}',
                          onTap: () {},
                        ),
                      ],
                      totalAmount: '₹${formatCoveAmount(2640)}',
                      footerDate: 'THURSDAY, OCT 15',
                    ),
                    const SizedBox(height: CoveSpace.md),
                    CoveTicket(
                      variant: CoveSlipVariant.ink,
                      title: longTicketTitle,
                      date: 'Thursday, Oct 15',
                      owner: 'Both of you',
                      hour: '8',
                      meridiem: 'PM',
                      onTap: () {},
                    ),
                    const SizedBox(height: CoveSpace.md),
                    CoveVoucher(
                      variant: CoveSlipVariant.ink,
                      title: longVoucherTitle,
                      amount: '₹${formatCoveAmount(8500)}',
                      dueDay: '25',
                      dueMonth: 'OCT',
                      dueMonthSemantic: 'October',
                      state: CoveVoucherState.due,
                      onTap: () {},
                    ),
                    const SizedBox(height: CoveSpace.md),
                    CoveHabitCard(
                      variant: CoveSlipVariant.ink,
                      title: longHabitTitle,
                      cadence: 'every evening · both of you',
                      isDoneToday: true,
                      daysRunning: 23,
                      onToggle: (_) {},
                    ),
                    const SizedBox(height: CoveSpace.md),
                    CoveNote(
                      variant: CoveSlipVariant.ink,
                      items: <CoveNoteItem>[
                        CoveNoteItem(
                          title: longNoteTitle,
                          addedBy: 'added by Ancy',
                          isDone: false,
                          onChanged: (_) {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      _assertNoTextClipOrEllipsis(
        tester,
        contextLabel: 'All slips @ 320dp 2.0x',
      );

      for (final longTitle in const <String>[
        longReceiptTitle,
        longTicketTitle,
        longVoucherTitle,
        longHabitTitle,
        longNoteTitle,
      ]) {
        final rect = tester.getRect(find.text(longTitle));
        // At 2.0x text (~30-36dp per line), wrapped multi-line titles exceed 60dp height.
        expect(
          rect.height,
          greaterThan(60.0),
          reason: 'Expected "$longTitle" to wrap across multiple lines',
        );
      }
    });
  });
}
