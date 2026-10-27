import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_avatar.dart';
import '../../core/widgets/cove_max_width.dart';
import '../../core/widgets/cove_page_header.dart';
import '../../core/widgets/cove_round_button.dart';
import '../../core/widgets/cove_section_label.dart';
import '../../core/widgets/cove_seed_card.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/first_run_provider.dart';
import '../add/add_draft.dart';
import '../add/add_flow.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/user_profile_controller.dart';
import 'routine_controller.dart';
import 'routine_event_form_sheet.dart';
import 'routine_form_sheet.dart';
import 'routine_models.dart';

/// Which person's solo routine lane is focused when tapped in the legend.
enum RoutineLaneFocus {
  /// Left lane (viewer / yours) is focused; partner's right lane is faded.
  yours,

  /// Right lane (partner's) is focused; your left lane is faded.
  partner,
}

enum _RoutineBandOwnerKind {
  yours,
  partner,
  both,
}

/// Routines — the shape of a day (`design/screens/routines.md` & `4.7d`).
///
/// Order:
/// 1. [CovePageHeader] — "Routines", gold add ([CoveRoundButton]).
/// 2. Filter chips — routine selector pills (`Everyday · Weekdays · Weekend`).
/// 3. Two-person legend — yours on the left, your partner's on the right;
///    tapping a person fades the other lane while shared gold stays.
/// 4. The day canvas — a dusk-to-dawn sky gradient strip with two lanes:
///    yours on the left, your partner's on the right, `both` drawn in solid
///    gold spanning the split, solo routines as frosted glass in their own
///    lane, and a NOW marker.
class RoutineScreen extends ConsumerStatefulWidget {
  final RoutineLaneFocus? initialFocusedLane;

  const RoutineScreen({
    super.key,
    this.initialFocusedLane,
  });

  @override
  ConsumerState<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends ConsumerState<RoutineScreen> {
  final ScrollController _timelineScrollController = ScrollController();
  RoutineLaneFocus? _focusedLane;

  static const double _hourHeight = 64.0;
  static const double _asleepStripHeight = 40.0;
  static const double _timeGutterWidth = 42.0;
  static const double _chipHeight = 36.0;
  static const double _minEventHeight = 36.0;
  static const double _compactEventHeight = 50.0;
  static const double _threeLineEventHeight = 76.0;
  static const double _laneGap = 6.0;
  static const double _fadedLaneOpacity = 0.25;
  static const double _nowDotSize = 8.0;
  static const double _nowLineHeight = 1.5;
  static const double _emptyIconSize = 48.0;
  static const double _asleepIconSize = 13.0;
  static const double _blurSigma = 10.0;

  @override
  void initState() {
    super.initState();
    _focusedLane = widget.initialFocusedLane;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(routineControllerProvider).seedDefaultRoutinesIfEmpty();
    });
  }

  @override
  void didUpdateWidget(covariant RoutineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFocusedLane != widget.initialFocusedLane) {
      _focusedLane = widget.initialFocusedLane;
    }
  }

  @override
  void dispose() {
    _timelineScrollController.dispose();
    super.dispose();
  }

  void _toggleLaneFocus(RoutineLaneFocus lane) {
    setState(() {
      _focusedLane = _focusedLane == lane ? null : lane;
    });
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
        0.00, // Deep night / asleep
        0.08, // Dawn horizon (~6:30 AM)
        0.24, // Morning sky (~9:00 AM)
        0.48, // Midday sky (~1:00 PM)
        0.72, // Dusk horizon (~5:30 PM)
        0.86, // Twilight (~8:30 PM)
        1.00, // Night (~11:59 PM)
      ],
      colors: [
        night,
        dawn,
        morning,
        midday,
        dusk,
        twilight,
        preDawn,
      ],
    );
  }

  _RoutineBandOwnerKind _classifyOwner(String rawOwner, String currentUserId) {
    final trimmed = rawOwner.trim();
    if (trimmed.isEmpty || trimmed == 'both') {
      return _RoutineBandOwnerKind.both;
    }
    if (trimmed == currentUserId ||
        trimmed == 'local_user' ||
        trimmed == 'me' ||
        trimmed == 'you') {
      return _RoutineBandOwnerKind.yours;
    }
    return _RoutineBandOwnerKind.partner;
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
    final myName = userProfile.displayName.trim().isNotEmpty
        ? userProfile.displayName.trim()
        : (user?.displayName?.trim().isNotEmpty == true
              ? user!.displayName!.trim()
              : 'Alex');
    final partnerName = partnerProfile.displayName.trim().isNotEmpty
        ? partnerProfile.displayName.trim()
        : 'Partner';
    final myPerson = viewerIsCreator ? CovePerson.a : CovePerson.b;
    final partnerPerson = viewerIsCreator ? CovePerson.b : CovePerson.a;

    final bottomInset = CovePageInsets.bottomOf(context);
    final isFirstRun =
        ref.watch(firstRunProvider(CoveScreen.routines)) == FirstRunState.firstRun;
    final firstRunPartner = resolveFirstRunPartnerName(ref);

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: CovePageInsets(
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
            final currentRoutine = routines.isEmpty
                ? null
                : routines.firstWhere(
                    (r) => r.id == selectedRoutineId,
                    orElse: () => routines.first,
                  );

            if (isFirstRun) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: CoveSpace.barClearance + bottomInset,
                ),
                child: CoveMaxWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                              routineId: currentRoutine?.id,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: CoveSpace.lg),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CoveSpace.gutter,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CoveSeedCard(
                              art: CoveSeedArtKind.bands,
                              title: 'Two days, not yet drawn',
                              body:
                                  'A routine is the shape a day repeats — the '
                                  'walk, the standing call, lights out. Add a '
                                  'few and the sky fills in behind them.',
                              buttonLabel: 'Add a routine',
                              onPressed: () => AddFlow.show(
                                context,
                                kind: AddKind.routine,
                                routineId: currentRoutine?.id,
                              ),
                              altText:
                                  "Yours on the left, $firstRunPartner's on the right.",
                            ),
                            const SizedBox(height: CoveSpace.section),
                            const CoveSectionLabel.page(
                              label: 'EVERYDAY',
                              readout: '0',
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: CoveSpace.lg,
                              ),
                              child: Text(
                                'Nothing repeats yet.',
                                textAlign: TextAlign.center,
                                style: CoveType.readout.copyWith(
                                  color: cv.textTertiary,
                                ),
                              ),
                            ),
                            const CoveSectionLabel.page(
                              label: 'WEEKDAYS',
                              readout: '0',
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: CoveSpace.lg,
                              ),
                              child: Text(
                                'Nothing repeats yet.',
                                textAlign: TextAlign.center,
                                style: CoveType.readout.copyWith(
                                  color: cv.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (routines.isEmpty) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: CoveSpace.barClearance + bottomInset,
                ),
                child: CoveMaxWidth(
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
                      _buildEmptyState(cv),
                    ],
                  ),
                ),
              );
            }

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
                            routineId: currentRoutine!.id,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: CoveSpace.lg),

                    // 2. Filter chips
                    _buildRoutineTabs(
                      routines,
                      currentRoutine!,
                      allEvents,
                      cv,
                    ),

                    const SizedBox(height: CoveSpace.lg),

                    // 3. Two-person legend (yours on the left, partner's on the right)
                    _buildTwoPersonLegend(
                      myName: myName,
                      myPerson: myPerson,
                      partnerName: partnerName,
                      partnerPerson: partnerPerson,
                      cv: cv,
                    ),

                    const SizedBox(height: CoveSpace.md),

                    // 4. The day canvas — dusk-to-dawn strip with two routine lanes
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
                decoration: CoveShape.decoration(
                  CoveRadius.pill,
                  color: cv.accentFill,
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
        decoration: CoveShape.decoration(
          CoveRadius.pill,
          color: isSelected ? cv.accentFill : Colors.transparent,
          side: BorderSide(
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

  Widget _buildTwoPersonLegend({
    required String myName,
    required CovePerson myPerson,
    required String partnerName,
    required CovePerson partnerPerson,
    required CoveTokens cv,
  }) {
    final duration = CoveMotion.q(context);
    final yoursOpacity =
        _focusedLane == RoutineLaneFocus.partner ? _fadedLaneOpacity : 1.0;
    final partnerOpacity =
        _focusedLane == RoutineLaneFocus.yours ? _fadedLaneOpacity : 1.0;

    return Padding(
      padding: const EdgeInsets.only(
        left: CoveSpace.gutter + _timeGutterWidth,
        right: CoveSpace.gutter + CoveSpace.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Semantics(
                button: true,
                selected: _focusedLane == RoutineLaneFocus.yours,
                label: myName,
                child: GestureDetector(
                  key: const ValueKey('routine_legend_yours'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _toggleLaneFocus(RoutineLaneFocus.yours),
                  child: AnimatedOpacity(
                    key: const ValueKey('routine_legend_opacity_yours'),
                    duration: duration,
                    curve: CoveMotion.easing,
                    opacity: yoursOpacity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CoveSpace.sm,
                        vertical: CoveSpace.xs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CoveAvatar.inline(
                            person: myPerson,
                            nameOrInitial: myName,
                          ),
                          const SizedBox(width: CoveSpace.sm),
                          Flexible(
                            child: Text(
                              myName,
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
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: _laneGap),
          Expanded(
            child: Center(
              child: Semantics(
                button: true,
                selected: _focusedLane == RoutineLaneFocus.partner,
                label: partnerName,
                child: GestureDetector(
                  key: const ValueKey('routine_legend_partner'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _toggleLaneFocus(RoutineLaneFocus.partner),
                  child: AnimatedOpacity(
                    key: const ValueKey('routine_legend_opacity_partner'),
                    duration: duration,
                    curve: CoveMotion.easing,
                    opacity: partnerOpacity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CoveSpace.sm,
                        vertical: CoveSpace.xs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CoveAvatar.inline(
                            person: partnerPerson,
                            nameOrInitial: partnerName,
                          ),
                          const SizedBox(width: CoveSpace.sm),
                          Flexible(
                            child: Text(
                              partnerName,
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
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineView(Routine routine, CoveTokens cv) {
    final eventsAsync = ref.watch(routineEventsProvider(routine.id));
    final user = ref.watch(authProvider).value;
    final currentUserId = user?.id ?? 'local_user';

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
        final hasEarlyEvents = events.any((e) => e.startMinutes < 360);
        final startHour = hasEarlyEvents ? 0 : 6;
        final hourCount = 24 - startHour;
        final topOffset = hasEarlyEvents ? 0.0 : _asleepStripHeight;
        final totalHeight = topOffset + hourCount * _hourHeight;

        final soloEvents = <RoutineEvent>[];
        final sharedEvents = <RoutineEvent>[];
        for (final ev in events) {
          final kind = _classifyOwner(ev.owner, currentUserId);
          if (kind == _RoutineBandOwnerKind.both) {
            sharedEvents.add(ev);
          } else {
            soloEvents.add(ev);
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final canvasWidth = constraints.maxWidth;
            const trackLeft = _timeGutterWidth;
            const trackRight = CoveSpace.sm;
            final trackWidth =
                (canvasWidth - trackLeft - trackRight).clamp(0.0, double.infinity);
            final laneWidth =
                ((trackWidth - _laneGap) / 2).clamp(0.0, double.infinity);
            final splitX = trackLeft + laneWidth + (_laneGap / 2);

            return CoveShape.clip(
              CoveRadius.hero,
              DecoratedBox(
                decoration: CoveShape.decoration(
                  CoveRadius.hero,
                  side: BorderSide(color: cv.lineHairline),
                  gradient: _buildSkyGradient(cv),
                ),
                child: SizedBox(
                  height: totalHeight,
                  child: Stack(
                    children: [
                      // 1. Pre-dawn asleep header + hourly grid & time markers
                      _buildHourlyGrid(
                        routine.id,
                        cv,
                        startHour: startHour,
                        topOffset: topOffset,
                      ),

                      // 2. Center split line separating left lane (yours) and right lane (partner's)
                      Positioned(
                        key: const ValueKey('routine_lane_split_line'),
                        top: topOffset,
                        bottom: 0,
                        left: splitX - 0.5,
                        width: 1.0,
                        child: ColoredBox(color: cv.lineHairline),
                      ),

                      // 3. Solo frosted-glass routine bands in their own lane
                      for (final ev in soloEvents)
                        _buildEventBlock(
                          routineId: routine.id,
                          event: ev,
                          ownerKind: _classifyOwner(ev.owner, currentUserId),
                          startHour: startHour,
                          topOffset: topOffset,
                          totalHeight: totalHeight,
                          trackLeft: trackLeft,
                          trackWidth: trackWidth,
                          laneWidth: laneWidth,
                          cv: cv,
                        ),

                      // 4. Shared ('both') solid gold bands spanning across the split
                      for (final ev in sharedEvents)
                        _buildEventBlock(
                          routineId: routine.id,
                          event: ev,
                          ownerKind: _RoutineBandOwnerKind.both,
                          startHour: startHour,
                          topOffset: topOffset,
                          totalHeight: totalHeight,
                          trackLeft: trackLeft,
                          trackWidth: trackWidth,
                          laneWidth: laneWidth,
                          cv: cv,
                        ),

                      // 5. NOW marker (when current weekday matches routine)
                      _buildCurrentTimeIndicator(
                        routine,
                        cv,
                        startHour: startHour,
                        topOffset: topOffset,
                        totalHeight: totalHeight,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHourlyGrid(
    String routineId,
    CoveTokens cv, {
    required int startHour,
    required double topOffset,
  }) {
    final hourCount = 24 - startHour;

    return Column(
      children: [
        if (topOffset > 0)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => AddFlow.show(
              context,
              kind: AddKind.routine,
              routineId: routineId,
              startMinutes: 6 * 60,
            ),
            child: SizedBox(
              height: topOffset,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: CoveSpace.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.bedtime_outlined,
                      size: _asleepIconSize,
                      color: cv.accentText.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: CoveSpace.xs),
                    Expanded(
                      child: Text(
                        'asleep · 7 h · 11p – 6a',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CoveType.rowSub.copyWith(
                          color: cv.textTertiary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ...List.generate(hourCount, (index) {
          final hour = startHour + index;
          final period = hour >= 12 ? 'PM' : 'AM';
          final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
          final label = '$displayHour $period';

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => AddFlow.show(
              context,
              kind: AddKind.routine,
              routineId: routineId,
              startMinutes: hour * 60,
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
      ],
    );
  }

  Widget _buildEventBlock({
    required String routineId,
    required RoutineEvent event,
    required _RoutineBandOwnerKind ownerKind,
    required int startHour,
    required double topOffset,
    required double totalHeight,
    required double trackLeft,
    required double trackWidth,
    required double laneWidth,
    required CoveTokens cv,
  }) {
    final startMin = event.startMinutes;
    final baseMinute = startHour * 60;
    final top = topOffset + ((startMin - baseMinute) / 60.0) * _hourHeight;
    final duration = event.durationMinutes;
    final rawHeight = (duration / 60.0) * _hourHeight;
    final height = rawHeight.clamp(_minEventHeight, totalHeight - top);

    final double left;
    final double width;
    final double opacity;

    switch (ownerKind) {
      case _RoutineBandOwnerKind.both:
        left = trackLeft;
        width = trackWidth;
        opacity = 1.0;
      case _RoutineBandOwnerKind.yours:
        left = trackLeft;
        width = laneWidth;
        opacity = _focusedLane == RoutineLaneFocus.partner
            ? _fadedLaneOpacity
            : 1.0;
      case _RoutineBandOwnerKind.partner:
        left = trackLeft + laneWidth + _laneGap;
        width = laneWidth;
        opacity = _focusedLane == RoutineLaneFocus.yours
            ? _fadedLaneOpacity
            : 1.0;
    }

    final isSharedGold = ownerKind == _RoutineBandOwnerKind.both;
    final bandRadius = height <= 44.0 ? CoveRadius.pill : CoveRadius.inline;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showNotes = height >= _threeLineEventHeight &&
        event.notes != null &&
        event.notes!.trim().isNotEmpty;

    final titleColor = isSharedGold ? cv.textOnAccent : cv.textPrimary;
    final subColor = isSharedGold
        ? cv.textOnAccent.withValues(alpha: 0.76)
        : cv.textSecondary;
    final notesColor = isSharedGold
        ? cv.textOnAccent.withValues(alpha: 0.82)
        : cv.textTertiary;

    final Widget content;
    if (isSharedGold && height < _compactEventHeight) {
      // Compact shared gold pill spanning both lanes: Title left, time right
      content = Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoveSpace.md,
          vertical: CoveSpace.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                event.title,
                style: CoveType.rowTitle.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: CoveSpace.sm),
            Text(
              event.formattedTimeRange,
              style: CoveType.rowSub.copyWith(
                color: subColor,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    } else if (height < _compactEventHeight) {
      // Compact solo frosted-glass band in a single lane: tight 2-line stack
      content = Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoveSpace.sm,
          vertical: 2.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              event.title,
              style: CoveType.readout.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              event.formattedTimeRange,
              style: CoveType.barLabel.copyWith(
                color: subColor,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    } else {
      // Multi-line block (45m+): Title, time range, and optional notes
      content = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isSharedGold ? CoveSpace.md : CoveSpace.sm + 2.0,
          vertical: CoveSpace.xs + 2.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: height >= 96.0
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Text(
              event.title,
              style: CoveType.rowTitle.copyWith(
                color: titleColor,
                fontWeight: isSharedGold ? FontWeight.w600 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              event.formattedTimeRange,
              style: CoveType.rowSub.copyWith(
                color: subColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (showNotes)
              Text(
                event.notes!,
                style: CoveType.rowSub.copyWith(
                  color: notesColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      );
    }

    final Widget bandSurface;
    if (isSharedGold) {
      bandSurface = DecoratedBox(
        key: ValueKey('routine_band_surface_${event.id}'),
        decoration: CoveShape.decoration(
          bandRadius,
          color: cv.accentFill,
          side: BorderSide(color: cv.accentFill),
        ),
        child: CoveShape.clip(bandRadius, content),
      );
    } else {
      final glassTop = Color.lerp(
        cv.surfaceCard,
        cv.textPrimary,
        isDark ? 0.09 : 0.04,
      )!.withValues(alpha: isDark ? 0.68 : 0.78);
      final glassBottom =
          cv.surfaceCard.withValues(alpha: isDark ? 0.52 : 0.66);

      bandSurface = CoveShape.clip(
        bandRadius,
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
          child: DecoratedBox(
            key: ValueKey('routine_band_surface_${event.id}'),
            decoration: CoveShape.decoration(
              bandRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [glassTop, glassBottom],
              ),
              side: BorderSide(color: cv.lineStrong),
            ),
            child: content,
          ),
        ),
      );
    }

    return Positioned(
      key: ValueKey('routine_band_${event.id}'),
      top: top,
      left: left,
      width: width,
      height: height,
      child: AnimatedOpacity(
        key: ValueKey('routine_band_opacity_${event.id}'),
        duration: CoveMotion.q(context),
        curve: CoveMotion.easing,
        opacity: opacity,
        child: GestureDetector(
          onTap: () => _openEventForm(routineId, event: event),
          child: bandSurface,
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(
    Routine routine,
    CoveTokens cv, {
    required int startHour,
    required double topOffset,
    required double totalHeight,
  }) {
    final now = clock.now();
    if (!routine.days.contains(now.weekday)) {
      return const SizedBox.shrink();
    }

    final currentMinutes = now.hour * 60 + now.minute;
    final baseMinute = startHour * 60;
    final double top;
    if (currentMinutes < baseMinute && topOffset > 0) {
      top = (currentMinutes / baseMinute) * topOffset;
    } else {
      top = topOffset + ((currentMinutes - baseMinute) / 60.0) * _hourHeight;
    }
    final clampedTop = top.clamp(0.0, totalHeight);

    return Positioned(
      top: clampedTop - (_nowDotSize / 2),
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
