import 'package:clock/clock.dart';
import 'package:cove/core/widgets/cove_activity_row.dart';
import 'package:cove/core/widgets/cove_checkbox.dart';
import 'package:cove/core/widgets/cove_empty_state.dart';
import 'package:cove/core/widgets/cove_error_state.dart';
import 'package:cove/core/widgets/cove_loading.dart';
import 'package:cove/core/widgets/cove_pill_button.dart';
import 'package:cove/core/widgets/cove_pill_input.dart';
import 'package:cove/core/widgets/cove_splash_screen.dart';
import 'package:cove/core/widgets/cove_streak_badge.dart';
import 'package:cove/core/widgets/cove_sync_tick.dart';
import 'package:cove/core/widgets/cove_tab_row.dart';
import 'package:cove/core/widgets/cove_toggle_switch.dart';
import 'package:cove/core/widgets/cove_undo_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

Widget _scaffoldWrap(Widget child) => Builder(
      builder: (context) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ),
      ),
    );

class _UndoToastTriggerShowcase extends StatefulWidget {
  const _UndoToastTriggerShowcase();

  @override
  State<_UndoToastTriggerShowcase> createState() =>
      _UndoToastTriggerShowcaseState();
}

class _UndoToastTriggerShowcaseState extends State<_UndoToastTriggerShowcase> {
  Brightness? _lastBrightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_lastBrightness != brightness) {
      _lastBrightness = brightness;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        CoveUndoToast.show(
          context,
          message: 'Deleted Farmers Market Produce',
          onUndo: () {},
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      key: ValueKey('undo_toast_scaffold_$brightness'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const SizedBox.expand(),
    );
  }
}

Future<void> _splashGoldenMatrix(WidgetTester tester) async {
  await loadCoveFonts();
  const widths = <Size>[CoveWidth.phone, CoveWidth.cover, CoveWidth.wide];
  const modes = <Brightness>[Brightness.dark, Brightness.light];

  await withClock(kDefaultGoldenClock, () async {
    for (final size in widths) {
      final w = size == CoveWidth.cover
          ? 'cover'
          : size == CoveWidth.wide
              ? 'wide'
              : 'phone';
      for (final mode in modes) {
        tester.view
          ..physicalSize = size * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            child: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.0),
              ),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: coveThemeFor(mode),
                home: const CoveSplashScreen(
                  showProgress: true,
                ),
              ),
            ),
          ),
        );
        // Pump to 1100ms so all entrance intervals (0.0..0.85 of 1200ms) have
        // reached 1.0 before the repeating breathing controller starts.
        await tester.pump(const Duration(milliseconds: 1100));

        final m = mode == Brightness.dark ? 'dark' : 'light';
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/core_41a_splash_screen.$w.$m.png'),
        );

        // Unmount before next iteration so AnimationControllers dispose cleanly.
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}

const Set<String> _kKnownLegacyOverflows = {};

void main() {
  testWidgets('4.1a before/after golden: cove_checkbox & CoveChecklistRow',
      (tester) async {
    await goldenMatrix(
      tester,
      'core_41a_checkbox',
      _scaffoldWrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoveChecklistRow(
              value: false,
              onChanged: (_) {},
              title: 'Sourdough country loaf',
              subtitle: 'Added by Sarah',
            ),
            CoveChecklistRow(
              value: true,
              onChanged: (_) {},
              title: 'Organic whole milk',
              subtitle: 'Completed today',
            ),
          ],
        ),
      ),
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1a before/after golden: cove_tab_row', (tester) async {
    await goldenMatrix(
      tester,
      'core_41a_tab_row',
      _scaffoldWrap(
        CoveTabRow(
          tabs: const ['Groceries', 'Weekend Hardware', 'Pharmacy'],
          selectedIndex: 0,
          onTabSelected: (_) {},
        ),
      ),
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1a before/after golden: cove_pill_button', (tester) async {
    await goldenMatrix(
      tester,
      'core_41a_pill_button',
      _scaffoldWrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CovePillButton(
              label: 'Save commitment',
              icon: const Icon(Icons.check_rounded),
              variant: CoveButtonVariant.primary,
              isFullWidth: true,
              onPressed: () {},
            ),
            const SizedBox(height: 12),
            CovePillButton(
              label: 'Check connection',
              variant: CoveButtonVariant.secondary,
              isCompact: true,
              onPressed: () {},
            ),
            const SizedBox(height: 12),
            CovePillButton(
              label: 'Cancel',
              variant: CoveButtonVariant.ghost,
              isCompact: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1a before/after golden: cove_undo_toast', (tester) async {
    await goldenMatrix(
      tester,
      'core_41a_undo_toast',
      const _UndoToastTriggerShowcase(),
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1a before/after golden: cove_toggle_switch', (tester) async {
    await goldenMatrix(
      tester,
      'core_41a_toggle_switch',
      _scaffoldWrap(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CoveToggleSwitch(value: true, onChanged: (_) {}),
            const SizedBox(width: 24),
            CoveToggleSwitch(value: false, onChanged: (_) {}),
          ],
        ),
      ),
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1a before/after golden: cove_pill_input', (tester) async {
    final populated = TextEditingController(text: 'Coffee beans — dark roast');
    addTearDown(populated.dispose);

    await goldenMatrix(
      tester,
      'core_41a_pill_input',
      _scaffoldWrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CovePillInput(
              hintText: 'Add an item to Groceries…',
              prefixIcon: Icon(Icons.add_rounded, size: 18),
            ),
            const SizedBox(height: 12),
            CovePillInput(
              controller: populated,
              hintText: 'Expense title',
            ),
          ],
        ),
      ),
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1a before/after golden: cove_activity_row', (tester) async {
    await goldenMatrix(
      tester,
      'core_41a_activity_row',
      _scaffoldWrap(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoveActivityRow(
              authorName: 'Sarah',
              actionText: 'logged ₹1,450.50 for Farmers Market Produce',
              timestamp: '10:30 AM',
              syncStatus: CoveSyncStatus.syncedToPartner,
            ),
            CoveActivityRow(
              authorName: 'Alex',
              actionText: 'checked off Sourdough country loaf',
              timestamp: '9:15 AM',
              syncStatus: CoveSyncStatus.savedLocally,
            ),
          ],
        ),
      ),
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1a before/after golden: cove_streak_badge', (tester) async {
    await goldenMatrix(
      tester,
      'core_41a_streak_badge',
      _scaffoldWrap(
        const Center(
          child: CoveStreakIndicator(count: 14, label: 'days'),
        ),
      ),
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1a before/after golden: cove_splash_screen', (tester) async {
    await _splashGoldenMatrix(tester);
  });

  testWidgets('4.1a before/after golden: cove_error_state', (tester) async {
    await goldenMatrix(
      tester,
      'core_41a_error_state',
      _scaffoldWrap(
        CoveErrorState.syncPending(onRetry: () {}),
      ),
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1a before/after golden: cove_empty_state', (tester) async {
    await goldenMatrix(
      tester,
      'core_41a_empty_state',
      _scaffoldWrap(
        CoveEmptyState(
          icon: Icons.format_list_bulleted_outlined,
          title: 'Nothing on this list yet',
          description: 'Add items above and they will sync with Sarah.',
          action: CovePillButton(
            label: 'Add first item',
            isCompact: true,
            onPressed: () {},
          ),
        ),
      ),
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1a before/after golden: cove_loading', (tester) async {
    await loadCoveFonts();
    const widths = <Size>[CoveWidth.phone, CoveWidth.cover, CoveWidth.wide];
    const modes = <Brightness>[Brightness.dark, Brightness.light];

    await withClock(kDefaultGoldenClock, () async {
      for (final size in widths) {
        final w = size == CoveWidth.cover
            ? 'cover'
            : size == CoveWidth.wide
                ? 'wide'
                : 'phone';
        for (final mode in modes) {
          tester.view
            ..physicalSize = size * 2
            ..devicePixelRatio = 2.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            ProviderScope(
              child: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(1.0),
                ),
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: coveThemeFor(mode),
                  home: _scaffoldWrap(
                    const CoveLoading(message: 'Loading your household…'),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 250));

          final m = mode == Brightness.dark ? 'dark' : 'light';
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/core_41a_loading.$w.$m.png'),
          );
        }
      }
    });
  });
}
