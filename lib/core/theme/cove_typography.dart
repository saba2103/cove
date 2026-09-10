import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cove_colors.dart';

@immutable
class CoveTypography extends ThemeExtension<CoveTypography> {
  final TextStyle displayLarge;
  final TextStyle headline;
  final TextStyle title;
  final TextStyle bodyMedium;
  final TextStyle bodyRegular;
  final TextStyle caption;
  final TextStyle largeNumber;

  const CoveTypography({
    required this.displayLarge,
    required this.headline,
    required this.title,
    required this.bodyMedium,
    required this.bodyRegular,
    required this.caption,
    required this.largeNumber,
  });

  static const String generalSansFamily = 'GeneralSans';
  static const String bodoniModaFamily = 'BodoniModa';

  factory CoveTypography.fromColors(CoveColors colors) {
    return CoveTypography(
      displayLarge: GoogleFonts.bodoniModa(
        fontSize: 36,
        fontWeight: FontWeight.w500,
        height: 1.15,
        letterSpacing: -0.5,
        color: colors.textPrimary,
        textStyle: const TextStyle(
          fontFamily: bodoniModaFamily,
          fontFamilyFallback: ['BodoniModa', 'serif'],
        ),
      ),
      headline: GoogleFonts.bodoniModa(
        fontSize: 26,
        fontWeight: FontWeight.w500,
        height: 1.20,
        letterSpacing: -0.3,
        color: colors.textPrimary,
        textStyle: const TextStyle(
          fontFamily: bodoniModaFamily,
          fontFamilyFallback: ['BodoniModa', 'serif'],
        ),
      ),
      title: const TextStyle(
        fontFamily: generalSansFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ).copyWith(color: colors.textPrimary),
      bodyMedium: const TextStyle(
        fontFamily: generalSansFamily,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.35,
      ).copyWith(color: colors.textPrimary),
      bodyRegular: const TextStyle(
        fontFamily: generalSansFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.40,
      ).copyWith(color: colors.textPrimary),
      caption: const TextStyle(
        fontFamily: generalSansFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.30,
        letterSpacing: 0.2,
      ).copyWith(color: colors.textMuted),
      largeNumber: GoogleFonts.bodoniModa(
        fontSize: 36,
        fontWeight: FontWeight.w500,
        height: 1.15,
        letterSpacing: -0.5,
        color: colors.accentTint,
        textStyle: const TextStyle(
          fontFamily: bodoniModaFamily,
          fontFamilyFallback: ['BodoniModa', 'serif'],
        ),
      ),
    );
  }

  @override
  CoveTypography copyWith({
    TextStyle? displayLarge,
    TextStyle? headline,
    TextStyle? title,
    TextStyle? bodyMedium,
    TextStyle? bodyRegular,
    TextStyle? caption,
    TextStyle? largeNumber,
  }) {
    return CoveTypography(
      displayLarge: displayLarge ?? this.displayLarge,
      headline: headline ?? this.headline,
      title: title ?? this.title,
      bodyMedium: bodyMedium ?? this.bodyMedium,
      bodyRegular: bodyRegular ?? this.bodyRegular,
      caption: caption ?? this.caption,
      largeNumber: largeNumber ?? this.largeNumber,
    );
  }

  @override
  CoveTypography lerp(ThemeExtension<CoveTypography>? other, double t) {
    if (other is! CoveTypography) return this;
    return CoveTypography(
      displayLarge: TextStyle.lerp(displayLarge, other.displayLarge, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      bodyMedium: TextStyle.lerp(bodyMedium, other.bodyMedium, t)!,
      bodyRegular: TextStyle.lerp(bodyRegular, other.bodyRegular, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      largeNumber: TextStyle.lerp(largeNumber, other.largeNumber, t)!,
    );
  }

  static CoveTypography of(BuildContext context) {
    return Theme.of(context).extension<CoveTypography>() ??
        CoveTypography.fromColors(CoveColors.dark);
  }
}
