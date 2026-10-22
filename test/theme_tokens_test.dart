import 'package:cove/core/theme/cove_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoveTokens ThemeExtension registration', () {
    testWidgets('context.cv resolves in Brightness.dark and matches CoveTokens.dark', (
      tester,
    ) async {
      CoveTokens? resolvedTokens;
      ColorScheme? resolvedScheme;
      TextTheme? resolvedTextTheme;

      await tester.pumpWidget(
        MaterialApp(
          theme: CoveTheme.darkTheme,
          home: Builder(
            builder: (context) {
              resolvedTokens = context.cv;
              resolvedScheme = Theme.of(context).colorScheme;
              resolvedTextTheme = Theme.of(context).textTheme;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolvedTokens, isNotNull);
      expect(resolvedTokens!.surfaceCanvas, equals(CoveTokens.dark.surfaceCanvas));
      expect(resolvedTokens!.textPrimary, equals(CoveTokens.dark.textPrimary));
      expect(resolvedTokens!.accentFill, equals(CoveTokens.dark.accentFill));

      expect(resolvedScheme!.surface, equals(CoveTokens.dark.surfaceCard));
      expect(resolvedScheme!.onSurface, equals(CoveTokens.dark.textPrimary));
      expect(resolvedScheme!.primary, equals(CoveTokens.dark.accentFill));
      expect(resolvedScheme!.onPrimary, equals(CoveTokens.dark.textOnAccent));
      expect(resolvedScheme!.error, equals(CoveTokens.dark.statusAlert));

      expect(resolvedTextTheme!.titleLarge?.fontFamily, equals(CoveType.title.fontFamily));
      expect(resolvedTextTheme!.bodyLarge?.fontFamily, equals(CoveType.body.fontFamily));
      expect(resolvedTextTheme!.bodyMedium?.fontFamily, equals(CoveType.readout.fontFamily));

      final overlay = CoveTheme.darkTheme.appBarTheme.systemOverlayStyle;
      expect(overlay, isNotNull);
      expect(overlay!.statusBarColor, equals(Colors.transparent));
      expect(overlay.statusBarIconBrightness, equals(Brightness.light));
      expect(overlay.statusBarBrightness, equals(Brightness.dark));
    });

    testWidgets('context.cv resolves in Brightness.light and matches CoveTokens.light', (
      tester,
    ) async {
      CoveTokens? resolvedTokens;
      ColorScheme? resolvedScheme;
      TextTheme? resolvedTextTheme;

      await tester.pumpWidget(
        MaterialApp(
          theme: CoveTheme.lightTheme,
          home: Builder(
            builder: (context) {
              resolvedTokens = context.cv;
              resolvedScheme = Theme.of(context).colorScheme;
              resolvedTextTheme = Theme.of(context).textTheme;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolvedTokens, isNotNull);
      expect(resolvedTokens!.surfaceCanvas, equals(CoveTokens.light.surfaceCanvas));
      expect(resolvedTokens!.textPrimary, equals(CoveTokens.light.textPrimary));
      expect(resolvedTokens!.accentFill, equals(CoveTokens.light.accentFill));

      expect(resolvedScheme!.surface, equals(CoveTokens.light.surfaceCard));
      expect(resolvedScheme!.onSurface, equals(CoveTokens.light.textPrimary));
      expect(resolvedScheme!.primary, equals(CoveTokens.light.accentFill));
      expect(resolvedScheme!.onPrimary, equals(CoveTokens.light.textOnAccent));
      expect(resolvedScheme!.error, equals(CoveTokens.light.statusAlert));

      expect(resolvedTextTheme!.titleLarge?.fontFamily, equals(CoveType.title.fontFamily));
      expect(resolvedTextTheme!.bodyLarge?.fontFamily, equals(CoveType.body.fontFamily));
      expect(resolvedTextTheme!.bodyMedium?.fontFamily, equals(CoveType.readout.fontFamily));

      final overlay = CoveTheme.lightTheme.appBarTheme.systemOverlayStyle;
      expect(overlay, isNotNull);
      expect(overlay!.statusBarColor, equals(Colors.transparent));
      expect(overlay.statusBarIconBrightness, equals(Brightness.dark));
      expect(overlay.statusBarBrightness, equals(Brightness.light));
    });
  });
}
