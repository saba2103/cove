import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import 'routine_controller.dart';
import 'routine_event_form_sheet.dart';
import 'routine_form_sheet.dart';
import 'routine_models.dart';

class RoutineScreen extends ConsumerStatefulWidget {
  const RoutineScreen({super.key});

  @override
  ConsumerState<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends ConsumerState<RoutineScreen> {
  final ScrollController _timelineScrollController = ScrollController();
  static const double _hourHeight = 64.0;
  static const double _timeGutterWidth = 64.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(routineControllerProvider).seedDefaultRoutinesIfEmpty();
      // Scroll timeline to reasonable morning hour (e.g. 7 AM)
      if (_timelineScrollController.hasClients) {
        _timelineScrollController.jumpTo(7 * _hourHeight);
      }
    });
  }

  @override
  void dispose() {
    _timelineScrollController.dispose();
    super.dispose();
  }

  void _openRoutineForm([Routine? routine]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoutineFormSheet(routine: routine),
    );
  }

  void _openEventForm(String routineId, {RoutineEvent? event, int? initialStartMinutes}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoutineEventFormSheet(
        routineId: routineId,
        event: event,
        initialStartMinutes: initialStartMinutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final routinesAsync = ref.watch(activeHomeRoutinesProvider);
    final selectedRoutineId = ref.watch(selectedRoutineIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Daily Routines',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'New Routine',
            onPressed: () => _openRoutineForm(),
          ),
        ],
      ),
      body: routinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading routines: $err')),
        data: (routines) {
          if (routines.isEmpty) {
            return _buildEmptyState(theme, colors);
          }

          // Ensure a selected routine
          final currentRoutine = routines.firstWhere(
            (r) => r.id == selectedRoutineId,
            orElse: () => routines.first,
          );

          return Column(
            children: [
              _buildRoutineTabs(routines, currentRoutine, colors),
              const Divider(height: 1),
              Expanded(
                child: _buildTimelineView(currentRoutine, colors),
              ),
            ],
          );
        },
      ),
      floatingActionButton: routinesAsync.maybeWhen(
        data: (routines) {
          if (routines.isEmpty) return null;
          final currentRoutine = routines.firstWhere(
            (r) => r.id == selectedRoutineId,
            orElse: () => routines.first,
          );
          return FloatingActionButton.extended(
            onPressed: () => _openEventForm(currentRoutine.id),
            backgroundColor: colors.accentPrimary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Event',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, CoveColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_outlined, size: 64, color: colors.accentPrimary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              'No Routines Yet',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Create daily routines for weekdays, weekends, or specific days.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: colors.accentPrimary),
              onPressed: () => _openRoutineForm(),
              icon: const Icon(Icons.add),
              label: const Text('Create Routine'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineTabs(List<Routine> routines, Routine selected, CoveColors colors) {
    return Container(
      height: 56,
      color: Theme.of(context).cardColor,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: routines.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == routines.length) {
            return ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('New Tab'),
              onPressed: () => _openRoutineForm(),
            );
          }

          final routine = routines[index];
          final isSelected = routine.id == selected.id;

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              ref.read(selectedRoutineIdProvider.notifier).select(routine.id);
            },
            onLongPress: () => _openRoutineForm(routine),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? colors.accentPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? colors.accentPrimary : Theme.of(context).dividerColor,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    routine.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _openRoutineForm(routine),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineView(Routine routine, CoveColors colors) {
    final eventsAsync = ref.watch(routineEventsProvider(routine.id));

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (events) {
        return SingleChildScrollView(
          controller: _timelineScrollController,
          child: SizedBox(
            height: 24 * _hourHeight,
            child: Stack(
              children: [
                // 1. Grid lines and hour markers
                _buildHourlyGrid(routine.id),

                // 2. Events layer
                ...events.map((ev) => _buildEventBlock(routine.id, ev)),

                // 3. Current time line (if current day of week matches routine)
                _buildCurrentTimeIndicator(routine, colors),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHourlyGrid(String routineId) {
    final theme = Theme.of(context);

    return Column(
      children: List.generate(24, (hour) {
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final label = '$displayHour $period';

        return InkWell(
          onTap: () => _openEventForm(routineId, initialStartMinutes: hour * 60),
          child: SizedBox(
            height: _hourHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _timeGutterWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, top: 2),
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEventBlock(String routineId, RoutineEvent event) {
    const totalDayMinutes = 1440.0;
    const totalHeight = 24 * _hourHeight;

    final top = (event.startMinutes / totalDayMinutes) * totalHeight;
    final duration = event.durationMinutes;
    final rawHeight = (duration / totalDayMinutes) * totalHeight;
    final height = rawHeight.clamp(32.0, totalHeight - top);

    final color = event.categoryColor;

    return Positioned(
      top: top,
      left: _timeGutterWidth + 8,
      right: 16,
      height: height,
      child: GestureDetector(
        onTap: () => _openEventForm(routineId, event: event),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            event.formattedTimeRange,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).hintColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (height > 44 && event.notes != null && event.notes!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          event.notes!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(Routine routine, CoveColors colors) {
    final now = DateTime.now();
    // Monday is 1, Sunday is 7 in DateTime.weekday
    if (!routine.days.contains(now.weekday)) {
      return const SizedBox.shrink();
    }

    final currentMinutes = now.hour * 60 + now.minute;
    const totalDayMinutes = 1440.0;
    const totalHeight = 24 * _hourHeight;
    final top = (currentMinutes / totalDayMinutes) * totalHeight;

    return Positioned(
      top: top - 4,
      left: _timeGutterWidth - 6,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: colors.accentSecondary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: colors.accentSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
