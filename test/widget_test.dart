import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/widgets.dart';
import 'package:cove/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CoveApp renders design system showcase', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CoveApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify app title and sections exist
    expect(find.text('Cove'), findsOneWidget);
    expect(find.text('Foundational Design System'), findsOneWidget);
    expect(find.text('Two-Tick Delivery Indicator'), findsOneWidget);
    expect(find.text('One Tick: Saved locally on this device'), findsOneWidget);
    expect(find.text('Two Ticks: Synced to partner\'s device'), findsOneWidget);
  });

  testWidgets('Theme toggle switches mode', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CoveApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Initially in Dark mode
    expect(find.text('Dark'), findsOneWidget);

    // Tap toggle button
    await tester.tap(find.byTooltip('Toggle Theme'));
    await tester.pumpAndSettle();

    // Now in Light mode
    expect(find.text('Light'), findsOneWidget);
  });

  testWidgets('CoveSyncTick renders 1-tick and 2-tick accurately', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoveTheme.darkTheme,
        home: const Scaffold(
          body: Column(
            children: [
              CoveSyncTick(
                status: CoveSyncStatus.savedLocally,
              ),
              CoveSyncTick(
                status: CoveSyncStatus.syncedToPartner,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Saved locally'), findsOneWidget);
    expect(find.bySemanticsLabel('Synced to partner'), findsOneWidget);
  });

  testWidgets('CoveCheckbox and CoveToggleSwitch toggle interactive state',
      (WidgetTester tester) async {
    bool checkVal = false;
    bool toggleVal = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoveTheme.darkTheme,
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Column(
                children: [
                  CoveCheckbox(
                    value: checkVal,
                    onChanged: (v) => setState(() => checkVal = v),
                  ),
                  CoveToggleSwitch(
                    value: toggleVal,
                    onChanged: (v) => setState(() => toggleVal = v),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.check), findsNothing);

    // Tap checkbox
    await tester.tap(find.byType(CoveCheckbox));
    await tester.pumpAndSettle();
    expect(checkVal, isTrue);
    expect(find.byIcon(Icons.check), findsOneWidget);

    // Tap toggle switch
    await tester.tap(find.byType(CoveToggleSwitch));
    await tester.pumpAndSettle();
    expect(toggleVal, isTrue);
  });
}
