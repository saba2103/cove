// pubspec.yaml, kCoveCurrentAppVersion and the About screen must never drift.
// §4 of product/versioning_and_git_strategy.md, enforced instead of remembered.
import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final m = RegExp(r'^version:\s*(\S+)$', multiLine: true).firstMatch(pubspec);
  if (m == null) { stderr.writeln('! no version: in pubspec.yaml'); exit(1); }
  final full = m.group(1)!;                  // e.g. 2.0.0-alpha.1+1
  final semver = full.split('+').first;      // e.g. 2.0.0-alpha.1

  final models = File('lib/features/changelog/changelog_models.dart').readAsStringSync();
  final k = RegExp(r"kCoveCurrentAppVersion\s*=\s*'([^']+)'").firstMatch(models);
  if (k == null) { stderr.writeln('! no kCoveCurrentAppVersion'); exit(1); }

  if (k.group(1) != semver) {
    stderr.writeln('! pubspec says $semver, kCoveCurrentAppVersion says ${k.group(1)}');
    exit(1);
  }
  stdout.writeln('version: $full (display v${semver.replaceFirst(".0-", "-")})');
}
