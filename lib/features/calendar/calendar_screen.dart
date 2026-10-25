import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_error_state.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_max_width.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../add/add_flow.dart';
import 'views/calendar_agenda_view.dart';

enum CalendarViewMode {
  day,
  month;

  // Backwards compatibility aliases
  static const CalendarViewMode week = CalendarViewMode.day;
  static const CalendarViewMode agenda = CalendarViewMode.day;
  static const CalendarViewMode year = CalendarViewMode.month;
}

class CalendarScreen extends ConsumerStatefulWidget {
  final List<LocalCalendarEvent>? initialEvents;
  final List<LocalSubscription>? initialSubscriptions;
  final CalendarViewMode initialMode;
  final DateTime? initialSelectedDate;
  final ValueChanged<DateTime>? onSelectedDateChanged;

  const CalendarScreen({
    super.key,
    this.initialEvents,
    this.initialSubscriptions,
    this.initialMode = CalendarViewMode.day,
    this.initialSelectedDate,
    this.onSelectedDateChanged,
  });

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _selectedDate;

  Future<void> _handleRefresh() async {
    final homeId = ref.read(activeHomeIdProvider);
    await ref.read(syncEngineProvider).pullLatestEvents(homeId: homeId);
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialSelectedDate ?? clock.now();
  }

  @override
  void didUpdateWidget(covariant CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedDate != null &&
        widget.initialSelectedDate != oldWidget.initialSelectedDate) {
      _selectedDate = widget.initialSelectedDate!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
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
        backgroundColor: cv.surfaceCanvas,
        body: const Center(child: CoveLoading()),
      );
    }

    if (eventsAsync.hasError || subsAsync.hasError) {
      return Scaffold(
        backgroundColor: cv.surfaceCanvas,
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
    final cv = context.cv;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SafeArea(
        bottom: false,
        child: CoveMaxWidth(
          child: RefreshIndicator(
            color: cv.accentFill,
            backgroundColor: cv.surfaceCard,
            onRefresh: _handleRefresh,
            child: CalendarAgendaView(
              events: events,
              subscriptions: subscriptions,
              outboxEvents: outboxEvents,
              selectedDate: _selectedDate,
              onSelectDate: (d) {
                setState(() => _selectedDate = d);
                widget.onSelectedDateChanged?.call(d);
              },
              onAddEvent: () => AddFlow.show(
                context,
                anchor: _selectedDate,
              ),
              hasPartner: hasPartner,
            ),
          ),
        ),
      ),
    );
  }
}
