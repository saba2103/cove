import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';

/// Size rungs for [CoveAvatar], matching `design/specs/05-avatar.md`.
enum CoveAvatarRung {
  /// `CoveSize.avatarInline` (24dp) — inside a sentence.
  inline(CoveSize.avatarInline),

  /// `CoveSize.avatarRow` (28dp) — a list row.
  row(CoveSize.avatarRow),

  /// `CoveSize.avatarHeader` (32dp) — a header or card head.
  header(CoveSize.avatarHeader),

  /// `CoveSize.avatarProfile` (64dp) — a profile or the home page.
  profile(CoveSize.avatarProfile);

  final double diameter;
  const CoveAvatarRung(this.diameter);
}

/// Household attribution identity for [CoveAvatar].
///
/// Keyed strictly to `home.createdBy`, never to the local viewer:
/// - [a]: the home's creator (`personA` gradient fill, `personALabel` initial)
/// - [b]: the joiner (`personB` gradient fill, `personBLabel` initial)
/// - [both]: shared / joint (`personBothRing` 1.5dp unfilled ring, `&` in `personBothLabel`)
enum CovePerson {
  a,
  b,
  both,
}

/// Who did what, answered by a circle rather than a word.
///
/// Built to the contract in `design/specs/05-avatar.md`:
/// - Four size rungs: [CoveAvatarRung.inline] (24), [CoveAvatarRung.row] (28),
///   [CoveAvatarRung.header] (32), [CoveAvatarRung.profile] (64).
/// - Initial is Libre Bodoni at `0.44 × diameter`, w500.
/// - [CovePerson.a] and [CovePerson.b] use their gradient fills; [CovePerson.both]
///   is an unfilled 1.5dp gradient ring with an ampersand (`&`).
/// - Initials only — no photos, no emoji.
class CoveAvatar extends StatelessWidget {
  final CovePerson person;
  final CoveAvatarRung rung;
  final String? nameOrInitial;
  final String? semanticLabel;

  static const double _kInitialScale = 0.44; // (literal) per 05-avatar.md
  static const double _kBothRingWidth = 1.5; // (literal) 1.5dp ring per 05-avatar.md
  static const double _kTightLineHeight = 1.0; // (literal) optical vertical centring

  const CoveAvatar({
    super.key,
    required this.person,
    this.rung = CoveAvatarRung.row,
    this.nameOrInitial,
    this.semanticLabel,
  });

  /// 24dp inline avatar (`CoveSize.avatarInline`) for use inside a sentence.
  const CoveAvatar.inline({
    super.key,
    required this.person,
    this.nameOrInitial,
    this.semanticLabel,
  }) : rung = CoveAvatarRung.inline;

  /// 28dp row avatar (`CoveSize.avatarRow`) for use in a list row.
  const CoveAvatar.row({
    super.key,
    required this.person,
    this.nameOrInitial,
    this.semanticLabel,
  }) : rung = CoveAvatarRung.row;

  /// 32dp header avatar (`CoveSize.avatarHeader`) for use in a header or card head.
  const CoveAvatar.header({
    super.key,
    required this.person,
    this.nameOrInitial,
    this.semanticLabel,
  }) : rung = CoveAvatarRung.header;

  /// 64dp profile avatar (`CoveSize.avatarProfile`) for use on a profile or home page.
  const CoveAvatar.profile({
    super.key,
    required this.person,
    this.nameOrInitial,
    this.semanticLabel,
  }) : rung = CoveAvatarRung.profile;

  /// Resolves [CovePerson] keyed strictly to [homeCreatedBy], never to the
  /// local viewer, so both phones agree on who is [CovePerson.a] and who is
  /// [CovePerson.b].
  static CovePerson resolvePerson({
    required String homeCreatedBy,
    String? actorUserId,
    bool isShared = false,
  }) {
    if (isShared || actorUserId == null || actorUserId.isEmpty) {
      return CovePerson.both;
    }
    return actorUserId == homeCreatedBy ? CovePerson.a : CovePerson.b;
  }

  String _resolveGlyph() {
    if (person == CovePerson.both) {
      return '&';
    }
    final raw = nameOrInitial?.trim() ?? '';
    if (raw.toLowerCase() != 'you') {
      final match = RegExp(r'[A-Za-z]').firstMatch(raw);
      if (match != null) {
        return match.group(0)!.toUpperCase();
      }
    }
    return person == CovePerson.a ? 'A' : 'B';
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final diameter = rung.diameter;
    final initialFontSize = diameter * _kInitialScale;
    final glyph = _resolveGlyph();

    final Color labelColor = switch (person) {
      CovePerson.a => cv.personALabel,
      CovePerson.b => cv.personBLabel,
      CovePerson.both => cv.personBothLabel,
    };

    final TextStyle initialStyle = CoveType.title.copyWith(
      fontSize: initialFontSize,
      height: _kTightLineHeight,
      letterSpacing: 0.0,
      color: labelColor,
    );

    final Widget textChild = Center(
      child: Text(
        glyph,
        textAlign: TextAlign.center,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        style: initialStyle,
      ),
    );

    final Widget circle = switch (person) {
      CovePerson.a => DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: cv.personA,
          ),
          child: textChild,
        ),
      CovePerson.b => DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: cv.personB,
          ),
          child: textChild,
        ),
      CovePerson.both => CustomPaint(
          painter: _GradientRingPainter(
            gradient: cv.personBothRing,
            strokeWidth: _kBothRingWidth,
          ),
          child: textChild,
        ),
    };

    return Semantics(
      label: semanticLabel ?? glyph,
      child: ExcludeSemantics(
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: circle,
        ),
      ),
    );
  }
}

class _GradientRingPainter extends CustomPainter {
  final Gradient gradient;
  final double strokeWidth;

  const _GradientRingPainter({
    required this.gradient,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = (size.shortestSide - strokeWidth) / 2;
    if (radius <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true
      ..shader = gradient.createShader(rect);

    canvas.drawCircle(rect.center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientRingPainter oldDelegate) {
    return oldDelegate.gradient != gradient ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
