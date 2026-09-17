import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/cove_theme.dart';
import '../../../sync/db/app_database.dart';
import '../calendar_models.dart';

class CalendarYearView extends StatelessWidget {
  final List<LocalCalendarEvent> events;
  final List<LocalSubscription> subscriptions;
  final int year;
  final ValueChanged<DateTime> onMonthSelected;
  final ValueChanged<int>? onYearChanged;

  const CalendarYearView({
    super.key,
    required this.events,
    required this.subscriptions,
    required this.year,
    required this.onMonthSelected,
    this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final now = DateTime.now();

    // 1. Project subscriptions across the entire year
    final yearStart = DateTime(year, 1, 1);
    final yearEnd = DateTime(year, 12, 31);
    final projectedSubs = CalendarDateUtils.projectSubscriptions(
      subscriptions: subscriptions,
      startDate: yearStart,
      endDate: yearEnd,
    );

    // 2. Map all entries by month
    final Map<int, List<CalendarEntry>> entriesByMonth = {};
    for (final e in events) {
      if (e.startTime.year == year) {
        entriesByMonth.putIfAbsent(e.startTime.month, () => []).add(CalendarEventEntry(e));
      }
    }
    for (final s in projectedSubs) {
      if (s.date.year == year) {
        entriesByMonth.putIfAbsent(s.date.month, () => []).add(s);
      }
    }

    return Column(
      children: [
        // Year Navigation Header with arrows (matching Month & Week tabs)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$year',
                style: typography.headline.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 22),
                    onPressed: onYearChanged != null
                        ? () => onYearChanged!(year - 1)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 22),
                    onPressed: onYearChanged != null
                        ? () => onYearChanged!(year + 1)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.82,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: 12,
      itemBuilder: (ctx, idx) {
        final month = idx + 1;
        final monthDate = DateTime(year, month, 1);
        final monthName = DateFormat('MMM').format(monthDate);
        final isCurrentMonth = now.year == year && now.month == month;
        final items = entriesByMonth[month] ?? [];

        return GestureDetector(
          onTap: () => onMonthSelected(monthDate),
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrentMonth
                    ? colors.accentPrimary
                    : colors.borderHairline,
                width: isCurrentMonth ? 1.5 : 1.0,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month Name
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      monthName,
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isCurrentMonth
                            ? colors.accentPrimary
                            : colors.textPrimary,
                      ),
                    ),
                    if (isCurrentMonth)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.accentPrimary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Item count caption
                Text(
                  items.isEmpty
                      ? 'Nothing yet'
                      : '${items.length} upcoming',
                  style: typography.caption.copyWith(
                    fontSize: 11,
                    color: items.isEmpty
                        ? colors.textSubtle.withValues(alpha: 0.6)
                        : colors.accentPrimary,
                    fontWeight: items.isEmpty ? FontWeight.w400 : FontWeight.w500,
                  ),
                ),

                const Spacer(),

                // Mini density indicator dots
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: List.generate(
                    items.length.clamp(0, 12),
                    (i) => Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.accentPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
        );
      },
    ),
  ),
],
);
}
}
