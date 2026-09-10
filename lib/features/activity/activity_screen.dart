import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_activity_row.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_sync_tick.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Activity Log', style: typography.headline.copyWith(fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          Text('RECENT HOUSEHOLD ACTIVITY', style: typography.caption),
          const SizedBox(height: 10),
          CoveGroupedCard(
            children: const [
              CoveActivityRow(
                authorName: 'Sarah',
                actionText: 'checked off Oat milk',
                timestamp: '4m ago',
                syncStatus: CoveSyncStatus.syncedToPartner,
              ),
              CoveActivityRow(
                authorName: 'Alex',
                actionText: 'logged \$42.50 for Farmer\'s Market',
                timestamp: '1h ago',
                syncStatus: CoveSyncStatus.syncedToPartner,
              ),
              CoveActivityRow(
                authorName: 'Alex',
                actionText: 'added "Fresh rosemary & garlic" to Groceries',
                timestamp: '2h ago',
                syncStatus: CoveSyncStatus.syncedToPartner,
              ),
              CoveActivityRow(
                authorName: 'Sarah',
                actionText: 'completed Morning walk',
                timestamp: 'Yesterday',
                syncStatus: CoveSyncStatus.syncedToPartner,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
