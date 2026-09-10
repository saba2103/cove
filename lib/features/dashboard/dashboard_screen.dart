import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_streak_badge.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        // Daily Greeting
        Text(
          'Good morning',
          style: typography.displayLarge.copyWith(fontSize: 30),
        ),
        const SizedBox(height: 4),
        Text(
          'Here is your household overview for today.',
          style: typography.bodyRegular.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 24),

        // Hero Metric Cards: Subscriptions & Habit Streak
        Row(
          children: [
            Expanded(
              child: CoveCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SUBSCRIPTIONS', style: typography.caption),
                    const SizedBox(height: 8),
                    Text('\$184', style: typography.largeNumber.copyWith(fontSize: 32)),
                    const SizedBox(height: 2),
                    Text('/month shared', style: typography.caption),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: CoveCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MORNING WALK', style: typography.caption),
                    const SizedBox(height: 10),
                    const CoveStreakIndicator(count: 14, label: 'days'),
                    const SizedBox(height: 6),
                    Text('Active rhythm', style: typography.caption),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Shared Lists Quick Summary Card
        CoveCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PENDING ERRANDS', style: typography.caption),
                  Text('3 items', style: typography.caption.copyWith(color: colors.accentPrimary)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '• Sourdough bread\n• Oat milk (unsweetened)\n• Fresh rosemary',
                style: typography.bodyMedium.copyWith(height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Upcoming Calendar Preview
        CoveCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('UPCOMING THIS WEEK', style: typography.caption),
              const SizedBox(height: 10),
              Text('Friday, 7:30 PM — Anniversary Dinner', style: typography.bodyMedium),
              const SizedBox(height: 2),
              Text('Trattoria Bella', style: typography.caption),
            ],
          ),
        ),
      ],
    );
  }
}
