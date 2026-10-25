import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_avatar.dart';
import '../../core/widgets/cove_max_width.dart';
import '../../core/widgets/cove_page_header.dart';
import '../../core/widgets/cove_round_button.dart';
import '../../sync/providers/active_home_provider.dart';
import '../add/add_draft.dart';
import '../add/add_flow.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/user_profile_controller.dart';
import 'routine_controller.dart';
import 'routine_event_form_sheet.dart';
import 'routine_form_sheet.dart';
import 'routine_models.dart';

/// Routines — the shape of a day (`design/screens/routines.md`).
///
/// Order:
/// 1. [CovePageHeader] — "Routines", gold add ([CoveRoundButton]).
/// 2. Filter chips — routine selector pills with event counts.
/// 3. Two-person legend — [CoveAvatar.inline] for Person A (creator) and
///    Person B (joiner), keyed strictly to `home.createdBy`.
/// 4. The day canvas — a dusk-to-dawn sky gradient strip with routine bands
///    positioned by real time (`startMinutes`..`endMinutes`) and a NOW marker.
class RoutineScreen extends ConsumerStatefulWidget {
  const RoutineScreen({super.key});

  @override
  ConsumerState<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends ConsumerState<RoutineScreen> {
  final ScrollController _timelineScrollController = ScrollController();

  static const double _hourHeight = 64.0;
  static const double _timeGutterWidth = 42.0;
  static const double _chipHeight = 36.0;
  static const double _minEventHeight = 36.0;
  static const double _threeLineEventHeight = 72.0;
  static const double _eventAccentBarWidth = 4.0;
  static const double _nowDotSize = 8.0;
  static const double _nowLineHeight = 1.5;
  static const double _emptyIconSize = 48.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(routineControllerProvider).seedDefaultRoutinesIfEmpty();
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoutineFormSheet(routine: routine),
    );
  }

  void _openEventForm(
    String routineId, {
    RoutineEvent? event,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoutineEventFormSheet(
        routineId: routineId,
        event: event,
      ),
    );
  }

  LinearGradient _buildSkyGradient(CoveTokens cv) {
    final night = cv.surfaceCanvas;
    final preDawn = cv.surfaceRow;
    final dawn = Color.lerp(cv.surfaceCard, cv.accentFill, 0.28)!;
    final morning = Color.lerp(cv.surfaceCard, cv.categoryPets, 0.14)!;
    final midday = Color.lerp(cv.surfaceCard, cv.categoryFuel, 0.14)!;
    final dusk = Color.lerp(cv.surfaceCard, cv.accentFill, 0.24)!;
    final twilight = Color.lerp(cv.surfaceRow, cv.moneyMore, 0.14)!;

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [
        0.00, // 12 AM — deep night
        0.18, // ~4:20 AM — pre-dawn
        0.26, // ~6:15 AM — dawn horizon
        0.38, // ~9:00 AM — morning sky
        0.58, // ~2:00 PM — afternoon sky
        0.74, // ~5:45 PM — dusk horizon
        0.84, // ~8:10 PM — twilight
        1.00, // 11:59 PM — night
      ],
      colors: [
        night,
        preDawn,
        dawn,
        morning,
        midday,
        dusk,
        twilight,
        night,
      ],
    );
  }

  _RoutineBandPalette _resolveBandPalette(CoveTokens cv, String? category) {
    final cat = (category ?? 'general').toLowerCase().trim();
    switch (cat) {
      case 'meals':
      case 'food':
      case 'breakfast':
      case 'lunch':
      case 'dinner':
        return _RoutineBandPalette(
          accent: cv.accentFill,
          fill: cv.accentWash,
          border: cv.accentFill.withValues(alpha: 0.45),
        );
      case 'work':
      case 'focus':
        return _RoutineBandPalette(
          accent: cv.categoryFuel,
          fill: cv.surfaceCard.withValues(alpha: 0.78),
          border: cv.lineStrong,
        );
      case 'fitness':
      case 'workout':
      case 'exercise':
        return _RoutineBandPalette(
          accent: cv.categoryHealth,
          fill: cv.surfaceCard.withValues(alpha: 0.78),
          border: cv.lineStrong,
        );
      case 'health':
      case 'wellness':
        return _RoutineBandPalette(
          accent: cv.categoryPets,
          fill: cv.surfaceCard.withValues(alpha: 0.78),
          border: cv.lineStrong,
        );
      case 'sleep':
      case 'rest':
        return _RoutineBandPalette(
          accent: cv.categoryGifts,
          fill: cv.surfaceCanvas.withValues(alpha: 0.78),
          border: cv.lineStrong,
        );
      case 'study':
      case 'reading':
      case 'learning':
        return _RoutineBandPalette(
          accent: cv.categoryHome,
          fill: cv.surfaceCard.withValues(alpha: 0.78),
          border: cv.lineStrong,
        );
      case 'household':
      case 'chores':
        return _RoutineBandPalette(
          accent: cv.categoryTravel,
          fill: cv.surfaceCard.withValues(alpha: 0.78),
          border: cv.lineStrong,
        );
      case 'leisure':
      case 'hobby':
      case 'relax':
        return _RoutineBandPalette(
          accent: cv.categoryEatingOut,
          fill: cv.surfaceCard.withValues(alpha: 0.78),
          border: cv.lineStrong,
        );
      default:
        return _RoutineBandPalette(
          accent: cv.accentTint,
          fill: cv.surfaceCard.withValues(alpha: 0.78),
          border: cv.lineStrong,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final routinesAsync = ref.watch(activeHomeRoutinesProvider);
    final selectedRoutineId = ref.watch(selectedRoutineIdProvider);
    final allEvents =
        ref.watch(activeHomeAllRoutineEventsProvider).value ?? const [];

    final activeHome = ref.watch(activeHomeProvider).value;
    final user = ref.watch(authProvider).value;
    final userProfile = ref.watch(userProfileProvider);
    final partnerProfile = ref.watch(partnerProfileProvider);

    final viewerIsCreator =
        activeHome == null ||
        user == null ||
        user.id.isEmpty ||
        user.id == activeHome.createdBy;
    final creatorName = viewerIsCreator
        ? (userProfile.displayName.isNotEmpty
            ? userProfile.displayName
            : 'Alex')
        : (partnerProfile.displayName.isNotEmpty
            ? partnerProfile.displayName
            : 'Partner');
    final joinerName = viewerIsCreator
        ? (partnerProfile.displayName.isNotEmpty
            ? partnerProfile.displayName
            : 'Partner')
        : (userProfile.displayName.isNotEmpty
            ? userProfile.displayName
            : 'Alex');

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SafeArea(
        bottom: false,
        child: routinesAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: cv.accentFill),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
              child: Text(
                'Error loading routines: $err',
                style: CoveType.body.copyWith(color: cv.statusAlertText),
              ),
            ),
          ),
          data: (routines) {
            if (routines.isEmpty) {
              return CoveMaxWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CovePageHeader(
                      title: 'Routines',
                      actions: [
                        CoveRoundButton(
                          icon: Icons.add_rounded,
                          variant: CoveRoundButtonVariant.gold,
                          semanticLabel: 'New Routine',
                          onPressed: _openRoutineForm,
                        ),
                      ],
                    ),
                    Expanded(child: _buildEmptyState(cv)),
                  ],
                ),
              );
            }

            final currentRoutine = routines.firstWhere(
              (r) => r.id == selectedRoutineId,
              orElse: () => routines.first,
            );

            return SingleChildScrollView(
              controller: _timelineScrollController,
              padding: EdgeInsets.only(
                bottom: CoveSpace.barClearance + bottomInset,
              ),
              child: CoveMaxWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. CovePageHeader — "Routines", gold add
                    CovePageHeader(
                      title: 'Routines',
                      actions: [
                        CoveRoundButton(
                          icon: Icons.add_rounded,
                          variant: CoveRoundButtonVariant.gold,
                          semanticLabel: 'Add Event',
                          onPressed: () => AddFlow.show(
                            context,
                            kind: AddKind.routine,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: CoveSpace.lg),

                    // 2. Filter chips
                    _buildRoutineTabs(
                      routines,
                      currentRoutine,
                      allEvents,
                      cv,
                    ),

                    const SizedBox(height: CoveSpace.lg),

                    // 3. Two-person legend
                    _buildTwoPersonLegend(creatorName, joinerName, cv),

                    const SizedBox(height: CoveSpace.md),

                    // 4. The day canvas — dusk-to-dawn strip with routine bands
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CoveSpace.gutter,
                      ),
                      child: _buildTimelineView(currentRoutine, cv),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(CoveTokens cv) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CoveSpace.section),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule_outlined,
              size: _emptyIconSize,
              color: cv.accentText,
            ),
            const SizedBox(height: CoveSpace.md),
            Text(
              'No Routines Yet',
              style: CoveType.title.copyWith(color: cv.textPrimary),
            ),
            const SizedBox(height: CoveSpace.sm),
            Text(
              'Create daily routines for weekdays, weekends, or specific days.',
              textAlign: TextAlign.center,
              style: CoveType.body.copyWith(color: cv.textSecondary),
            ),
            const SizedBox(height: CoveSpace.lg),
            GestureDetector(
              onTap: _openRoutineForm,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cv.accentFill,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(CoveRadius.pill),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.lg,
                    vertical: CoveSpace.md,
                  ),
                  child: Text(
                    'Create Routine',
                    style: CoveType.rowTitle.copyWith(color: cv.textOnAccent),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineTabs(
    List<Routine> routines,
    Routine selected,
    List<RoutineEvent> allEvents,
    CoveTokens cv,
  ) {
    final duration = CoveMotion.q(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
      child: Row(
        children: [
          for (var i = 0; i < routines.length; i++) ...[
            if (i > 0) const SizedBox(width: CoveSpace.sm),
            _buildRoutineChip(
              routine: routines[i],
              isSelected: routines[i].id == selected.id,
              eventCount: allEvents
                  .where((e) => e.routineId == routines[i].id)
                  .length,
              duration: duration,
              cv: cv,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoutineChip({
    required Routine routine,
    required bool isSelected,
    required int eventCount,
    required Duration duration,
    required CoveTokens cv,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (isSelected) {
          _openRoutineForm(routine);
        } else {
          ref.read(selectedRoutineIdProvider.notifier).select(routine.id);
        }
      },
      onLongPress: () => _openRoutineForm(routine),
      child: AnimatedContainer(
        duration: duration,
        curve: CoveMotion.easing,
        height: _chipHeight,
        padding: const EdgeInsets.symmetric(horizontal: CoveSpace.md),
        decoration: BoxDecoration(
          color: isSelected ? cv.accentFill : Colors.transparent,
          borderRadius: const BorderRadius.all(
            Radius.circular(CoveRadius.pill),
          ),
          border: Border.all(
            color: isSelected ? cv.accentFill : cv.lineStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              routine.name,
              style: CoveType.readout.copyWith(
                color: isSelected ? cv.textOnAccent : cv.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (eventCount > 0) ...[
              const SizedBox(width: CoveSpace.sm),
              Text(
                '$eventCount',
                style: CoveType.readout.copyWith(
                  color: isSelected
                      ? cv.textOnAccent.withValues(alpha: 0.72)
                      : cv.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTwoPersonLegend(
    String creatorName,
    String joinerName,
    CoveTokens cv,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CoveAvatar.inline(
                  person: CovePerson.a,
                  nameOrInitial: creatorName,
                ),
                const SizedBox(width: CoveSpace.sm),
                Flexible(
                  child: Text(
                    creatorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoveType.readout.copyWith(
                      color: cv.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: CoveSpace.section),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CoveAvatar.inline(
                  person: CovePerson.b,
                  nameOrInitial: joinerName,
                ),
                const SizedBox(width: CoveSpace.sm),
                Flexible(
                  child: Text(
                    joinerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoveType.readout.copyWith(
                      color: cv.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineView(Routine routine, CoveTokens cv) {
    final eventsAsync = ref.watch(routineEventsProvider(routine.id));

    return eventsAsync.when(
      loading: () => SizedBox(
        height: 4 * _hourHeight,
        child: Center(
          child: CircularProgressIndicator(color: cv.accentFill),
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(CoveSpace.lg),
        child: Text(
          'Error: $err',
          style: CoveType.body.copyWith(color: cv.statusAlertText),
        ),
      ),
      data: (events) {
        return ClipRRect(
          borderRadius: const BorderRadius.all(
            Radius.circular(CoveRadius.hero),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.hero),
              ),
              border: Border.all(color: cv.lineHairline),
              gradient: _buildSkyGradient(cv),
            ),
            child: SizedBox(
              height: 24 * _hourHeight,
              child: Stack(
                children: [
                  // 1. Hourly grid & time markers
                  _buildHourlyGrid(routine.id, cv),

                  // 2. Routine bands positioned by real time
                  ...events.map((ev) => _buildEventBlock(routine.id, ev, cv)),

                  // 3. NOW marker (when current weekday matches routine)
                  _buildCurrentTimeIndicator(routine, cv),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHourlyGrid(String routineId, CoveTokens cv) {
    return Column(
      children: List.generate(24, (hour) {
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final label = '$displayHour $period';

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => AddFlow.show(
            context,
            kind: AddKind.routine,
          ),
          child: SizedBox(
            height: _hourHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _timeGutterWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: CoveSpace.sm,
                      top: CoveSpace.xs,
                    ),
                    child: Text(
                      label,
                      style: CoveType.barLabel.copyWith(
                        color: cv.textTertiary,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: cv.lineHairline),
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEventBlock(
    String routineId,
    RoutineEvent event,
    CoveTokens cv,
  ) {
    const totalDayMinutes = 1440.0;
    const totalHeight = 24 * _hourHeight;

    final top = (event.startMinutes / totalDayMinutes) * totalHeight;
    final duration = event.durationMinutes;
    final rawHeight = (duration / totalDayMinutes) * totalHeight;
    final height = rawHeight.clamp(_minEventHeight, totalHeight - top);

    final palette = _resolveBandPalette(cv, event.category);
    final isMultiLine = height >= CoveSize.row;
    final showNotes = height >= _threeLineEventHeight &&
        event.notes != null &&
        event.notes!.isNotEmpty;

    return Positioned(
      top: top,
      left: _timeGutterWidth,
      right: CoveSpace.sm,
      height: height,
      child: GestureDetector(
        onTap: () => _openEventForm(routineId, event: event),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.fill,
            borderRadius: const BorderRadius.all(
              Radius.circular(CoveRadius.inline),
            ),
            border: Border.all(color: palette.border),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(
              Radius.circular(CoveRadius.inline),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: _eventAccentBarWidth,
                  height: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: palette.accent),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CoveSpace.sm,
                      vertical: CoveSpace.xs,
                    ),
                    child: isMultiLine
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                event.title,
                                style: CoveType.rowTitle.copyWith(
                                  color: cv.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                event.formattedTimeRange,
                                style: CoveType.rowSub.copyWith(
                                  color: cv.textTertiary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (showNotes)
                                Text(
                                  event.notes!,
                                  style: CoveType.rowSub.copyWith(
                                    color: cv.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: CoveType.rowTitle.copyWith(
                                    color: cv.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: CoveSpace.sm),
                              Text(
                                event.formattedTimeRange,
                                style: CoveType.rowSub.copyWith(
                                  color: cv.textTertiary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(Routine routine, CoveTokens cv) {
    final now = clock.now();
    if (!routine.days.contains(now.weekday)) {
      return const SizedBox.shrink();
    }

    final currentMinutes = now.hour * 60 + now.minute;
    const totalDayMinutes = 1440.0;
    const totalHeight = 24 * _hourHeight;
    final top = (currentMinutes / totalDayMinutes) * totalHeight;

    return Positioned(
      top: top - (_nowDotSize / 2),
      left: _timeGutterWidth - (_nowDotSize / 2),
      right: 0,
      child: Row(
        children: [
          SizedBox(
            width: _nowDotSize,
            height: _nowDotSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cv.accentFill,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: _nowLineHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: cv.accentFill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineBandPalette {
  final Color accent;
  final Color fill;
  final Color border;

  const _RoutineBandPalette({
    required this.accent,
    required this.fill,
    required this.border,
  });
}
