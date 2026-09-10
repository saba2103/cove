import 'package:flutter/material.dart';

@immutable
class CoveColors extends ThemeExtension<CoveColors> {
  final Color background;
  final Color surfaceCard;
  final Color surfaceRow;
  final Color accentPrimary;
  final Color accentTint; // Used for big Bodoni Moda totals
  final Color accentSecondary; // Muted terracotta for attention-needed moments
  final Color textPrimary;
  final Color textMuted; // ~55% opacity
  final Color textSubtle; // ~40% opacity
  final Color borderHairline; // ~6% opacity

  const CoveColors({
    required this.background,
    required this.surfaceCard,
    required this.surfaceRow,
    required this.accentPrimary,
    required this.accentTint,
    required this.accentSecondary,
    required this.textPrimary,
    required this.textMuted,
    required this.textSubtle,
    required this.borderHairline,
  });

  static const dark = CoveColors(
    background: Color(0xFF0B1F1E),
    surfaceCard: Color(0xFF12302E),
    surfaceRow: Color(0xFF0F2624),
    accentPrimary: Color(0xFFD8B98C),
    accentTint: Color(0xFFEAD3AC),
    accentSecondary: Color(0xFFC46D5E),
    textPrimary: Color(0xFFF3ECE2),
    textMuted: Color(0x8CF3ECE2), // 55% of #F3ECE2
    textSubtle: Color(0x66F3ECE2), // 40% of #F3ECE2
    borderHairline: Color(0x0FF3ECE2), // 6% of #F3ECE2
  );

  static const light = CoveColors(
    background: Color(0xFFF4EDE3),
    surfaceCard: Color(0xFFFFFCF8),
    surfaceRow: Color(0xFFF8F3EC),
    accentPrimary: Color(0xFFA97C4F),
    accentTint: Color(0xFFA97C4F),
    accentSecondary: Color(0xFFB85B4C),
    textPrimary: Color(0xFF1C2E2C),
    textMuted: Color(0x8C1C2E2C), // 55% of #1C2E2C
    textSubtle: Color(0x661C2E2C), // 40% of #1C2E2C
    borderHairline: Color(0x0F1C2E2C), // 6% of #1C2E2C
  );

  @override
  CoveColors copyWith({
    Color? background,
    Color? surfaceCard,
    Color? surfaceRow,
    Color? accentPrimary,
    Color? accentTint,
    Color? accentSecondary,
    Color? textPrimary,
    Color? textMuted,
    Color? textSubtle,
    Color? borderHairline,
  }) {
    return CoveColors(
      background: background ?? this.background,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceRow: surfaceRow ?? this.surfaceRow,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentTint: accentTint ?? this.accentTint,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      borderHairline: borderHairline ?? this.borderHairline,
    );
  }

  @override
  CoveColors lerp(ThemeExtension<CoveColors>? other, double t) {
    if (other is! CoveColors) return this;
    return CoveColors(
      background: Color.lerp(background, other.background, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceRow: Color.lerp(surfaceRow, other.surfaceRow, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
      borderHairline: Color.lerp(borderHairline, other.borderHairline, t)!,
    );
  }

  static CoveColors of(BuildContext context) {
    return Theme.of(context).extension<CoveColors>() ?? dark;
  }
}
