import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cove_colors.dart';
import 'cove_tokens.dart';
import 'cove_typography.dart';

export 'cove_colors.dart';
export 'cove_tokens.dart';
export 'cove_typography.dart';
export '../widgets/cove_page_header.dart' show CovePageInsets;

class CoveTheme {
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  /// Single source of truth for system chrome overlay style.
  /// Light status-bar icons on the dark theme, dark icons on the light theme,
  /// and a transparent status bar so `surfaceCanvas` runs underneath it.
  static SystemUiOverlayStyle overlayStyleFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final tokens = isDark ? CoveTokens.dark : CoveTokens.light;
    final base = isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    return base.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: tokens.surfaceCanvas,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colors = isDark ? CoveColors.dark : CoveColors.light;
    final tokens = isDark ? CoveTokens.dark : CoveTokens.light;
    final typography = CoveTypography.fromColors(colors);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: tokens.surfaceCanvas,
      fontFamily: 'PlusJakartaSans',
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: tokens.accentFill,
        onPrimary: tokens.textOnAccent,
        secondary: tokens.statusAlert,
        onSecondary: tokens.textOnAccent,
        error: tokens.statusAlert,
        onError: tokens.textOnAccent,
        surface: tokens.surfaceCard,
        onSurface: tokens.textPrimary,
      ),
      textTheme: TextTheme(
        displayLarge: CoveType.heroFigure.copyWith(color: tokens.textPrimary),
        displayMedium: CoveType.cardFigure.copyWith(color: tokens.textPrimary),
        displaySmall: CoveType.title.copyWith(color: tokens.textPrimary),
        headlineLarge: CoveType.title.copyWith(color: tokens.textPrimary),
        headlineMedium: CoveType.title.copyWith(color: tokens.textPrimary),
        headlineSmall: CoveType.title.copyWith(color: tokens.textPrimary),
        titleLarge: CoveType.title.copyWith(color: tokens.textPrimary),
        titleMedium: CoveType.rowTitle.copyWith(color: tokens.textPrimary),
        titleSmall: CoveType.readout.copyWith(color: tokens.textSecondary),
        bodyLarge: CoveType.body.copyWith(color: tokens.textPrimary),
        bodyMedium: CoveType.readout.copyWith(color: tokens.textPrimary),
        bodySmall: CoveType.rowSub.copyWith(color: tokens.textSecondary),
        labelLarge: CoveType.rowTitle.copyWith(color: tokens.textPrimary),
        labelMedium: CoveType.capsPage.copyWith(color: tokens.textSecondary),
        labelSmall: CoveType.capsCard.copyWith(color: tokens.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: isDark
              ? BorderSide.none
              : BorderSide(color: colors.borderHairline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: colors.borderHairline,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: colors.textPrimary,
          size: 20,
        ),
        systemOverlayStyle: overlayStyleFor(brightness),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        constraints: const BoxConstraints(maxWidth: 580),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(false),
        trackVisibility: const WidgetStatePropertyAll(false),
        interactive: true,
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll(
          colors.textSubtle.withValues(alpha: 0.3),
        ),
      ),
      extensions: [
        colors,
        typography,
        tokens,
      ],
    );
  }
}

extension CoveContextExtension on BuildContext {
  CoveColors get colors => CoveColors.of(this);
  CoveTypography get typography => CoveTypography.of(this);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
