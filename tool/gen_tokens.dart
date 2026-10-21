// Reads design/tokens.json and writes lib/core/theme/cove_tokens.dart.
// Run from the repo root:  dart run tool/gen_tokens.dart
// The generated file is committed. After running, `git diff` must be empty.
import 'dart:convert';
import 'dart:io';

String hex(String v) {
  var h = v.replaceFirst('#', '');
  if (h.length == 8) {
    h = h.substring(6) + h.substring(0, 6); // RRGGBBAA -> AARRGGBB
  } else if (h.length == 6) {
    h = 'FF$h';
  }
  return 'Color(0x${h.toUpperCase()})';
}

String mode(Map t, String m) {
  final v = t[r'$value'];
  return hex(v is Map ? (v[m] ?? v['dark']) as String : v as String);
}

void main() {
  final j = jsonDecode(File('design/tokens.json').readAsStringSync()) as Map<String, dynamic>;
  final colorGroups = <String, List<String>>{};
  for (final g in ['surface', 'text', 'line', 'accent', 'status', 'money', 'paper', 'category']) {
    colorGroups[g] = (j[g] as Map).keys.cast<String>().toList();
  }

  final b = StringBuffer();
  b.writeln('// GENERATED FILE — do not edit by hand.');
  b.writeln('// Source: design/tokens.json   Regenerate: dart run tool/gen_tokens.dart');
  b.writeln("\nimport 'package:flutter/material.dart';\n");

  // mode-independent scales
  void scale(String cls, String grp) {
    b.writeln('/// Mode-independent. Authored at device scale in design/tokens.json.');
    b.writeln('abstract final class $cls {');
    (j[grp] as Map).forEach((k, v) {
      final raw = v[r'$value'];
      final n = raw is String ? double.parse(raw.replaceAll(RegExp(r'[^0-9.]'), '')) : (raw as num).toDouble();
      final d = v[r'$description'];
      if (d != null) b.writeln('  /// $d');
      b.writeln('  static const double $k = $n;');
    });
    b.writeln('}\n');
  }
  scale('CoveSpace', 'space');
  scale('CoveSize', 'size');
  scale('CoveRadius', 'radius');

  // typography (colourless — the colour is applied at the use site)
  b.writeln('/// Text styles without colour. Pair with a CoveTokens colour at the use site.');
  b.writeln('abstract final class CoveType {');
  (j['type'] as Map).forEach((k, v) {
    if (v[r'$type'] != 'typography') return;
    final s = v[r'$value'] as Map;
    final fam = s['family'] == 'display' ? j['type']['familyDisplay'][r'$value'] : j['type']['familyUi'][r'$value'];
    final d = v[r'$description'];
    if (d != null) b.writeln('  /// $d');
    b.write('  static const TextStyle $k = TextStyle(');
    b.write("fontFamily: '$fam', fontSize: ${(s['size'] as num).toDouble()}, ");
    b.write('fontWeight: FontWeight.w${s['weight']}, ');
    b.write('height: ${(s['lineHeight'] as num) / (s['size'] as num)}, ');
    b.write('letterSpacing: ${((s['letterSpacing'] as num) * (s['size'] as num)).toStringAsFixed(3)}');
    b.writeln(');');
  });
  b.writeln('}\n');

  b.writeln('abstract final class CoveMotion {');
  b.writeln('  static const Duration quick = Duration(milliseconds: ${j['motion']['quick'][r'$value']});');
  b.writeln('  static const Duration sheet = Duration(milliseconds: ${j['motion']['sheet'][r'$value']});');
  b.writeln('  static const Curve easing = Cubic(${(j['motion']['easing'][r'$value'] as List).join(', ')});');
  b.writeln('  /// Collapse every duration to zero when the OS asks for reduced motion.');
  b.writeln('  static Duration q(BuildContext c) => MediaQuery.disableAnimationsOf(c) ? Duration.zero : quick;');
  b.writeln('  static Duration s(BuildContext c) => MediaQuery.disableAnimationsOf(c) ? Duration.zero : sheet;');
  b.writeln('}\n');

  // the colour extension
  final fields = <String>[];
  colorGroups.forEach((g, keys) {
    for (final k in keys) {
      fields.add('$g${k[0].toUpperCase()}${k.substring(1)}');
    }
  });
  b.writeln('@immutable');
  b.writeln('class CoveTokens extends ThemeExtension<CoveTokens> {');
  for (final f in fields) {
    b.writeln('  final Color $f;');
  }
  b.writeln('  final Gradient personA;');
  b.writeln('  final Gradient personB;');
  b.writeln('  /// person.both is UNFILLED — use this as a ring, never as a fill.');
  b.writeln('  final Gradient personBothRing;');
  b.writeln('  final Color personALabel;');
  b.writeln('  final Color personBLabel;');
  b.writeln('  final Color personBothLabel;');
  b.writeln('  final List<BoxShadow> elevationPaper;');
  b.writeln('  final List<BoxShadow> elevationBar;\n');
  b.writeln('  const CoveTokens({');
  for (final f in fields) {
    b.writeln('    required this.$f,');
  }
  for (final f in ['personA','personB','personBothRing','personALabel','personBLabel','personBothLabel','elevationPaper','elevationBar']) {
    b.writeln('    required this.$f,');
  }
  b.writeln('  });\n');

  for (final m in ['dark', 'light']) {
    b.writeln('  static const $m = CoveTokens(');
    colorGroups.forEach((g, keys) {
      for (final k in keys) {
        b.writeln('    $g${k[0].toUpperCase()}${k.substring(1)}: ${mode(j[g][k] as Map, m)},');
      }
    });
    for (final p in ['a', 'b']) {
      final gr = j['person'][p][r'$value'] as Map;
      b.writeln('    person${p.toUpperCase()}: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,');
      b.writeln('      colors: [${hex(gr['from'])}, ${hex(gr['to'])}]),');
    }
    final bo = j['person']['both'][r'$value'] as Map;
    b.writeln('    personBothRing: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,');
    b.writeln('      colors: [${hex(bo['from'])}, ${hex(bo['to'])}]),');
    b.writeln('    personALabel: ${mode(j['person']['aLabel'] as Map, m)},');
    b.writeln('    personBLabel: ${mode(j['person']['bLabel'] as Map, m)},');
    b.writeln('    personBothLabel: ${mode(j['person']['bothLabel'] as Map, m)},');
    for (final e in ['paper', 'bar']) {
      final list = (j['elevation'][e][r'$value'] as List)
          .map((s) => 'BoxShadow(offset: Offset(0, ${(s['y'] as num).toDouble()}), blurRadius: ${(s['blur'] as num).toDouble()}, color: ${hex(s['color'])})')
          .join(', ');
      b.writeln('    elevation${e[0].toUpperCase()}${e.substring(1)}: [$list],');
    }
    b.writeln('  );\n');
  }

  b.writeln('  @override');
  b.writeln('  CoveTokens copyWith() => this;');
  b.writeln('  @override');
  b.writeln('  CoveTokens lerp(ThemeExtension<CoveTokens>? other, double t) => t < .5 ? this : (other as CoveTokens? ?? this);');
  b.writeln('}\n');
  b.writeln('extension CoveTokensX on BuildContext {');
  b.writeln('  CoveTokens get cv => Theme.of(this).extension<CoveTokens>()!;');
  b.writeln('}');

  Directory('lib/core/theme').createSync(recursive: true);
  File('lib/core/theme/cove_tokens.dart').writeAsStringSync(b.toString());
  stdout.writeln('wrote lib/core/theme/cove_tokens.dart (${fields.length} colours x 2 modes)');
}
