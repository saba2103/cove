import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../calendar/calendar_models.dart';
import '../habits/habit_schedule.dart';
import '../profile/partner_profile_controller.dart';
import '../routines/routine_controller.dart';
import '../routines/routine_models.dart';

/// Gold arc strength on the 24-hour Day Arc ring (`design/specs/18-widgets.md` §1):
/// - [solid]: booked shared or viewer routines and events.
/// - [faint]: tentative or solo-partner routines and events.
enum DayArcStrength {
  solid,
  faint,
}

/// A routine band or calendar event arc on today's 24-hour Day Arc ring.
@immutable
class DayArcBand {
  final String id;
  final String title;
  final int startMinutes; // 0..1439
  final int endMinutes; // 0..1440
  final DayArcStrength strength;
  final bool isEvent;

  const DayArcBand({
    required this.id,
    required this.title,
    required this.startMinutes,
    required this.endMinutes,
    this.strength = DayArcStrength.solid,
    this.isEvent = false,
  });

  int get durationMinutes {
    if (endMinutes >= startMinutes) {
      return endMinutes - startMinutes;
    }
    return (1440 - startMinutes) + endMinutes;
  }

  /// Whether [minutesFromMidnight] falls inside this band.
  bool containsMinute(int minutesFromMidnight) {
    if (endMinutes >= startMinutes) {
      return minutesFromMidnight >= startMinutes &&
          minutesFromMidnight < endMinutes;
    }
    return minutesFromMidnight >= startMinutes ||
        minutesFromMidnight < endMinutes;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'strength': strength.name,
        'isEvent': isEvent,
      };

  factory DayArcBand.fromJson(Map<String, dynamic> json) {
    return DayArcBand(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      startMinutes: (json['startMinutes'] as num?)?.toInt() ?? 0,
      endMinutes: (json['endMinutes'] as num?)?.toInt() ?? 60,
      strength: (json['strength'] as String?) == DayArcStrength.faint.name
          ? DayArcStrength.faint
          : DayArcStrength.solid,
      isEvent: json['isEvent'] as bool? ?? false,
    );
  }
}

/// A habit dot sitting on the outer rim of the Day Arc at its scheduled time
/// (`design/specs/18-widgets.md` §1).
@immutable
class DayArcHabitDot {
  final String habitId;
  final String title;
  final int minutes; // 0..1439
  final bool isKept;

  const DayArcHabitDot({
    required this.habitId,
    required this.title,
    required this.minutes,
    required this.isKept,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'habitId': habitId,
        'title': title,
        'minutes': minutes,
        'isKept': isKept,
      };

  factory DayArcHabitDot.fromJson(Map<String, dynamic> json) {
    return DayArcHabitDot(
      habitId: json['habitId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      minutes: (json['minutes'] as num?)?.toInt() ?? 480,
      isKept: json['isKept'] as bool? ?? false,
    );
  }
}

/// Formats minutes from midnight (`0..1439`) as a 12-hour Bodoni figure
/// without AM/PM (e.g. `1:30`, `8:30`, `10:00`) per `design/specs/18-widgets.md` §1.
String formatDayArcTime(int minutesFromMidnight) {
  final normalized = ((minutesFromMidnight % 1440) + 1440) % 1440;
  final hour24 = normalized ~/ 60;
  final minute = normalized % 60;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:${minute.toString().padLeft(2, '0')}';
}

/// Computed state for the Day Arc widget at [referenceDate].
@immutable
class DayArcSummary {
  final DateTime referenceDate;
  final int nowMinutes; // 0..1439
  final List<DayArcBand> bands;
  final List<DayArcHabitDot> habitDots;
  final DayArcBand? currentOrNextBand;

  const DayArcSummary({
    required this.referenceDate,
    required this.nowMinutes,
    required this.bands,
    required this.habitDots,
    required this.currentOrNextBand,
  });

  bool get isEmptyDay => bands.isEmpty && habitDots.isEmpty;

  String? get centerTimeLabel => currentOrNextBand != null
      ? formatDayArcTime(currentOrNextBand!.startMinutes)
      : null;

  String get centerTitle =>
      currentOrNextBand?.title ?? 'Nothing booked today';

  /// Returns a copy recomputed for [newReferenceDate] (used by the 30-minute
  /// background refresh so the `now` hairline and current/next centre readout
  /// advance without touching the database).
  DayArcSummary atTime(DateTime newReferenceDate) {
    final sameDay = CalendarDateUtils.isSameDay(
      referenceDate,
      newReferenceDate,
    );
    final updatedNowMinutes =
        (newReferenceDate.hour * 60 + newReferenceDate.minute).clamp(0, 1439);
    if (!sameDay) {
      return DayArcSummary(
        referenceDate: newReferenceDate,
        nowMinutes: updatedNowMinutes,
        bands: const [],
        habitDots: const [],
        currentOrNextBand: null,
      );
    }
    return DayArcSummary(
      referenceDate: newReferenceDate,
      nowMinutes: updatedNowMinutes,
      bands: bands,
      habitDots: habitDots,
      currentOrNextBand: selectCurrentOrNextBand(bands, updatedNowMinutes),
    );
  }

  /// Selects the current band spanning [nowMinutes], or the next upcoming band
  /// starting at or after [nowMinutes].
  static DayArcBand? selectCurrentOrNextBand(
    List<DayArcBand> bands,
    int nowMinutes,
  ) {
    if (bands.isEmpty) return null;
    final sorted = List<DayArcBand>.from(bands)
      ..sort((a, b) {
        final cmp = a.startMinutes.compareTo(b.startMinutes);
        if (cmp != 0) return cmp;
        if (a.isEvent != b.isEvent) return a.isEvent ? -1 : 1;
        return a.endMinutes.compareTo(b.endMinutes);
      });

    // 1. Current item spanning `nowMinutes` (prefer events or latest start).
    DayArcBand? currentMatch;
    for (final band in sorted) {
      if (band.containsMinute(nowMinutes)) {
        if (currentMatch == null ||
            (band.isEvent && !currentMatch.isEvent) ||
            band.startMinutes >= currentMatch.startMinutes) {
          currentMatch = band;
        }
      }
    }
    if (currentMatch != null) return currentMatch;

    // 2. Next upcoming item today (`startMinutes >= nowMinutes`).
    for (final band in sorted) {
      if (band.startMinutes >= nowMinutes) {
        return band;
      }
    }

    return null;
  }

  factory DayArcSummary.compute({
    required DateTime referenceDate,
    required List<LocalCalendarEvent> events,
    required List<Routine> routines,
    required List<RoutineEvent> routineEvents,
    required List<LocalHabit> habits,
    required List<LocalHabitCheckin> checkins,
    String currentUserId = '',
    String partnerName = '',
  }) {
    final today = CalendarDateUtils.dateOnly(referenceDate);
    final todayString = DateFormat('yyyy-MM-dd').format(today);
    final nowMinutes =
        (referenceDate.hour * 60 + referenceDate.minute).clamp(0, 1439);

    final bands = <DayArcBand>[];

    // 1. Today's routine bands.
    final projectedRoutines = CalendarDateUtils.projectRoutines(
      routines: routines,
      routineEvents: routineEvents,
      startDate: today,
      endDate: today,
    );
    for (final entry in projectedRoutines) {
      final ev = entry.routineEvent;
      final isFaint = _isFaintRoutine(
        routine: entry.routine,
        event: ev,
        partnerName: partnerName,
      );
      bands.add(
        DayArcBand(
          id: entry.id,
          title: ev.title,
          startMinutes: ev.startMinutes.clamp(0, 1439),
          endMinutes: ev.endMinutes.clamp(0, 1440),
          strength: isFaint ? DayArcStrength.faint : DayArcStrength.solid,
          isEvent: false,
        ),
      );
    }

    // 2. Today's calendar events.
    final projectedEvents = CalendarDateUtils.projectCalendarEvents(
      events: events,
      startDate: today,
      endDate: today,
    );
    for (final entry in projectedEvents) {
      final ev = entry.event;
      if (ev.isAllDay) continue;
      final startMin =
          (entry.startTime.hour * 60 + entry.startTime.minute).clamp(0, 1439);
      final rawEndMin = entry.endTime.hour * 60 + entry.endTime.minute;
      final endMin = CalendarDateUtils.isSameDay(entry.startTime, entry.endTime)
          ? math.max(startMin + 15, rawEndMin).clamp(0, 1440)
          : 1440;
      final isFaint = _isFaintEvent(
        event: ev,
        currentUserId: currentUserId,
        partnerName: partnerName,
      );
      bands.add(
        DayArcBand(
          id: entry.id,
          title: ev.title,
          startMinutes: startMin,
          endMinutes: endMin,
          strength: isFaint ? DayArcStrength.faint : DayArcStrength.solid,
          isEvent: true,
        ),
      );
    }

    bands.sort((a, b) {
      final cmp = a.startMinutes.compareTo(b.startMinutes);
      if (cmp != 0) return cmp;
      if (a.isEvent != b.isEvent) return a.isEvent ? -1 : 1;
      return a.title.compareTo(b.title);
    });

    // 3. Today's habit dots on the outer rim.
    final habitDots = <DayArcHabitDot>[];
    var untimedCount = 0;
    for (final h in habits) {
      if (h.isArchived) continue;
      final isPrivate = h.targetDaysPerWeek < 0;
      // Privacy rule: never show another person's private records.
      if (isPrivate &&
          currentUserId.isNotEmpty &&
          h.createdBy.isNotEmpty &&
          h.createdBy != currentUserId) {
        continue;
      }

      final sched = HabitSchedule.parse(
        h.cadence,
        targetDays: h.targetDaysPerWeek,
      );
      if (!sched.isDueOn(today)) continue;

      final int minutes;
      if (sched.timeOfDay != null) {
        minutes = (sched.timeOfDay!.hour * 60 + sched.timeOfDay!.minute)
            .clamp(0, 1439);
      } else {
        minutes = (8 * 60 + untimedCount * 60).clamp(0, 1439);
        untimedCount++;
      }

      final isKept = checkins.any((c) {
        if (c.habitId != h.id || c.checkinDate != todayString) return false;
        if (currentUserId.isEmpty) return true;
        if (h.createdBy == currentUserId) {
          return c.memberId == currentUserId;
        }
        return c.memberId == h.createdBy || c.memberId == currentUserId;
      });

      habitDots.add(
        DayArcHabitDot(
          habitId: h.id,
          title: h.name,
          minutes: minutes,
          isKept: isKept,
        ),
      );
    }

    habitDots.sort((a, b) => a.minutes.compareTo(b.minutes));

    return DayArcSummary(
      referenceDate: referenceDate,
      nowMinutes: nowMinutes,
      bands: bands,
      habitDots: habitDots,
      currentOrNextBand: selectCurrentOrNextBand(bands, nowMinutes),
    );
  }

  static bool _isFaintRoutine({
    required Routine routine,
    required RoutineEvent event,
    required String partnerName,
  }) {
    final combined = [
      routine.name,
      event.category ?? '',
      event.notes ?? '',
    ].join(' ').toLowerCase();
    if (combined.contains('tentative') ||
        combined.contains('solo') ||
        combined.contains('partner')) {
      return true;
    }
    final cleanPartner = partnerName.trim().toLowerCase();
    if (cleanPartner.isNotEmpty &&
        cleanPartner != 'partner' &&
        combined.contains(cleanPartner)) {
      return true;
    }
    return false;
  }

  static bool _isFaintEvent({
    required LocalCalendarEvent event,
    required String currentUserId,
    required String partnerName,
  }) {
    final desc = (event.description ?? '').toLowerCase();
    final title = event.title.toLowerCase();
    if (desc.contains('tentative') ||
        desc.contains('solo') ||
        desc.contains('maybe') ||
        title.contains('tentative') ||
        title.endsWith('?')) {
      return true;
    }
    final cleanPartner = partnerName.trim().toLowerCase();
    if (cleanPartner.isNotEmpty &&
        cleanPartner != 'partner' &&
        desc.contains(cleanPartner) &&
        !desc.contains('both') &&
        !desc.contains('shared')) {
      return true;
    }
    if (currentUserId.isNotEmpty &&
        event.createdBy.isNotEmpty &&
        event.createdBy != 'local_user' &&
        event.createdBy != currentUserId &&
        !desc.contains('both') &&
        !desc.contains('shared')) {
      return true;
    }
    return false;
  }
}

/// Optional override for the Day Arc reference date/time (defaults to `null`,
/// which uses `clock.now()`).
final dayArcReferenceDateProvider = Provider<DateTime?>((ref) => null);

/// Provider computing [DayArcSummary] from the active home's routines, calendar
/// events, and habits.
final dayArcSummaryProvider = Provider<DayArcSummary>((ref) {
  final referenceDate = ref.watch(dayArcReferenceDateProvider) ?? clock.now();
  final events =
      ref.watch(activeHomeCalendarEventsProvider).value ?? const [];
  final routines = ref.watch(activeHomeRoutinesProvider).value ?? const [];
  final routineEvents =
      ref.watch(activeHomeAllRoutineEventsProvider).value ?? const [];
  final habits = ref.watch(activeHomeHabitsProvider).value ?? const [];
  final checkins =
      ref.watch(activeHomeAllHabitCheckinsProvider).value ?? const [];
  final currentUserId = ref.watch(authProvider).value?.id ?? '';
  final partnerName = ref.watch(partnerProfileProvider).displayName;

  return DayArcSummary.compute(
    referenceDate: referenceDate,
    events: events,
    routines: routines,
    routineEvents: routineEvents,
    habits: habits,
    checkins: checkins,
    currentUserId: currentUserId,
    partnerName: partnerName,
  );
});

/// Home-screen Day Arc widget (`2×2`, read-only) per `design/specs/18-widgets.md` §1
/// and `design/screens/widgets/arc-{dark,light}.png`.
class CoveDayArcWidget extends ConsumerWidget {
  final VoidCallback? onTap;

  const CoveDayArcWidget({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dayArcSummaryProvider);
    return CoveDayArcCard(
      summary: summary,
      onTap: onTap,
    );
  }
}

/// Pure presentation card for The Day Arc (`design/specs/18-widgets.md` §1).
///
/// Follows the ambient [Theme] (system dark / light mode on the home screen).
/// Tapping anywhere on the card opens `Calendar · Day`.
class CoveDayArcCard extends StatelessWidget {
  static const double _kCardFillOpacity = 0.88; // (literal) ~88% card fill over wallpaper
  static const double _kHairlineWidth = 1.0; // (literal) 1dp card border
  static const double _kCenterContentPadding = 36.0; // (literal) inset inside the 24h ring

  final DayArcSummary summary;
  final VoidCallback? onTap;

  const CoveDayArcCard({
    super.key,
    required this.summary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final timeLabel = summary.centerTimeLabel;

    return DefaultTextStyle.merge(
      style: const TextStyle(decoration: TextDecoration.none),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width =
                constraints.maxWidth.isFinite ? constraints.maxWidth : 176.0;
            final height =
                constraints.maxHeight.isFinite ? constraints.maxHeight : 176.0;
            final shortest = math.min(width, height);
            final horizontalPad = math.max(
              CoveSpace.md,
              (width - shortest) / 2 +
                  (_kCenterContentPadding * (shortest / 176.0)),
            );
            final verticalPad = math.max(
              CoveSpace.sm,
              (height - shortest) / 2 +
                  (_kCenterContentPadding * (shortest / 176.0)),
            );

            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: CoveShape.decoration(
                CoveRadius.hero,
                color: cv.surfaceCard.withValues(alpha: _kCardFillOpacity),
                side: BorderSide(
                  color: cv.lineStrong,
                  width: _kHairlineWidth,
                ),
              ),
              child: CustomPaint(
                painter: _DayArcRingPainter(
                  cv: cv,
                  summary: summary,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPad,
                    vertical: verticalPad,
                  ),
                  child: Center(
                    child: timeLabel != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: CoveType.slipTitle.copyWith(
                                  color: cv.textPrimary,
                                ),
                              ),
                              if (shortest >= 110.0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  summary.centerTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: CoveType.rowSub.copyWith(
                                    color: cv.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Text(
                            summary.centerTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: CoveType.rowSub.copyWith(
                              color: cv.textSecondary,
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DayArcRingPainter extends CustomPainter {
  static const double _kReferenceSide = 176.0;
  static const double _kBaseRingRadius = 56.0;
  static const double _kBaseTrackStrokeWidth = 9.5;
  static const double _kBaseHabitOrbitOffset = 9.0;
  static const double _kBaseHabitDotRadius = 2.6;
  static const double _kBaseHabitOutlineStroke = 1.25;
  static const double _kBaseHairlineHalfLength = 9.5;
  static const double _kBaseHairlineStrokeWidth = 2.0;
  static const double _kFaintArcAlpha = 0.45;
  static const double _kOutlinedDotAlpha = 0.65;

  final CoveTokens cv;
  final DayArcSummary summary;

  const _DayArcRingPainter({
    required this.cv,
    required this.summary,
  });

  static double _angleForMinutes(num minutes) {
    final normalized = (minutes.toDouble() % 1440.0) / 1440.0;
    return -math.pi / 2 + normalized * 2 * math.pi;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    if (shortest <= 0) return;

    final scale = shortest / _kReferenceSide;
    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = _kBaseRingRadius * scale;
    final trackStrokeWidth = _kBaseTrackStrokeWidth * scale;
    final ringRect = Rect.fromCircle(center: center, radius: ringRadius);

    // 1. 24-hour base track.
    final trackPaint = Paint()
      ..color = cv.accentWash
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackStrokeWidth
      ..isAntiAlias = true;
    canvas.drawCircle(center, ringRadius, trackPaint);

    // 2. Routine bands and events in gold at two strengths:
    //    - booked solid (`cv.accentFill`)
    //    - tentative or solo-partner fainter (`cv.accentFill` at 45% alpha)
    //    Draw faint arcs first so solid arcs sit cleanly on top if overlapping.
    for (final targetStrength in const [
      DayArcStrength.faint,
      DayArcStrength.solid,
    ]) {
      final arcColor = targetStrength == DayArcStrength.solid
          ? cv.accentFill
          : cv.accentFill.withValues(alpha: _kFaintArcAlpha);
      final arcPaint = Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackStrokeWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      for (final band in summary.bands) {
        if (band.strength != targetStrength) continue;
        final startAngle = _angleForMinutes(band.startMinutes);
        final clampedMinutes = band.durationMinutes.clamp(15, 1440);
        final sweepAngle = (clampedMinutes / 1440.0) * 2 * math.pi;
        canvas.drawArc(ringRect, startAngle, sweepAngle, false, arcPaint);
      }
    }

    // 3. Habit dots on the outer rim at their scheduled times:
    //    filled when kept, outlined when not.
    final dotOrbitRadius =
        ringRadius + (trackStrokeWidth / 2) + (_kBaseHabitOrbitOffset * scale);
    final dotRadius = _kBaseHabitDotRadius * scale;
    final filledDotPaint = Paint()
      ..color = cv.accentFill
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final outlinedDotPaint = Paint()
      ..color = cv.accentFill.withValues(alpha: _kOutlinedDotAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kBaseHabitOutlineStroke * scale
      ..isAntiAlias = true;

    for (final dot in summary.habitDots) {
      final angle = _angleForMinutes(dot.minutes);
      final dotCenter = Offset(
        center.dx + dotOrbitRadius * math.cos(angle),
        center.dy + dotOrbitRadius * math.sin(angle),
      );
      if (dot.isKept) {
        canvas.drawCircle(dotCenter, dotRadius, filledDotPaint);
      } else {
        canvas.drawCircle(dotCenter, dotRadius, outlinedDotPaint);
      }
    }

    // 4. The "now" hairline.
    final nowAngle = _angleForMinutes(summary.nowMinutes);
    final hairlineHalf = _kBaseHairlineHalfLength * scale;
    final innerPoint = Offset(
      center.dx + (ringRadius - hairlineHalf) * math.cos(nowAngle),
      center.dy + (ringRadius - hairlineHalf) * math.sin(nowAngle),
    );
    final outerPoint = Offset(
      center.dx + (ringRadius + hairlineHalf) * math.cos(nowAngle),
      center.dy + (ringRadius + hairlineHalf) * math.sin(nowAngle),
    );
    final hairlinePaint = Paint()
      ..color = cv.accentFill
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kBaseHairlineStrokeWidth * scale
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawLine(innerPoint, outerPoint, hairlinePaint);
  }

  @override
  bool shouldRepaint(covariant _DayArcRingPainter oldDelegate) {
    return oldDelegate.cv != cv ||
        oldDelegate.summary.nowMinutes != summary.nowMinutes ||
        oldDelegate.summary.bands != summary.bands ||
        oldDelegate.summary.habitDots != summary.habitDots;
  }
}
