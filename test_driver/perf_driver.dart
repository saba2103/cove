import 'dart:convert' show jsonEncode;
import 'dart:io' show File;

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver.dart';

Map<String, double> _computeSummaryPercentiles(Map<String, dynamic> summaryJson) {
  List<double> toSortedMs(String key) {
    final raw = summaryJson[key] as List<dynamic>? ?? const <dynamic>[];
    final ms = raw.whereType<num>().map((us) => us / 1000.0).toList()..sort();
    return ms;
  }

  double pct(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0.0;
    final idx = ((sorted.length - 1) * p).round().clamp(0, sorted.length - 1);
    return double.parse(sorted[idx].toStringAsFixed(2));
  }

  final builds = toSortedMs('frame_build_times');
  final rasters = toSortedMs('frame_rasterizer_times');

  return {
    'timeline_build_p50_ms': pct(builds, 0.50),
    'timeline_build_p90_ms': pct(builds, 0.90),
    'timeline_build_worst_ms': builds.isEmpty
        ? 0.0
        : double.parse(builds.last.toStringAsFixed(2)),
    'timeline_raster_p50_ms': pct(rasters, 0.50),
    'timeline_raster_p90_ms': pct(rasters, 0.90),
    'timeline_raster_worst_ms': rasters.isEmpty
        ? 0.0
        : double.parse(rasters.last.toStringAsFixed(2)),
  };
}

Future<void> main() => integrationDriver(
      responseDataCallback: (data) async {
        if (data != null) {
          for (final entry in data.entries) {
            final value = entry.value;
            if (value is Map<String, dynamic> &&
                value.containsKey('traceEvents')) {
              final timeline = Timeline.fromJson(value);
              final summary = TimelineSummary.summarize(timeline);
              await summary.writeTimelineToFile(
                entry.key,
                destinationDirectory: 'build',
                pretty: true,
              );
              final customPct = _computeSummaryPercentiles(summary.summaryJson);
              // ignore: avoid_print
              print(
                'TIMELINE_SUMMARY_${entry.key}:${jsonEncode({...summary.summaryJson, ...customPct})}',
              );
            } else {
              final out = File('build/${entry.key}.json');
              await out.writeAsString(jsonEncode(value));
              // ignore: avoid_print
              print('REPORT_DATA_${entry.key}:${jsonEncode(value)}');
            }
          }
        }
      },
    );
