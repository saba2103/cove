import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_grouped_list.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typography = context.typography;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        // Balance Summary Card
        CoveCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CURRENT BALANCE', style: typography.caption),
              const SizedBox(height: 8),
              Text('\$34.20', style: typography.largeNumber.copyWith(fontSize: 34)),
              const SizedBox(height: 4),
              Text('Alex is owed \$34.20 by Sarah', style: typography.caption),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text('RECENT PURCHASES', style: typography.caption),
        const SizedBox(height: 8),
        CoveGroupedCard(
          children: [
            CoveGroupedRow(
              title: Text('Farmers Market', style: typography.bodyMedium),
              subtitle: Text('Paid by Sarah • Yesterday', style: typography.caption),
              trailing: Text('\$42.50', style: typography.bodyMedium),
            ),
            CoveGroupedRow(
              title: Text('Home Depot Hardware', style: typography.bodyMedium),
              subtitle: Text('Paid by Alex • Sep 7', style: typography.caption),
              trailing: Text('\$86.10', style: typography.bodyMedium),
            ),
            CoveGroupedRow(
              title: Text('Whole Foods Market', style: typography.bodyMedium),
              subtitle: Text('Paid by Alex • Sep 5', style: typography.caption),
              trailing: Text('\$65.80', style: typography.bodyMedium),
            ),
          ],
        ),
      ],
    );
  }
}
