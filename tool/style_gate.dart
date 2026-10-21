// Fails if a widget file still hard-codes a value that belongs in design/tokens.json.
// Run from the repo root:  dart run tool/style_gate.dart
//
// Files listed in tool/style_allowlist.txt are exempt WITH A BUDGET: the number is
// how many raw literals that file is still allowed. Converting a screen means
// deleting its line. The budget may only ever go DOWN — the gate fails if a file
// comes in under its budget without the budget being updated, so the ratchet holds.
import 'dart:io';

final _patterns = <String, RegExp>{
  'colour':  RegExp(r'Color\(0x[0-9A-Fa-f]{6,8}\)'),
  'font':    RegExp(r'fontSize:\s*[0-9.]+'),
  'radius':  RegExp(r'BorderRadius\.circular\(\s*[0-9.]+\s*\)'),
};
const _roots = ['lib/features', 'lib/core/widgets'];

void main() {
  final budgets = <String, int>{};
  final f = File('tool/style_allowlist.txt');
  if (f.existsSync()) {
    for (final line in f.readAsLinesSync()) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final parts = t.split(RegExp(r'\s+'));
      budgets[parts[0]] = int.parse(parts[1]);
    }
  }

  final failures = <String>[];
  final under = <String>[];
  var converted = 0, total = 0;

  for (final root in _roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final e in dir.listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart') || e.path.endsWith('.g.dart')) continue;
      final src = e.readAsStringSync();
      var hits = 0;
      final detail = <String>[];
      _patterns.forEach((name, re) {
        final n = re.allMatches(src).length;
        if (n > 0) detail.add('$n $name');
        hits += n;
      });
      total += hits;
      final budget = budgets[e.path];
      if (budget == null) {
        if (hits > 0) {
          failures.add('${e.path}: $hits raw ${detail.join(", ")} — this file is converted, '
              'so every value must come from CoveTokens / CoveType / CoveSpace / CoveRadius.');
        } else {
          converted++;
        }
      } else if (hits > budget) {
        failures.add('${e.path}: $hits raw literals, budget is $budget — the ratchet only turns one way.');
      } else if (hits < budget) {
        under.add('${e.path}: now $hits (budget $budget) — lower the budget, or delete the line if it is 0.');
      }
    }
  }

  stdout.writeln('style gate: $total raw literals left, $converted file(s) fully converted, '
      '${budgets.length} still on the allow-list');
  for (final u in under) {
    stdout.writeln('  tighten: $u');
  }
  if (failures.isNotEmpty) {
    stderr.writeln('\nSTYLE GATE FAILED');
    for (final x in failures) {
      stderr.writeln('  ! $x');
    }
    exit(1);
  }
  if (under.isNotEmpty) {
    stderr.writeln('\nSTYLE GATE FAILED — budgets are stale (see "tighten" above).');
    exit(1);
  }
}
