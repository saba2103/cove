import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_streak_badge.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Habits & Rhythms', style: typography.headline.copyWith(fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          Text('SHARED RHYTHMS', style: typography.caption),
          const SizedBox(height: 10),
          CoveGroupedCard(
            children: [
              CoveGroupedRow(
                title: Text('Morning Walk', style: typography.bodyMedium),
                subtitle: Text('Daily • Both completed today', style: typography.caption),
                trailing: const CoveStreakIndicator(count: 14, label: 'days'),
              ),
              CoveGroupedRow(
                title: Text('Water Balcony Plants', style: typography.bodyMedium),
                subtitle: Text('3x weekly • Completed by Alex', style: typography.caption),
                trailing: const CoveStreakIndicator(count: 6, label: 'weeks'),
              ),
              CoveGroupedRow(
                title: Text('Evening Reading', style: typography.bodyMedium),
                subtitle: Text('Daily • Not checked yet today', style: typography.caption),
                trailing: const CoveStreakIndicator(count: 9, label: 'days'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
