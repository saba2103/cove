import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_error_state.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import 'calendar_event_form_sheet.dart';
import 'views/calendar_agenda_view.dart';
import 'views/calendar_month_view.dart';
import 'views/calendar_year_view.dart';

enum CalendarViewMode {
  week,
  agenda,
  month,
  year,
}

class CalendarScreen extends ConsumerStatefulWidget {
  final List<LocalCalendarEvent>? initialEvents;
  final List<LocalSubscription>? initialSubscriptions;
  final CalendarViewMode initialMode;
  final DateTime? initialSelectedDate;

  const CalendarScreen({
    super.key,
    this.initialEvents,
    this.initialSubscriptions,
    this.initialMode = CalendarViewMode.week,
    this.initialSelectedDate,
  });

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late CalendarViewMode _viewMode;
  late DateTime _selectedDate;

  Future<void> _handleRefresh() async {
    final homeId = ref.read(activeHomeIdProvider);
    await ref.read(syncEngineProvider).pullLatestEvents(homeId: homeId);
  }

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialMode;
    _selectedDate = widget.initialSelectedDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final outboxEvents = ref.watch(activeHomeOutboxProvider).value ?? [];
    final hasPartner = ref.watch(activeHomeHasPartnerProvider);

    if (widget.initialEvents != null) {
      return _buildScaffold(
        context,
        events: widget.initialEvents!,
        subscriptions: widget.initialSubscriptions ?? [],
        outboxEvents: outboxEvents,
        hasPartner: hasPartner,
      );
    }

    final eventsAsync = ref.watch(activeHomeCalendarEventsProvider);
    final subsAsync = ref.watch(activeHomeSubscriptionsProvider);

    if (eventsAsync.isLoading || subsAsync.isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: CoveLoading()),
      );
    }

    if (eventsAsync.hasError || subsAsync.hasError) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: CoveErrorState.generic(
            title: 'Calendar unavailable',
            description: 'Could not load your shared events right now.',
            onRetry: () {
              ref.invalidate(activeHomeCalendarEventsProvider);
              ref.invalidate(activeHomeSubscriptionsProvider);
            },
          ),
        ),
      );
    }

    final events = eventsAsync.value ?? [];
    final subs = subsAsync.value ?? [];

    return _buildScaffold(
      context,
      events: events,
      subscriptions: subs,
      outboxEvents: outboxEvents,
      hasPartner: hasPartner,
    );
  }

  Widget _buildScaffold(
    BuildContext context, {
    required List<LocalCalendarEvent> events,
    required List<LocalSubscription> subscriptions,
    required List<LocalOutboxEvent> outboxEvents,
    bool hasPartner = true,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    final isDesktop = kIsWeb && MediaQuery.sizeOf(context).width >= 840;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Shared Calendar',
          style: typography.headline.copyWith(fontSize: 20),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CovePillButton(
              label: '+ Event',
              variant: CoveButtonVariant.secondary,
              isCompact: true,
              onPressed: () => CalendarEventFormSheet.show(
                context,
                initialDate: _selectedDate,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            alignment: Alignment.center,
            child: _buildSegmentedControl(context),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 1200 : 540),
            child: RefreshIndicator(
              color: colors.accentPrimary,
              backgroundColor: colors.surfaceCard,
              onRefresh: _handleRefresh,
              child: _buildActiveView(
                events: events,
                subscriptions: subscriptions,
                outboxEvents: outboxEvents,
                hasPartner: hasPartner,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedControl(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final modes = [
      (CalendarViewMode.week, 'Week'),
      (CalendarViewMode.month, 'Month'),
      (CalendarViewMode.year, 'Year'),
    ];

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderHairline),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: modes.map((m) {
          final isSelected = _viewMode == m.$1;
          return GestureDetector(
            onTap: () {
              setState(() {
                _viewMode = m.$1;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? colors.accentPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                m.$2,
                style: typography.caption.copyWith(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? colors.background : colors.textSubtle,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveView({
    required List<LocalCalendarEvent> events,
    required List<LocalSubscription> subscriptions,
    required List<LocalOutboxEvent> outboxEvents,
    bool hasPartner = true,
  }) {
    switch (_viewMode) {
      case CalendarViewMode.week:
      case CalendarViewMode.agenda:
        return CalendarAgendaView(
          events: events,
          subscriptions: subscriptions,
          outboxEvents: outboxEvents,
          selectedDate: _selectedDate,
          onSelectDate: (d) => setState(() => _selectedDate = d),
          onAddEvent: () => CalendarEventFormSheet.show(
            context,
            initialDate: _selectedDate,
          ),
          hasPartner: hasPartner,
        );

      case CalendarViewMode.month:
        return CalendarMonthView(
          events: events,
          subscriptions: subscriptions,
          outboxEvents: outboxEvents,
          selectedDate: _selectedDate,
          onSelectDate: (d) => setState(() => _selectedDate = d),
          onAddEvent: () => CalendarEventFormSheet.show(
            context,
            initialDate: _selectedDate,
          ),
          hasPartner: hasPartner,
        );

      case CalendarViewMode.year:
        return CalendarYearView(
          events: events,
          subscriptions: subscriptions,
          year: _selectedDate.year,
          onMonthSelected: (d) {
            setState(() {
              _selectedDate = d;
              _viewMode = CalendarViewMode.month;
            });
          },
          onYearChanged: (newYear) {
            setState(() {
              _selectedDate = DateTime(newYear, _selectedDate.month, _selectedDate.day);
            });
          },
        );
    }
  }
}
