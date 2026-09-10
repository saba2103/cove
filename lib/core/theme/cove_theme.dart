import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cove_colors.dart';
import 'cove_typography.dart';

class CoveTheme {
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colors = isDark ? CoveColors.dark : CoveColors.light;
    final typography = CoveTypography.fromColors(colors);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      fontFamily: CoveTypography.generalSansFamily,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.accentPrimary,
        onPrimary: isDark ? const Color(0xFF0B1F1E) : const Color(0xFFFFFFFF),
        secondary: colors.accentSecondary,
        onSecondary: const Color(0xFFFFFFFF),
        error: colors.accentSecondary,
        onError: const Color(0xFFFFFFFF),
        surface: colors.surfaceCard,
        onSurface: colors.textPrimary,
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
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: colors.background,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: colors.background,
              ),
      ),
      extensions: [
        colors,
        typography,
      ],
    );
  }
}

extension CoveContextExtension on BuildContext {
  CoveColors get colors => CoveColors.of(this);
  CoveTypography get typography => CoveTypography.of(this);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
