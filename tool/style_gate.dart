// Fails if a widget file still hard-codes a value that belongs in design/tokens.json
// or uses raw non-squircle shape primitives outside lib/core/shape/.
// Run from the repo root:  dart run tool/style_gate.dart
//
// Files listed in tool/style_allowlist.txt or tool/shape_allowlist.txt are exempt
// WITH A BUDGET: the number is how many raw literals/shapes that file is still
// allowed. Converting a screen means deleting its line. The budget may only ever
// go DOWN — the gate fails if a file comes in under its budget without the budget
// being updated (or its line deleted), so the ratchet holds.
import 'dart:io';

final _stylePatterns = <String, RegExp>{
  'colour': RegExp(r'Color\(0x[0-9A-Fa-f]{6,8}\)'),
  'font': RegExp(r'fontSize:\s*[0-9.]+'),
  'radius': RegExp(r'BorderRadius\.circular\(\s*[0-9.]+\s*\)'),
};
const _styleRoots = ['lib/features', 'lib/core/widgets'];

final _shapePatterns = <String, RegExp>{
  'BorderRadius.circular': RegExp(r'\bBorderRadius\.circular\b'),
  'BorderRadius.only': RegExp(r'\bBorderRadius\.only\b'),
  'BorderRadius.vertical': RegExp(r'\bBorderRadius\.vertical\b'),
  'BorderRadius.all': RegExp(r'\bBorderRadius\.all\b'),
  'Radius.circular': RegExp(r'\bRadius\.circular\b'),
  'RoundedRectangleBorder': RegExp(r'\bRoundedRectangleBorder\b'),
  'ClipRRect': RegExp(r'\bClipRRect\b'),
  'RRect.from': RegExp(r'\bRRect\.from'),
  'borderRadius:': RegExp(r'\bborderRadius:'),
};
const _shapeRoots = ['lib'];
const _shapeExcludedPrefixes = ['lib/core/shape/'];

Map<String, int> _readAllowlist(String path) {
  final budgets = <String, int>{};
  final f = File(path);
  if (f.existsSync()) {
    for (final line in f.readAsLinesSync()) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final parts = t.split(RegExp(r'\s+'));
      budgets[parts[0]] = int.parse(parts[1]);
    }
  }
  return budgets;
}

bool _runGate({
  required String name,
  required String allowlistPath,
  required List<String> roots,
  required Map<String, RegExp> patterns,
  required String unitLabel,
  required String convertedHint,
  List<String> excludedPrefixes = const [],
}) {
  final budgets = _readAllowlist(allowlistPath);
  final seenFiles = <String>{};
  final failures = <String>[];
  final under = <String>[];
  var converted = 0, total = 0;

  final files = <File>[];
  for (final root in roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final e in dir.listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart') || e.path.endsWith('.g.dart')) {
        continue;
      }
      if (excludedPrefixes.any((p) => e.path.startsWith(p))) continue;
      files.add(e);
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));

  for (final e in files) {
    seenFiles.add(e.path);
    final src = e.readAsStringSync();
    var hits = 0;
    final detail = <String>[];
    patterns.forEach((patternName, re) {
      final n = re.allMatches(src).length;
      if (n > 0) detail.add('$n $patternName');
      hits += n;
    });
    total += hits;
    final budget = budgets[e.path];
    if (budget == null) {
      if (hits > 0) {
        failures.add('${e.path}: $hits raw ${detail.join(", ")} — $convertedHint');
      } else {
        converted++;
      }
    } else if (hits > budget) {
      failures.add(
          '${e.path}: $hits $unitLabel, budget is $budget — the ratchet only turns one way.');
    } else if (hits < budget) {
      under.add(
          '${e.path}: now $hits (budget $budget) — lower the budget, or delete the line if it is 0.');
    }
  }

  for (final entry in budgets.entries) {
    if (!seenFiles.contains(entry.key)) {
      under.add(
          '${entry.key}: file no longer exists (budget ${entry.value}) — delete the line from $allowlistPath.');
    }
  }

  stdout.writeln(
      '$name: $total $unitLabel left, $converted file(s) fully converted, '
      '${budgets.length} still on the allow-list');
  for (final u in under) {
    stdout.writeln('  tighten: $u');
  }
  if (failures.isNotEmpty) {
    stderr.writeln('\n${name.toUpperCase()} FAILED');
    for (final x in failures) {
      stderr.writeln('  ! $x');
    }
    return false;
  }
  if (under.isNotEmpty) {
    stderr.writeln(
        '\n${name.toUpperCase()} FAILED — budgets are stale (see "tighten" above).');
    return false;
  }
  return true;
}

void main() {
  final styleOk = _runGate(
    name: 'style gate',
    allowlistPath: 'tool/style_allowlist.txt',
    roots: _styleRoots,
    patterns: _stylePatterns,
    unitLabel: 'raw literals',
    convertedHint:
        'this file is converted, so every value must come from CoveTokens / CoveType / CoveSpace / CoveRadius.',
  );

  final shapeOk = _runGate(
    name: 'shape gate',
    allowlistPath: 'tool/shape_allowlist.txt',
    roots: _shapeRoots,
    patterns: _shapePatterns,
    unitLabel: 'raw shapes',
    convertedHint:
        'this file is converted, so every rounded shape must come from CoveShape / smoothCornerPath.',
    excludedPrefixes: _shapeExcludedPrefixes,
  );

  if (!styleOk || !shapeOk) {
    exit(1);
  }
}
