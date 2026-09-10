import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_grouped_list.dart';

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typography = context.typography;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        // Hero Total Burn Card
        CoveCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MONTHLY COMMITMENT', style: typography.caption),
              const SizedBox(height: 8),
              Text('\$184.50', style: typography.largeNumber.copyWith(fontSize: 36)),
              const SizedBox(height: 4),
              Text('5 active shared recurring services', style: typography.caption),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Active Subscriptions Grouped List
        Text('ACTIVE SERVICES', style: typography.caption),
        const SizedBox(height: 8),
        CoveGroupedCard(
          children: [
            CoveGroupedRow(
              title: Text('Spotify Duo', style: typography.bodyMedium),
              subtitle: Text('Renews Oct 1 • Monthly', style: typography.caption),
              trailing: Text('\$16.99/mo', style: typography.bodyMedium),
            ),
            CoveGroupedRow(
              title: Text('Netflix Standard', style: typography.bodyMedium),
              subtitle: Text('Renews Oct 12 • Monthly', style: typography.caption),
              trailing: Text('\$15.49/mo', style: typography.bodyMedium),
            ),
            CoveGroupedRow(
              title: Text('Google One 2TB', style: typography.bodyMedium),
              subtitle: Text('Renews Nov 20 • Annual', style: typography.caption),
              trailing: Text('\$9.99/mo', style: typography.bodyMedium),
            ),
            CoveGroupedRow(
              title: Text('Fiber Internet', style: typography.bodyMedium),
              subtitle: Text('Renews Oct 5 • Monthly', style: typography.caption),
              trailing: Text('\$70.00/mo', style: typography.bodyMedium),
            ),
          ],
        ),
      ],
    );
  }
}
