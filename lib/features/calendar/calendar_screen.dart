import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_grouped_list.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Shared Calendar', style: typography.headline.copyWith(fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          Text('THIS WEEK', style: typography.caption),
          const SizedBox(height: 10),
          CoveGroupedCard(
            children: [
              CoveGroupedRow(
                title: Text('Friday Dinner Date', style: typography.bodyMedium),
                subtitle: Text('Fri Sep 12 • 7:30 PM • Trattoria Bella', style: typography.caption),
              ),
              CoveGroupedRow(
                title: Text('Farmer\'s Market Run', style: typography.bodyMedium),
                subtitle: Text('Sat Sep 13 • 9:00 AM • Union Square', style: typography.caption),
              ),
              CoveGroupedRow(
                title: Text('Trip to Portland', style: typography.bodyMedium),
                subtitle: Text('Sep 19 – Sep 22 • 4 days', style: typography.caption),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
