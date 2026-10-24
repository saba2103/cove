import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Guard: DateTime.now( does not appear in lib/features/ or lib/core/widgets/', () {
    const guardedDirs = ['lib/features', 'lib/core/widgets'];
    final violations = <String>[];

    for (final dirPath in guardedDirs) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      for (final file in files) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('DateTime.now(')) {
            violations.add('${file.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Use clock.now() from package:clock instead of DateTime.now( in '
          'lib/features/ and lib/core/widgets/.\nFound:\n${violations.join('\n')}',
    );
  });
}
