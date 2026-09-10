import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_empty_state.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/cove_sync_providers.dart';
import 'subscription_form_sheet.dart';

class SubscriptionsScreen extends ConsumerStatefulWidget {
  final List<LocalSubscription>? initialSubscriptions;

  const SubscriptionsScreen({super.key, this.initialSubscriptions});

  @override
  ConsumerState<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  bool _showAnnual = false;
  bool _includePrivateInHero = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final outboxEvents = ref.watch(activeHomeOutboxProvider).value ?? [];

    if (widget.initialSubscriptions != null) {
      return _buildContent(context, widget.initialSubscriptions!, outboxEvents);
    }

    final subscriptionsAsync = ref.watch(activeHomeSubscriptionsProvider);
    return subscriptionsAsync.when(
      data: (subscriptions) => _buildContent(context, subscriptions, outboxEvents),
      loading: () => Scaffold(
        backgroundColor: colors.background,
        body: const Center(
          child: CoveLoading(),
        ),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: colors.background,
        body: Center(child: Text('Failed to load subscriptions: $e')),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<LocalSubscription> subscriptions,
    List<LocalOutboxEvent> outboxEvents,
  ) {
    final colors = context.colors;
    final typography = context.typography;

    if (subscriptions.isEmpty) {
      return _buildEmptyState(context);
    }

        // 1. Separate Active vs Inactive
        final activeSubs = subscriptions.where((s) => s.isActive).toList();
        final inactiveSubs = subscriptions.where((s) => !s.isActive).toList();

        // 2. Separate Shared vs Private
        final sharedActive = activeSubs.where((s) => !s.isPrivate).toList();
        final privateActive = activeSubs.where((s) => s.isPrivate).toList();

        // 3. Compute Totals
        double sharedMonthlyBurn = 0.0;
        for (final sub in sharedActive) {
          if (sub.billingCycle.toLowerCase() == 'annual') {
            sharedMonthlyBurn += sub.amount / 12.0;
          } else {
            sharedMonthlyBurn += sub.amount;
          }
        }

        double totalMonthlyBurnWithPrivate = sharedMonthlyBurn;
        for (final sub in privateActive) {
          if (sub.billingCycle.toLowerCase() == 'annual') {
            totalMonthlyBurnWithPrivate += sub.amount / 12.0;
          } else {
            totalMonthlyBurnWithPrivate += sub.amount;
          }
        }

        final displayedBurn = _includePrivateInHero
            ? totalMonthlyBurnWithPrivate
            : sharedMonthlyBurn;

        final displayedAmount = _showAnnual
            ? displayedBurn * 12.0
            : displayedBurn;

        // 4. Group by Renewal Date
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final in7Days = today.add(const Duration(days: 7));
        final in30Days = today.add(const Duration(days: 30));

        final renewingSoon7 = <LocalSubscription>[];
        final renewingSoon30 = <LocalSubscription>[];
        final later = <LocalSubscription>[];

        for (final sub in activeSubs) {
          final ren = DateTime(
            sub.nextBillingDate.year,
            sub.nextBillingDate.month,
            sub.nextBillingDate.day,
          );
          if (ren.isBefore(in7Days) || ren.isAtSameMomentAs(in7Days)) {
            renewingSoon7.add(sub);
          } else if (ren.isBefore(in30Days) || ren.isAtSameMomentAs(in30Days)) {
            renewingSoon30.add(sub);
          } else {
            later.add(sub);
          }
        }

        return Scaffold(
          backgroundColor: colors.background,
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              // Hero Editorial Total (Bodoni Moda)
              CoveCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _showAnnual ? 'ANNUAL COMMITMENT' : 'MONTHLY COMMITMENT',
                          style: typography.caption.copyWith(
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // Toggle Monthly / Annual
                        InkWell(
                          onTap: () => setState(() => _showAnnual = !_showAnnual),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.surfaceRow,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: colors.borderHairline, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _showAnnual ? 'Annual' : 'Monthly',
                                  style: typography.caption.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.accentPrimary,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.swap_horiz,
                                  size: 14,
                                  color: colors.accentPrimary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Bodoni Moda Luminous Numerical Total
                    Text(
                      '\$${displayedAmount.toStringAsFixed(2)}',
                      style: typography.largeNumber.copyWith(
                        fontSize: 40,
                        height: 1.1,
                        color: colors.accentTint,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${sharedActive.length} shared commitments${privateActive.isNotEmpty ? " • ${privateActive.length} private" : ""}',
                          style: typography.caption.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                        if (privateActive.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(
                                () => _includePrivateInHero = !_includePrivateInHero),
                            child: Text(
                              _includePrivateInHero
                                  ? 'Show shared only'
                                  : 'Include private',
                              style: typography.caption.copyWith(
                                color: colors.accentPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action button row: Add Subscription
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECURRING SERVICES',
                    style: typography.caption.copyWith(
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CovePillButton(
                    label: 'Add Service',
                    isCompact: true,
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: () => SubscriptionFormSheet.show(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Section: Renewing Soon (Next 7 Days) - Champagne Highlighted
              if (renewingSoon7.isNotEmpty) ...[
                _buildSectionHeader(
                  title: 'Renewing this week',
                  count: renewingSoon7.length,
                  highlight: true,
                ),
                const SizedBox(height: 8),
                CoveGroupedCard(
                  children: renewingSoon7
                      .map((sub) => _buildSubscriptionRow(sub, outboxEvents, isUrgent: true))
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],

              // Section: Renewing in 30 Days
              if (renewingSoon30.isNotEmpty) ...[
                _buildSectionHeader(
                  title: 'Renewing this month',
                  count: renewingSoon30.length,
                  highlight: false,
                ),
                const SizedBox(height: 8),
                CoveGroupedCard(
                  children: renewingSoon30
                      .map((sub) => _buildSubscriptionRow(sub, outboxEvents))
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],

              // Section: Later Renewals
              if (later.isNotEmpty) ...[
                _buildSectionHeader(
                  title: 'Later',
                  count: later.length,
                  highlight: false,
                ),
                const SizedBox(height: 8),
                CoveGroupedCard(
                  children: later
                      .map((sub) => _buildSubscriptionRow(sub, outboxEvents))
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],

              // Section: Inactive / Paused Subscriptions
              if (inactiveSubs.isNotEmpty) ...[
                _buildSectionHeader(
                  title: 'Paused & Cancelled',
                  count: inactiveSubs.length,
                  highlight: false,
                ),
                const SizedBox(height: 8),
                CoveGroupedCard(
                  children: inactiveSubs
                      .map((sub) => _buildSubscriptionRow(sub, outboxEvents, isPaused: true))
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        );
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required bool highlight,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    return Row(
      children: [
        if (highlight) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colors.accentPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: typography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: highlight ? colors.accentPrimary : colors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: typography.caption.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }

  Widget _buildSubscriptionRow(
    LocalSubscription sub,
    List<LocalOutboxEvent> outbox, {
    bool isUrgent = false,
    bool isPaused = false,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    // Determine two-tick delivery status for shared items
    CoveSyncStatus tickStatus = CoveSyncStatus.savedLocally;
    if (!sub.isPrivate) {
      final outboxItem = outbox.firstWhere(
        (o) => o.payloadJson.contains(sub.id),
        orElse: () => LocalOutboxEvent(
          id: '',
          homeId: '',
          actorId: '',
          eventType: '',
          payloadJson: '',
          encryptedPayload: '',
          createdAt: DateTime.now(),
          syncStatus: 'syncedToPartner',
          retryCount: 0,
        ),
      );
      if (outboxItem.syncStatus == 'syncedToPartner') {
        tickStatus = CoveSyncStatus.syncedToPartner;
      }
    }

    final cycleSuffix = sub.billingCycle.toLowerCase() == 'annual' ? '/yr' : '/mo';
    final renewalFormatted = DateFormat('MMM d').format(sub.nextBillingDate);

    return CoveGroupedRow(
      onTap: () => SubscriptionFormSheet.show(context, existing: sub),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colors.surfaceRow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isUrgent
                ? colors.accentPrimary.withValues(alpha: 0.4)
                : colors.borderHairline,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          _getCategoryIcon(sub.category),
          size: 18,
          color: isUrgent ? colors.accentPrimary : colors.textMuted,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              sub.name,
              style: typography.bodyMedium.copyWith(
                color: isPaused ? colors.textMuted : colors.textPrimary,
                decoration: isPaused ? TextDecoration.lineThrough : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (sub.isPrivate) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: colors.surfaceRow,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.borderHairline, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 11,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Private',
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          Text(
            isPaused
                ? 'Paused'
                : 'Renews $renewalFormatted • ${sub.billingCycle == "annual" ? "Annual" : "Monthly"}',
            style: typography.caption.copyWith(
              color: isUrgent ? colors.accentPrimary : colors.textMuted,
              fontWeight: isUrgent ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '\$${sub.amount.toStringAsFixed(2)}$cycleSuffix',
            style: typography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isPaused ? colors.textMuted : colors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          CoveSyncTick(
            status: tickStatus,
            size: 13,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Center(
        child: CoveEmptyState(
          icon: Icons.repeat_outlined,
          title: 'No recurring subscriptions',
          description:
              'Track joint household commitments, renewals, and monthly commitments in one calm space.',
          action: CovePillButton(
            label: 'Add First Subscription',
            icon: const Icon(Icons.add, size: 16),
            onPressed: () => SubscriptionFormSheet.show(context),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'streaming':
        return Icons.play_circle_outline;
      case 'utilities':
        return Icons.bolt_outlined;
      case 'software':
        return Icons.devices_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'health':
        return Icons.favorite_outline;
      case 'news':
        return Icons.newspaper_outlined;
      default:
        return Icons.repeat_outlined;
    }
  }
}
