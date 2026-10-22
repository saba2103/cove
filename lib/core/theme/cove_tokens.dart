// GENERATED FILE — do not edit by hand.
// Source: design/tokens.json   Regenerate: dart run tool/gen_tokens.dart

import 'package:flutter/material.dart';

/// Mode-independent. Authored at device scale in design/tokens.json.
abstract final class CoveSpace {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  /// Horizontal padding of every scroll container. Inner elements add none.
  static const double gutter = 20.0;
  static const double lg = 24.0;
  static const double section = 32.0;
  static const double xl = 48.0;
  /// Bottom padding on any page wearing the floating bar.
  static const double barClearance = 112.0;
  /// A row's horizontal padding; it bleeds out with an equal negative margin.
  static const double hitPlate = 12.0;
}

/// Mode-independent. Authored at device scale in design/tokens.json.
abstract final class CoveSize {
  /// Row HEIGHT is the token. Vertical padding is derived: (row - content) / 2.
  static const double row = 52.0;
  /// The drawn circle. Every header action, back and add alike.
  static const double buttonRound = 40.0;
  /// Tappable area around the drawn button. Never smaller.
  static const double hit = 48.0;
  static const double avatarInline = 24.0;
  static const double avatarRow = 28.0;
  static const double avatarHeader = 32.0;
  static const double avatarProfile = 64.0;
  /// Page content never exceeds this; centred on anything wider - the Fold's inner screen, tablets, web.
  static const double maxContent = 420.0;
}

/// Mode-independent. Authored at device scale in design/tokens.json.
abstract final class CoveRadius {
  static const double inline = 16.0;
  static const double card = 20.0;
  static const double hero = 28.0;
  /// Top corners of every bottom sheet.
  static const double sheet = 32.0;
  /// Bottom corners of a sheet reaching the screen edge. A stand-in for the hardware corner - read it from the OS where you can.
  static const double device = 40.0;
  static const double pill = 999.0;
}

/// Text styles without colour. Pair with a CoveTokens colour at the use site.
abstract final class CoveType {
  static const TextStyle title = TextStyle(fontFamily: 'LibreBodoni', fontSize: 28.0, fontWeight: FontWeight.w500, height: 1.2857142857142858, letterSpacing: -0.280);
  static const TextStyle heroFigure = TextStyle(fontFamily: 'LibreBodoni', fontSize: 40.0, fontWeight: FontWeight.w400, height: 1.1, letterSpacing: 0.000);
  static const TextStyle cardFigure = TextStyle(fontFamily: 'LibreBodoni', fontSize: 28.0, fontWeight: FontWeight.w400, height: 1.1428571428571428, letterSpacing: 0.000);
  static const TextStyle rowTitle = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15.0, fontWeight: FontWeight.w500, height: 1.3333333333333333, letterSpacing: 0.000);
  static const TextStyle body = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15.0, fontWeight: FontWeight.w400, height: 1.4666666666666666, letterSpacing: 0.000);
  static const TextStyle readout = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14.0, fontWeight: FontWeight.w400, height: 1.2857142857142858, letterSpacing: 0.000);
  static const TextStyle rowSub = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12.0, fontWeight: FontWeight.w400, height: 1.3333333333333333, letterSpacing: 0.000);
  /// Floating bar seat label — mixed-case, zero tracking.
  static const TextStyle barLabel = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11.0, fontWeight: FontWeight.w600, height: 1.2727272727272727, letterSpacing: 0.000);
  /// A section label on the page.
  static const TextStyle capsPage = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12.0, fontWeight: FontWeight.w700, height: 1.3333333333333333, letterSpacing: 1.800);
  /// A label inside a card or object. Nothing in the app is smaller.
  static const TextStyle capsCard = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11.0, fontWeight: FontWeight.w700, height: 1.2727272727272727, letterSpacing: 1.540);
  /// On paper only - the slips keep their own print scale.
  static const TextStyle capsSlip = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11.0, fontWeight: FontWeight.w700, height: 1.2727272727272727, letterSpacing: 1.980);
}

abstract final class CoveMotion {
  static const Duration quick = Duration(milliseconds: 140);
  static const Duration sheet = Duration(milliseconds: 320);
  static const Curve easing = Cubic(0.2, 0.0, 0.0, 1.0);
  /// Collapse every duration to zero when the OS asks for reduced motion.
  static Duration q(BuildContext c) => MediaQuery.disableAnimationsOf(c) ? Duration.zero : quick;
  static Duration s(BuildContext c) => MediaQuery.disableAnimationsOf(c) ? Duration.zero : sheet;
}

@immutable
class CoveTokens extends ThemeExtension<CoveTokens> {
  final Color surfaceCanvas;
  final Color surfaceCard;
  final Color surfaceRow;
  final Color surfaceSheet;
  final Color surfaceScrim;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnAccent;
  final Color textOnPaper;
  final Color lineHairline;
  final Color lineStrong;
  final Color accentFill;
  final Color accentText;
  final Color accentTint;
  final Color accentWash;
  final Color statusAlert;
  final Color statusAlertText;
  final Color statusGood;
  final Color moneyMore;
  final Color moneyLess;
  final Color paperFrom;
  final Color paperVia;
  final Color paperTo;
  final Color paperInk;
  final Color paperInk2;
  final Color paperInk3;
  final Color paperAccent;
  final Color paperRule;
  final Color paperHairline;
  final Color paperEdge;
  final Color categoryTravel;
  final Color categoryGroceries;
  final Color categoryHealth;
  final Color categoryEatingOut;
  final Color categoryHome;
  final Color categoryPets;
  final Color categoryFuel;
  final Color categoryGifts;
  final Gradient personA;
  final Gradient personB;
  /// person.both is UNFILLED — use this as a ring, never as a fill.
  final Gradient personBothRing;
  final Color personALabel;
  final Color personBLabel;
  final Color personBothLabel;
  final List<BoxShadow> elevationPaper;
  final List<BoxShadow> elevationBar;

  const CoveTokens({
    required this.surfaceCanvas,
    required this.surfaceCard,
    required this.surfaceRow,
    required this.surfaceSheet,
    required this.surfaceScrim,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnAccent,
    required this.textOnPaper,
    required this.lineHairline,
    required this.lineStrong,
    required this.accentFill,
    required this.accentText,
    required this.accentTint,
    required this.accentWash,
    required this.statusAlert,
    required this.statusAlertText,
    required this.statusGood,
    required this.moneyMore,
    required this.moneyLess,
    required this.paperFrom,
    required this.paperVia,
    required this.paperTo,
    required this.paperInk,
    required this.paperInk2,
    required this.paperInk3,
    required this.paperAccent,
    required this.paperRule,
    required this.paperHairline,
    required this.paperEdge,
    required this.categoryTravel,
    required this.categoryGroceries,
    required this.categoryHealth,
    required this.categoryEatingOut,
    required this.categoryHome,
    required this.categoryPets,
    required this.categoryFuel,
    required this.categoryGifts,
    required this.personA,
    required this.personB,
    required this.personBothRing,
    required this.personALabel,
    required this.personBLabel,
    required this.personBothLabel,
    required this.elevationPaper,
    required this.elevationBar,
  });

  static const dark = CoveTokens(
    surfaceCanvas: Color(0xFF0B1F1E),
    surfaceCard: Color(0xFF12302E),
    surfaceRow: Color(0xFF0F2624),
    surfaceSheet: Color(0xFF12302E),
    surfaceScrim: Color(0xA6000000),
    textPrimary: Color(0xFFF3ECE2),
    textSecondary: Color(0xFFB4B7B0),
    textTertiary: Color(0xFF909993),
    textOnAccent: Color(0xFF0B1F1E),
    textOnPaper: Color(0xFF1E332F),
    lineHairline: Color(0x12F3ECE2),
    lineStrong: Color(0x24F3ECE2),
    accentFill: Color(0xFFD8B98C),
    accentText: Color(0xFFD8B98C),
    accentTint: Color(0xFFEAD3AC),
    accentWash: Color(0x1FD8B98C),
    statusAlert: Color(0xFFC46D5E),
    statusAlertText: Color(0xFFD4806F),
    statusGood: Color(0xFF8CBE9D),
    moneyMore: Color(0xFFD99B86),
    moneyLess: Color(0xFF8CBE9D),
    paperFrom: Color(0xFFEDE3D0),
    paperVia: Color(0xFFE4D8C2),
    paperTo: Color(0xFFDED1B8),
    paperInk: Color(0xFF1E332F),
    paperInk2: Color(0xFF44534A),
    paperInk3: Color(0xFF505C53),
    paperAccent: Color(0xFF76532D),
    paperRule: Color(0x331E332F),
    paperHairline: Color(0x1C1E332F),
    paperEdge: Color(0x00000000),
    categoryTravel: Color(0xFFE0C98A),
    categoryGroceries: Color(0xFFD8B98C),
    categoryHealth: Color(0xFFC46D5E),
    categoryEatingOut: Color(0xFFC9A0C4),
    categoryHome: Color(0xFFA8C49B),
    categoryPets: Color(0xFF8FC9B6),
    categoryFuel: Color(0xFF8FB3C9),
    categoryGifts: Color(0xFFB9A3D8),
    personA: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFFD2B38E), Color(0xFFA47C51)]),
    personB: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF587166), Color(0xFF2C3C37)]),
    personBothRing: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFFD2B38E), Color(0xFF587166)]),
    personALabel: Color(0xFF0B1F1E),
    personBLabel: Color(0xFFF3ECE2),
    personBothLabel: Color(0xFFF3ECE2),
    elevationPaper: [BoxShadow(offset: Offset(0, 18.0), blurRadius: 40.0, color: Color(0x4D000000)), BoxShadow(offset: Offset(0, 3.0), blurRadius: 7.0, color: Color(0x2E000000))],
    elevationBar: [BoxShadow(offset: Offset(0, 8.0), blurRadius: 32.0, color: Color(0x66000000))],
  );

  static const light = CoveTokens(
    surfaceCanvas: Color(0xFFF4EDE3),
    surfaceCard: Color(0xFFFFFCF8),
    surfaceRow: Color(0xFFF8F3EC),
    surfaceSheet: Color(0xFFFFFCF8),
    surfaceScrim: Color(0x7A1E332F),
    textPrimary: Color(0xFF1E332F),
    textSecondary: Color(0xFF4B5B57),
    textTertiary: Color(0xFF5D6B67),
    textOnAccent: Color(0xFF0B1F1E),
    textOnPaper: Color(0xFF1E332F),
    lineHairline: Color(0x141E332F),
    lineStrong: Color(0x291E332F),
    accentFill: Color(0xFFA97C4F),
    accentText: Color(0xFF76532D),
    accentTint: Color(0xFFA97C4F),
    accentWash: Color(0x1FA97C4F),
    statusAlert: Color(0xFFB4523F),
    statusAlertText: Color(0xFFA8483A),
    statusGood: Color(0xFF3E7753),
    moneyMore: Color(0xFF985A47),
    moneyLess: Color(0xFF3E7753),
    paperFrom: Color(0xFFEDE3D0),
    paperVia: Color(0xFFE4D8C2),
    paperTo: Color(0xFFDED1B8),
    paperInk: Color(0xFF1E332F),
    paperInk2: Color(0xFF44534A),
    paperInk3: Color(0xFF505C53),
    paperAccent: Color(0xFF76532D),
    paperRule: Color(0x331E332F),
    paperHairline: Color(0x1C1E332F),
    paperEdge: Color(0x331E332F),
    categoryTravel: Color(0xFF8A6F2E),
    categoryGroceries: Color(0xFF7E5A2C),
    categoryHealth: Color(0xFF9C4335),
    categoryEatingOut: Color(0xFF7D4F78),
    categoryHome: Color(0xFF4F7042),
    categoryPets: Color(0xFF2F6D5B),
    categoryFuel: Color(0xFF3A6079),
    categoryGifts: Color(0xFF5C4788),
    personA: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFFD2B38E), Color(0xFFA47C51)]),
    personB: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF587166), Color(0xFF2C3C37)]),
    personBothRing: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFFD2B38E), Color(0xFF587166)]),
    personALabel: Color(0xFF0B1F1E),
    personBLabel: Color(0xFFF3ECE2),
    personBothLabel: Color(0xFF1E332F),
    elevationPaper: [BoxShadow(offset: Offset(0, 18.0), blurRadius: 40.0, color: Color(0x4D000000)), BoxShadow(offset: Offset(0, 3.0), blurRadius: 7.0, color: Color(0x2E000000))],
    elevationBar: [BoxShadow(offset: Offset(0, 8.0), blurRadius: 32.0, color: Color(0x66000000))],
  );

  @override
  CoveTokens copyWith() => this;
  @override
  CoveTokens lerp(ThemeExtension<CoveTokens>? other, double t) => t < .5 ? this : (other as CoveTokens? ?? this);
}

extension CoveTokensX on BuildContext {
  CoveTokens get cv => Theme.of(this).extension<CoveTokens>()!;
}
