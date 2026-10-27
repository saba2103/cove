import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/theme/cove_theme.dart';
import '../../sync/db/app_database.dart';
import '../../sync/pending_delete_service.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../backup/backup_scheduler.dart';
import '../expenses/expense_controller.dart';
import '../profile/preferences_controller.dart';
import '../subscriptions/subscription_controller.dart';
import '../weather/weather_controller.dart';
import 'cove_day_arc_widget.dart';
import 'cove_day_sheet_widget.dart';
import 'cove_ledger_widget.dart';
import 'cove_slip_widget.dart';
import 'cove_widget_tick_service.dart';

/// Metadata for each of the four Android home-screen widgets (`design/specs/18-widgets.md`).
@immutable
class CoveWidgetProviderInfo {
  final String id;
  final String androidName;
  final String qualifiedAndroidName;
  final int targetCellWidth;
  final int targetCellHeight;
  final Size minSizeDp;
  final Size minResizeSizeDp;
  final Size renderLogicalSize;

  const CoveWidgetProviderInfo({
    required this.id,
    required this.androidName,
    required this.qualifiedAndroidName,
    required this.targetCellWidth,
    required this.targetCellHeight,
    required this.minSizeDp,
    required this.minResizeSizeDp,
    required this.renderLogicalSize,
  });

  static const dayArc = CoveWidgetProviderInfo(
    id: 'arc',
    androidName: 'widgets.CoveDayArcWidgetProvider',
    qualifiedAndroidName: 'com.app.cove.widgets.CoveDayArcWidgetProvider',
    targetCellWidth: 2,
    targetCellHeight: 2,
    minSizeDp: Size(110, 110),
    minResizeSizeDp: Size(110, 85),
    renderLogicalSize: Size(176, 176),
  );

  static const slip = CoveWidgetProviderInfo(
    id: 'slip',
    androidName: 'widgets.CoveSlipWidgetProvider',
    qualifiedAndroidName: 'com.app.cove.widgets.CoveSlipWidgetProvider',
    targetCellWidth: 4,
    targetCellHeight: 2,
    minSizeDp: Size(260, 110),
    minResizeSizeDp: Size(145, 85),
    renderLogicalSize: Size(360, 176),
  );

  static const ledger = CoveWidgetProviderInfo(
    id: 'ledger',
    androidName: 'widgets.CoveLedgerWidgetProvider',
    qualifiedAndroidName: 'com.app.cove.widgets.CoveLedgerWidgetProvider',
    targetCellWidth: 4,
    targetCellHeight: 2,
    minSizeDp: Size(260, 110),
    minResizeSizeDp: Size(145, 85),
    renderLogicalSize: Size(360, 176),
  );

  static const daySheet = CoveWidgetProviderInfo(
    id: 'sheet',
    androidName: 'widgets.CoveDaySheetWidgetProvider',
    qualifiedAndroidName: 'com.app.cove.widgets.CoveDaySheetWidgetProvider',
    targetCellWidth: 4,
    targetCellHeight: 4,
    minSizeDp: Size(260, 360),
    minResizeSizeDp: Size(145, 180),
    renderLogicalSize: Size(360, 360),
  );

  static const List<CoveWidgetProviderInfo> all = [
    dayArc,
    slip,
    ledger,
    daySheet,
  ];
}

/// Abstract bridge over `home_widget` so widget bitmap rendering, storage, and
/// provider updates can be verified deterministically in tests.
abstract class CoveWidgetPlatformBridge {
  bool get isSupported;

  Future<String> renderFlutterWidget(
    Widget widget, {
    required String key,
    required Size logicalSize,
    double? pixelRatio,
  });

  Future<bool?> saveWidgetData<T>(String id, T? data);

  Future<bool?> updateWidget({
    required String androidName,
    required String qualifiedAndroidName,
  });

  Future<Uri?> initiallyLaunchedFromHomeWidget();

  Stream<Uri?> get widgetClicked;
}

class HomeWidgetPlatformBridge implements CoveWidgetPlatformBridge {
  const HomeWidgetPlatformBridge();

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<String> renderFlutterWidget(
    Widget widget, {
    required String key,
    required Size logicalSize,
    double? pixelRatio,
  }) {
    return HomeWidget.renderFlutterWidget(
      widget,
      key: key,
      logicalSize: logicalSize,
      pixelRatio: pixelRatio,
    );
  }

  @override
  Future<bool?> saveWidgetData<T>(String id, T? data) {
    return HomeWidget.saveWidgetData<T>(id, data);
  }

  @override
  Future<bool?> updateWidget({
    required String androidName,
    required String qualifiedAndroidName,
  }) {
    return HomeWidget.updateWidget(
      name: androidName,
      androidName: androidName,
      qualifiedAndroidName: qualifiedAndroidName,
    );
  }

  @override
  Future<Uri?> initiallyLaunchedFromHomeWidget() async {
    if (!isSupported) return null;
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<Uri?> get widgetClicked {
    if (!isSupported) return const Stream<Uri?>.empty();
    return HomeWidget.widgetClicked;
  }
}

/// Schedules the 30-minute periodic WorkManager refresh for home-screen widgets
/// (`design/specs/18-widgets.md` § Rendering).
abstract class WidgetRefreshScheduler {
  bool get isSupported;
  Future<void> initialize();
  Future<void> schedulePeriodicRefresh();
  Future<void> cancel();
}

class WorkmanagerWidgetRefreshScheduler implements WidgetRefreshScheduler {
  static const String uniqueName = 'cove-widget-refresh';
  static const String taskName = 'coveWidgetRefresh';
  static const Duration refreshFrequency = Duration(minutes: 30);
  static const Duration minBackgroundInterval = Duration(minutes: 15);
  static const String lastBackgroundRefreshEpochMsKey =
      'cove_widget_last_bg_refresh_ms';

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> initialize() async {
    if (!isSupported) return;
    await WorkmanagerBackupScheduler.ensureWorkmanagerInitialized();
  }

  @override
  Future<void> schedulePeriodicRefresh() async {
    if (!isSupported) return;
    await initialize();
    await Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: refreshFrequency,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  @override
  Future<void> cancel() async {
    if (!isSupported) return;
    await initialize();
    await Workmanager().cancelByUniqueName(uniqueName);
  }
}

/// Service that renders Cove's Flutter widget bitmaps and pushes updates to
/// Android's `AppWidgetManager`.
class CoveWidgetService {
  static const String arcDarkKey = 'cove_widget_arc_dark';
  static const String arcLightKey = 'cove_widget_arc_light';
  static const String cachedArcSnapshotPrefKey =
      'cove_widget_arc_snapshot_v1';
  static const Size arcLogicalSize = Size(176, 176);

  static const String slipDarkKey = 'cove_widget_slip_dark';
  static const String slipLightKey = 'cove_widget_slip_light';
  static const String slipCompactDarkKey = 'cove_widget_slip_compact_dark';
  static const String slipCompactLightKey = 'cove_widget_slip_compact_light';
  static const String slipListIdKey = 'cove_widget_slip_list_id';
  static const String slipRow0IdKey = 'cove_widget_slip_row_0_id';
  static const String slipRow1IdKey = 'cove_widget_slip_row_1_id';
  static const String slipRow2IdKey = 'cove_widget_slip_row_2_id';
  static const String slipListsJsonKey = 'cove_widget_slip_lists_json';
  static const String cachedSlipSnapshotPrefKey =
      'cove_widget_slip_snapshot_v1';
  static const Size slipFullLogicalSize = Size(379, 176);
  static const Size slipCompactLogicalSize = Size(200, 176);

  static const String ledgerDarkKey = 'cove_widget_ledger_dark';
  static const String ledgerLightKey = 'cove_widget_ledger_light';
  static const String ledgerCompactDarkKey = 'cove_widget_ledger_compact_dark';
  static const String ledgerCompactLightKey =
      'cove_widget_ledger_compact_light';
  static const String ledgerNextCommitmentIdKey =
      'cove_widget_ledger_next_commitment_id';
  static const String cachedLedgerSnapshotPrefKey =
      'cove_widget_ledger_snapshot_v1';

  static const Size ledgerFullLogicalSize = Size(379, 176);
  static const Size ledgerCompactLogicalSize = Size(200, 176);

  static const String sheetDarkKey = 'cove_widget_sheet_dark';
  static const String sheetLightKey = 'cove_widget_sheet_light';
  static const String sheetCheckinDateKey = 'cove_widget_sheet_checkin_date';
  static const String cachedSheetSnapshotPrefKey =
      'cove_widget_sheet_snapshot_v1';
  static const Size sheetLogicalSize = Size(360, 360);

  final CoveWidgetPlatformBridge bridge;
  final WidgetRefreshScheduler scheduler;

  String? _lastRenderedSignature;
  int _renderGeneration = 0;
  String? _lastRenderedArcSignature;
  int _arcRenderGeneration = 0;
  String? _lastRenderedSlipSignature;
  int _slipRenderGeneration = 0;
  String? _lastRenderedSheetSignature;
  int _sheetRenderGeneration = 0;

  CoveWidgetService({
    this.bridge = const HomeWidgetPlatformBridge(),
    WidgetRefreshScheduler? scheduler,
  }) : scheduler = scheduler ?? WorkmanagerWidgetRefreshScheduler();

  /// Registers the background interactivity callback with `HomeWidget` on
  /// Android so home-screen widget row taps invoke [coveWidgetBackgroundCallback].
  Future<bool?> registerInteractivityCallback() async {
    if (!bridge.isSupported) return false;
    try {
      return await HomeWidget.registerInteractivityCallback(
        coveWidgetBackgroundCallback,
      );
    } catch (_) {
      return false;
    }
  }

  /// Renders The Slip widget (dark + light, 4×2 + 3×2 compact) into PNG
  /// bitmaps via [bridge], saves interactive row hit metadata, and triggers an
  /// `AppWidgetManager` update (`design/specs/18-widgets.md` §2).
  Future<void> renderAndPushSlip({
    required SlipSummary summary,
    bool force = false,
  }) async {
    final signature = [
      summary.listId ?? '',
      summary.listName,
      summary.openCount,
      summary.openItems
          .map(
            (r) =>
                '${r.id}:${r.title}:${r.person.name}:${r.actorInitial}:${r.isTicked ? 1 : 0}',
          )
          .join(','),
      summary.availableLists
          .map(
            (o) =>
                '${o.id}:${o.name}:${o.openCount}:${o.totalCount}:${o.isMostUsed ? 1 : 0}',
          )
          .join(','),
    ].join('|');

    if (!force && _lastRenderedSlipSignature == signature) {
      return;
    }
    _lastRenderedSlipSignature = signature;
    final generation = ++_slipRenderGeneration;

    await _saveSlipSnapshotToPrefs(summary);
    if (generation != _slipRenderGeneration) return;

    if (!bridge.isSupported) return;

    try {
      final rowsFull = summary.visibleRowsFor(isCompact3Cell: false);
      await bridge.saveWidgetData<String>(slipListIdKey, summary.listId);
      await bridge.saveWidgetData<String>(
        slipRow0IdKey,
        rowsFull.isNotEmpty ? rowsFull[0].id : null,
      );
      await bridge.saveWidgetData<String>(
        slipRow1IdKey,
        rowsFull.length > 1 ? rowsFull[1].id : null,
      );
      await bridge.saveWidgetData<String>(
        slipRow2IdKey,
        rowsFull.length > 2 ? rowsFull[2].id : null,
      );
      await bridge.saveWidgetData<String>(
        slipListsJsonKey,
        jsonEncode(summary.availableLists.map((o) => o.toJson()).toList()),
      );
      if (generation != _slipRenderGeneration) return;

      final darkFull = _wrapForOffscreenRender(
        theme: CoveTheme.darkTheme,
        size: slipFullLogicalSize,
        child: CoveSlipCard(summary: summary),
      );
      final lightFull = _wrapForOffscreenRender(
        theme: CoveTheme.lightTheme,
        size: slipFullLogicalSize,
        child: CoveSlipCard(summary: summary),
      );
      final darkCompact = _wrapForOffscreenRender(
        theme: CoveTheme.darkTheme,
        size: slipCompactLogicalSize,
        child: CoveSlipCard(summary: summary),
      );
      final lightCompact = _wrapForOffscreenRender(
        theme: CoveTheme.lightTheme,
        size: slipCompactLogicalSize,
        child: CoveSlipCard(summary: summary),
      );

      await bridge.renderFlutterWidget(
        darkFull,
        key: slipDarkKey,
        logicalSize: slipFullLogicalSize,
      );
      if (generation != _slipRenderGeneration) return;
      await bridge.renderFlutterWidget(
        lightFull,
        key: slipLightKey,
        logicalSize: slipFullLogicalSize,
      );
      if (generation != _slipRenderGeneration) return;
      await bridge.renderFlutterWidget(
        darkCompact,
        key: slipCompactDarkKey,
        logicalSize: slipCompactLogicalSize,
      );
      if (generation != _slipRenderGeneration) return;
      await bridge.renderFlutterWidget(
        lightCompact,
        key: slipCompactLightKey,
        logicalSize: slipCompactLogicalSize,
      );
      if (generation != _slipRenderGeneration) return;

      await _renderActiveExactSizesForKind(
        kind: 'slip',
        childBuilder: () => CoveSlipCard(summary: summary),
      );
      if (generation != _slipRenderGeneration) return;

      await bridge.updateWidget(
        androidName: CoveWidgetProviderInfo.slip.androidName,
        qualifiedAndroidName: CoveWidgetProviderInfo.slip.qualifiedAndroidName,
      );
    } catch (e) {
      debugPrint('[CoveWidgetService] Failed to render Slip widget: $e');
    }
  }

  /// Immediately re-renders the cached Slip snapshot with [recordId] ticked
  /// (`design/specs/18-widgets.md` § Ticking rule 1: "The widget re-renders
  /// straight away with the tick shown.").
  Future<SlipSummary?> renderOptimisticSlipTick(
    String recordId, {
    bool toDone = true,
    SharedPreferences? prefsOverride,
  }) async {
    try {
      final prefs = prefsOverride ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(cachedSlipSnapshotPrefKey);
      if (raw == null || raw.isEmpty) return null;
      final current = SlipSummary.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      final updated = current.withOptimisticTick(recordId, toDone: toDone);
      await renderAndPushSlip(summary: updated, force: true);
      return updated;
    } catch (_) {
      return null;
    }
  }

  /// Renders the Day Arc widget (2×2, dark + light) into PNG bitmaps via
  /// [bridge] and triggers an `AppWidgetManager` update.
  Future<void> renderAndPushDayArc({
    required DayArcSummary summary,
    bool force = false,
  }) async {
    final signature = [
      DateFormat('yyyy-MM-dd').format(summary.referenceDate),
      summary.nowMinutes,
      summary.centerTimeLabel ?? '',
      summary.centerTitle,
      summary.bands
          .map(
            (b) =>
                '${b.id}:${b.title}:${b.startMinutes}-${b.endMinutes}:${b.strength.name}',
          )
          .join(','),
      summary.habitDots
          .map((d) => '${d.habitId}:${d.minutes}:${d.isKept ? 1 : 0}')
          .join(','),
    ].join('|');

    if (!force && _lastRenderedArcSignature == signature) {
      return;
    }
    _lastRenderedArcSignature = signature;
    final generation = ++_arcRenderGeneration;

    await _saveArcSnapshotToPrefs(summary);
    if (generation != _arcRenderGeneration) return;

    if (!bridge.isSupported) return;

    try {
      final darkArc = _wrapForOffscreenRender(
        theme: CoveTheme.darkTheme,
        size: arcLogicalSize,
        child: CoveDayArcCard(summary: summary),
      );
      final lightArc = _wrapForOffscreenRender(
        theme: CoveTheme.lightTheme,
        size: arcLogicalSize,
        child: CoveDayArcCard(summary: summary),
      );

      await bridge.renderFlutterWidget(
        darkArc,
        key: arcDarkKey,
        logicalSize: arcLogicalSize,
      );
      if (generation != _arcRenderGeneration) return;
      await bridge.renderFlutterWidget(
        lightArc,
        key: arcLightKey,
        logicalSize: arcLogicalSize,
      );
      if (generation != _arcRenderGeneration) return;

      await _renderActiveExactSizesForKind(
        kind: 'arc',
        childBuilder: () => CoveDayArcCard(summary: summary),
      );
      if (generation != _arcRenderGeneration) return;

      await bridge.updateWidget(
        androidName: CoveWidgetProviderInfo.dayArc.androidName,
        qualifiedAndroidName:
            CoveWidgetProviderInfo.dayArc.qualifiedAndroidName,
      );
    } catch (e) {
      debugPrint('[CoveWidgetService] Failed to render Day Arc widget: $e');
    }
  }

  /// Renders the Ledger widget (dark + light, 4×2 + 3×2 compact) into PNG
  /// bitmaps via [bridge] and triggers an `AppWidgetManager` update.
  Future<void> renderAndPushLedger({
    required ExpensesStandingSummary expenses,
    required CommitmentsSummary commitments,
    bool force = false,
  }) async {
    final next = commitments.nextSharedCommitment;
    final signature = [
      expenses.standingMonthName,
      expenses.standingDay,
      expenses.daysRemaining,
      expenses.sharedMonthlyTotal.toStringAsFixed(2),
      expenses.paidByMeSharedTotal.toStringAsFixed(2),
      expenses.paidByPartnerSharedTotal.toStringAsFixed(2),
      expenses.prevMonthName,
      expenses.prevMonthByThisDay.toStringAsFixed(2),
      expenses.hasPrevComparison,
      expenses.partnerName,
      expenses.currency.code,
      next?.id ?? '',
      next?.name ?? '',
      next?.amount.toStringAsFixed(2) ?? '',
      commitments.nextSharedCommitmentWhen ?? '',
    ].join('|');

    if (!force && _lastRenderedSignature == signature) {
      return;
    }
    _lastRenderedSignature = signature;
    final generation = ++_renderGeneration;

    await _saveSnapshotToPrefs(expenses: expenses, commitments: commitments);
    if (generation != _renderGeneration) return;

    if (!bridge.isSupported) return;

    try {
      await bridge.saveWidgetData<String>(
        ledgerNextCommitmentIdKey,
        next?.id,
      );
      if (generation != _renderGeneration) return;

      final darkFull = _wrapForOffscreenRender(
        theme: CoveTheme.darkTheme,
        size: ledgerFullLogicalSize,
        child: CoveLedgerCard(expenses: expenses, commitments: commitments),
      );
      final lightFull = _wrapForOffscreenRender(
        theme: CoveTheme.lightTheme,
        size: ledgerFullLogicalSize,
        child: CoveLedgerCard(expenses: expenses, commitments: commitments),
      );
      final darkCompact = _wrapForOffscreenRender(
        theme: CoveTheme.darkTheme,
        size: ledgerCompactLogicalSize,
        child: CoveLedgerCard(expenses: expenses, commitments: commitments),
      );
      final lightCompact = _wrapForOffscreenRender(
        theme: CoveTheme.lightTheme,
        size: ledgerCompactLogicalSize,
        child: CoveLedgerCard(expenses: expenses, commitments: commitments),
      );

      await bridge.renderFlutterWidget(
        darkFull,
        key: ledgerDarkKey,
        logicalSize: ledgerFullLogicalSize,
      );
      if (generation != _renderGeneration) return;
      await bridge.renderFlutterWidget(
        lightFull,
        key: ledgerLightKey,
        logicalSize: ledgerFullLogicalSize,
      );
      if (generation != _renderGeneration) return;
      await bridge.renderFlutterWidget(
        darkCompact,
        key: ledgerCompactDarkKey,
        logicalSize: ledgerCompactLogicalSize,
      );
      if (generation != _renderGeneration) return;
      await bridge.renderFlutterWidget(
        lightCompact,
        key: ledgerCompactLightKey,
        logicalSize: ledgerCompactLogicalSize,
      );
      if (generation != _renderGeneration) return;

      await _renderActiveExactSizesForKind(
        kind: 'ledger',
        childBuilder: () =>
            CoveLedgerCard(expenses: expenses, commitments: commitments),
      );
      if (generation != _renderGeneration) return;

      await bridge.updateWidget(
        androidName: CoveWidgetProviderInfo.ledger.androidName,
        qualifiedAndroidName:
            CoveWidgetProviderInfo.ledger.qualifiedAndroidName,
      );
    } catch (e) {
      debugPrint('[CoveWidgetService] Failed to render Ledger widget: $e');
    }
  }

  /// Renders the Day Sheet widget (4×4, dark + light) into PNG bitmaps via
  /// [bridge], saves interactive line and habit dot hit metadata, and triggers
  /// an `AppWidgetManager` update (`design/specs/18-widgets.md` §4).
  Future<void> renderAndPushDaySheet({
    required DaySheetSummary summary,
    bool force = false,
  }) async {
    final signature = [
      summary.checkinDateStr,
      summary.nowMinutes,
      summary.dayNumber,
      summary.monthName,
      summary.weekdayCaps,
      summary.weatherLine ?? '',
      summary.firstHabitDueToday ?? '',
      summary.todaySpend.toStringAsFixed(2),
      summary.currency.code,
      summary.lines
          .map(
            (l) =>
                '${l.id}:${l.kind.wireValue}:${l.timeLabel}:${l.title}:${l.subtitle}:${l.isOver ? 1 : 0}:${l.isCompleted ? 1 : 0}',
          )
          .join(','),
      summary.habitDots
          .map(
            (d) =>
                '${d.habitId}:${d.habitName}:${d.isKeptToday ? 1 : 0}:${d.isOwnedByViewer ? 1 : 0}',
          )
          .join(','),
    ].join('|');

    if (!force && _lastRenderedSheetSignature == signature) {
      return;
    }
    _lastRenderedSheetSignature = signature;
    final generation = ++_sheetRenderGeneration;

    await _saveSheetSnapshotToPrefs(summary);
    if (generation != _sheetRenderGeneration) return;

    if (!bridge.isSupported) return;

    try {
      final visibleLines = summary.visibleLines;
      final visibleDots = summary.visibleHabitDots;

      await bridge.saveWidgetData<String>(
        sheetCheckinDateKey,
        summary.checkinDateStr,
      );

      for (var i = 0; i < DaySheetSummary.maxVisibleLines; i++) {
        final line = i < visibleLines.length ? visibleLines[i] : null;
        await bridge.saveWidgetData<String>(
          'cove_widget_sheet_row_${i}_id',
          line?.id,
        );
        await bridge.saveWidgetData<String>(
          'cove_widget_sheet_row_${i}_kind',
          line?.kind.wireValue,
        );
        await bridge.saveWidgetData<bool>(
          'cove_widget_sheet_row_${i}_done',
          line?.isCompleted ?? false,
        );
      }

      for (var i = 0; i < DaySheetSummary.maxVisibleHabitDots; i++) {
        final dot = i < visibleDots.length ? visibleDots[i] : null;
        await bridge.saveWidgetData<String>(
          'cove_widget_sheet_habit_${i}_id',
          dot?.habitId,
        );
        await bridge.saveWidgetData<bool>(
          'cove_widget_sheet_habit_${i}_owned',
          dot?.isOwnedByViewer ?? false,
        );
        await bridge.saveWidgetData<bool>(
          'cove_widget_sheet_habit_${i}_kept',
          dot?.isKeptToday ?? false,
        );
      }

      if (generation != _sheetRenderGeneration) return;

      final darkSheet = _wrapForOffscreenRender(
        theme: CoveTheme.darkTheme,
        size: sheetLogicalSize,
        child: CoveDaySheetCard(summary: summary),
      );
      final lightSheet = _wrapForOffscreenRender(
        theme: CoveTheme.lightTheme,
        size: sheetLogicalSize,
        child: CoveDaySheetCard(summary: summary),
      );

      await bridge.renderFlutterWidget(
        darkSheet,
        key: sheetDarkKey,
        logicalSize: sheetLogicalSize,
      );
      if (generation != _sheetRenderGeneration) return;
      await bridge.renderFlutterWidget(
        lightSheet,
        key: sheetLightKey,
        logicalSize: sheetLogicalSize,
      );
      if (generation != _sheetRenderGeneration) return;

      await _renderActiveExactSizesForKind(
        kind: 'sheet',
        childBuilder: () => CoveDaySheetCard(summary: summary),
      );
      if (generation != _sheetRenderGeneration) return;

      await bridge.updateWidget(
        androidName: CoveWidgetProviderInfo.daySheet.androidName,
        qualifiedAndroidName:
            CoveWidgetProviderInfo.daySheet.qualifiedAndroidName,
      );
    } catch (e) {
      debugPrint('[CoveWidgetService] Failed to render Day Sheet widget: $e');
    }
  }

  /// Immediately re-renders the cached Day Sheet snapshot with an optimistic
  /// task or viewer-owned habit tick (`design/specs/18-widgets.md` §4 & § Ticking).
  Future<DaySheetSummary?> renderOptimisticDaySheetTick({
    String? taskRecordId,
    bool? taskToDone,
    String? habitRecordId,
    bool? habitToDone,
    SharedPreferences? prefsOverride,
  }) async {
    try {
      final prefs = prefsOverride ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(cachedSheetSnapshotPrefKey);
      if (raw == null || raw.isEmpty) return null;
      final current = DaySheetSummary.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      final updated = current.withOptimisticTick(
        taskRecordId: taskRecordId,
        taskToDone: taskToDone,
        habitRecordId: habitRecordId,
        habitToDone: habitToDone,
      );
      await renderAndPushDaySheet(summary: updated, force: true);
      return updated;
    } catch (_) {
      return null;
    }
  }

  /// Refreshes all registered Android widget providers in the background
  /// (invoked by the 30-minute WorkManager periodic job).
  ///
  /// Never writes to the Drift database (`design/specs/18-widgets.md`).
  /// Enforces a minimum 15-minute interval between background refreshes.
  Future<bool> runBackgroundRefresh({DateTime? nowOverride}) async {
    final now = nowOverride ?? clock.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(
        WorkmanagerWidgetRefreshScheduler.lastBackgroundRefreshEpochMsKey,
      );
      if (lastMs != null) {
        final elapsed = Duration(
          milliseconds: now.millisecondsSinceEpoch - lastMs,
        );
        if (elapsed >= Duration.zero &&
            elapsed < WorkmanagerWidgetRefreshScheduler.minBackgroundInterval) {
          return true;
        }
      }
      await prefs.setInt(
        WorkmanagerWidgetRefreshScheduler.lastBackgroundRefreshEpochMsKey,
        now.millisecondsSinceEpoch,
      );

      final rawArcSnapshot = prefs.getString(cachedArcSnapshotPrefKey);
      if (rawArcSnapshot != null && rawArcSnapshot.isNotEmpty) {
        final restoredArc = _restoreArcSnapshotFromJson(
          jsonDecode(rawArcSnapshot) as Map<String, dynamic>,
          now: now,
        );
        if (restoredArc != null) {
          await renderAndPushDayArc(
            summary: restoredArc,
            force: true,
          );
        }
      }

      final rawSlipSnapshot = prefs.getString(cachedSlipSnapshotPrefKey);
      if (rawSlipSnapshot != null && rawSlipSnapshot.isNotEmpty) {
        try {
          final restoredSlip = SlipSummary.fromJson(
            jsonDecode(rawSlipSnapshot) as Map<String, dynamic>,
          );
          await renderAndPushSlip(
            summary: restoredSlip,
            force: true,
          );
        } catch (_) {}
      }

      final rawSheetSnapshot = prefs.getString(cachedSheetSnapshotPrefKey);
      if (rawSheetSnapshot != null && rawSheetSnapshot.isNotEmpty) {
        try {
          final restoredSheet = DaySheetSummary.fromJson(
            jsonDecode(rawSheetSnapshot) as Map<String, dynamic>,
          ).atTime(now);
          await renderAndPushDaySheet(
            summary: restoredSheet,
            force: true,
          );
        } catch (_) {}
      }

      final rawSnapshot = prefs.getString(cachedLedgerSnapshotPrefKey);
      if (rawSnapshot != null && rawSnapshot.isNotEmpty) {
        final restored = _restoreSnapshotFromJson(
          jsonDecode(rawSnapshot) as Map<String, dynamic>,
          now: now,
        );
        if (restored != null) {
          await renderAndPushLedger(
            expenses: restored.$1,
            commitments: restored.$2,
            force: true,
          );
        }
      }

      if (bridge.isSupported) {
        for (final info in CoveWidgetProviderInfo.all) {
          await bridge.updateWidget(
            androidName: info.androidName,
            qualifiedAndroidName: info.qualifiedAndroidName,
          );
        }
      }
      return true;
    } catch (e) {
      debugPrint('[CoveWidgetService] Background refresh error: $e');
      return true;
    }
  }

  static Widget _wrapForOffscreenRender({
    required ThemeData theme,
    required Size size,
    required Widget child,
  }) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: theme,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> _saveSnapshotToPrefs({
    required ExpensesStandingSummary expenses,
    required CommitmentsSummary commitments,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = commitments.nextSharedCommitment;
      final payload = <String, dynamic>{
        'standingYear': expenses.standingMonth.year,
        'standingMonth': expenses.standingMonth.month,
        'sharedMonthlyTotal': expenses.sharedMonthlyTotal,
        'paidByMeSharedTotal': expenses.paidByMeSharedTotal,
        'paidByPartnerSharedTotal': expenses.paidByPartnerSharedTotal,
        'prevMonthName': expenses.prevMonthName,
        'prevMonthByThisDay': expenses.prevMonthByThisDay,
        'hasPrevComparison': expenses.hasPrevComparison,
        'myName': expenses.myName,
        'partnerName': expenses.partnerName,
        'creatorId': expenses.creatorId,
        'currencyCode': expenses.currency.code,
        if (next != null)
          'nextCommitment': <String, dynamic>{
            'id': next.id,
            'homeId': next.homeId,
            'name': next.name,
            'amount': next.amount,
            'currency': next.currency,
            'billingCycle': next.billingCycle,
            'nextBillingDate': next.nextBillingDate.toIso8601String(),
            'createdAt': next.createdAt.toIso8601String(),
          },
      };
      await prefs.setString(cachedLedgerSnapshotPrefKey, jsonEncode(payload));
    } catch (_) {}
  }

  (ExpensesStandingSummary, CommitmentsSummary)? _restoreSnapshotFromJson(
    Map<String, dynamic> map, {
    required DateTime now,
  }) {
    try {
      final standingYear = (map['standingYear'] as num).toInt();
      final standingMonthNum = (map['standingMonth'] as num).toInt();
      final standingMonth = DateTime(standingYear, standingMonthNum, 1);
      final standingMonthName = DateFormat('MMMM').format(standingMonth);
      final daysInStandingMonth = DateUtils.getDaysInMonth(
        standingYear,
        standingMonthNum,
      );
      final nowLocal = now.toLocal();
      final isSameMonth =
          nowLocal.year == standingYear && nowLocal.month == standingMonthNum;
      final standingDay = isSameMonth
          ? nowLocal.day.clamp(1, daysInStandingMonth)
          : daysInStandingMonth;
      final daysRemaining = (daysInStandingMonth - standingDay).clamp(
        0,
        daysInStandingMonth,
      );

      final sharedMonthlyTotal =
          (map['sharedMonthlyTotal'] as num?)?.toDouble() ?? 0.0;
      final paidByMeSharedTotal =
          (map['paidByMeSharedTotal'] as num?)?.toDouble() ?? 0.0;
      final paidByPartnerSharedTotal =
          (map['paidByPartnerSharedTotal'] as num?)?.toDouble() ?? 0.0;
      final prevMonthByThisDay =
          (map['prevMonthByThisDay'] as num?)?.toDouble() ?? 0.0;
      final hasPrevComparison = map['hasPrevComparison'] as bool? ?? false;
      final prevDelta = sharedMonthlyTotal - prevMonthByThisDay;
      final isSpendingLess = prevDelta <= 0;
      final prevPct = prevMonthByThisDay > 0
          ? ((prevDelta.abs() / prevMonthByThisDay) * 100).round()
          : 0;
      final prevMonth = DateTime(standingYear, standingMonthNum - 1, 1);
      final prevMonthName =
          map['prevMonthName'] as String? ?? DateFormat('MMMM').format(prevMonth);
      final currencyCode = map['currencyCode'] as String? ?? 'INR';
      final currency = supportedCurrencies.firstWhere(
        (c) => c.code == currencyCode,
        orElse: () => supportedCurrencies.first,
      );

      final expenses = ExpensesStandingSummary(
        referenceDate: now,
        standingMonth: standingMonth,
        standingMonthName: standingMonthName,
        daysInStandingMonth: daysInStandingMonth,
        standingDay: standingDay,
        daysRemaining: daysRemaining,
        standingMonthExpenses: const [],
        standingActualExpenses: const [],
        standingTransfers: const [],
        sharedMonthlyTotal: sharedMonthlyTotal,
        paidByMeSharedTotal: paidByMeSharedTotal,
        paidByPartnerSharedTotal: paidByPartnerSharedTotal,
        sharedCount: 0,
        personalCount: 0,
        transfersMonthlyTotal: 0.0,
        sentByMeTotal: 0.0,
        sentByPartnerTotal: 0.0,
        transfersCount: 0,
        prevMonth: prevMonth,
        prevMonthName: prevMonthName,
        daysInPrevMonth: DateUtils.getDaysInMonth(
          prevMonth.year,
          prevMonth.month,
        ),
        prevMonthTotal: prevMonthByThisDay,
        prevMonthByThisDay: prevMonthByThisDay,
        hasPrevComparison: hasPrevComparison,
        prevDelta: prevDelta,
        isSpendingLess: isSpendingLess,
        prevPct: prevPct,
        myName: map['myName'] as String? ?? 'You',
        partnerName: map['partnerName'] as String? ?? 'Partner',
        creatorId: map['creatorId'] as String? ?? 'user_alex',
        currency: currency,
        monthlyBudget: null,
      );

      final nextMap = map['nextCommitment'] as Map<String, dynamic>?;
      final nextSub = nextMap != null
          ? LocalSubscription(
              id: nextMap['id'] as String,
              homeId: nextMap['homeId'] as String? ?? 'home_1',
              name: nextMap['name'] as String,
              amount: (nextMap['amount'] as num).toDouble(),
              currency: nextMap['currency'] as String? ?? currencyCode,
              billingCycle: nextMap['billingCycle'] as String? ?? 'monthly',
              nextBillingDate: DateTime.parse(
                nextMap['nextBillingDate'] as String,
              ),
              isActive: true,
              isPrivate: false,
              createdAt: DateTime.parse(nextMap['createdAt'] as String),
            )
          : null;

      final commitments = CommitmentsSummary.compute(
        nextSub != null ? [nextSub] : const [],
        referenceDate: now,
      );

      return (expenses, commitments);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveArcSnapshotToPrefs(DayArcSummary summary) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'referenceDate': summary.referenceDate.toIso8601String(),
        'bands': summary.bands.map((b) => b.toJson()).toList(),
        'habitDots': summary.habitDots.map((d) => d.toJson()).toList(),
      };
      await prefs.setString(cachedArcSnapshotPrefKey, jsonEncode(payload));
    } catch (_) {}
  }

  DayArcSummary? _restoreArcSnapshotFromJson(
    Map<String, dynamic> map, {
    required DateTime now,
  }) {
    try {
      final referenceDate = DateTime.parse(map['referenceDate'] as String);
      final rawBands = map['bands'] as List<dynamic>? ?? const [];
      final rawDots = map['habitDots'] as List<dynamic>? ?? const [];
      final bands = rawBands
          .whereType<Map<String, dynamic>>()
          .map(DayArcBand.fromJson)
          .toList();
      final habitDots = rawDots
          .whereType<Map<String, dynamic>>()
          .map(DayArcHabitDot.fromJson)
          .toList();
      final nowMinutes = (now.hour * 60 + now.minute).clamp(0, 1439);
      final base = DayArcSummary(
        referenceDate: referenceDate,
        nowMinutes: nowMinutes,
        bands: bands,
        habitDots: habitDots,
        currentOrNextBand: DayArcSummary.selectCurrentOrNextBand(
          bands,
          nowMinutes,
        ),
      );
      return base.atTime(now);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveSlipSnapshotToPrefs(SlipSummary summary) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        cachedSlipSnapshotPrefKey,
        jsonEncode(summary.toJson()),
      );
    } catch (_) {}
  }

  Future<void> _saveSheetSnapshotToPrefs(DaySheetSummary summary) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        cachedSheetSnapshotPrefKey,
        jsonEncode(summary.toJson()),
      );
    } catch (_) {}
  }

  static String bitmapKeyForExactSize(
    String kind,
    Size sizeDp, {
    required bool isDark,
  }) {
    final w = sizeDp.width.round();
    final h = sizeDp.height.round();
    final suffix = isDark ? 'dark' : 'light';
    return 'cove_widget_${kind}_${w}x${h}_$suffix';
  }

  Future<double> _resolveDeviceDensity() async {
    if (bridge is HomeWidgetPlatformBridge && bridge.isSupported) {
      try {
        final raw = await HomeWidget.getWidgetData<String>(
          'cove_widget_device_density',
        );
        if (raw != null) {
          final parsed = double.tryParse(raw);
          if (parsed != null && parsed > 0) return parsed;
        }
      } catch (_) {}
    }
    final viewRatio =
        WidgetsBinding.instance.platformDispatcher.implicitView?.devicePixelRatio;
    if (viewRatio != null && viewRatio > 1.0) {
      return viewRatio;
    }
    return 2.625;
  }

  Future<List<Size>> _resolveActiveSizesForKind(String kind) async {
    if (bridge is! HomeWidgetPlatformBridge || !bridge.isSupported) {
      return const <Size>[];
    }
    try {
      final raw = await HomeWidget.getWidgetData<String>(
        'cove_widget_active_sizes_$kind',
      );
      if (raw == null || raw.trim().isEmpty) return const <Size>[];
      final sizes = <Size>[];
      final seen = <String>{};
      for (final token in raw.split(',')) {
        final trimmed = token.trim();
        if (trimmed.isEmpty || !seen.add(trimmed)) continue;
        final parts = trimmed.split('x');
        if (parts.length != 2) continue;
        final w = int.tryParse(parts[0]);
        final h = int.tryParse(parts[1]);
        if (w != null && h != null && w > 0 && h > 0) {
          sizes.add(Size(w.toDouble(), h.toDouble()));
        }
      }
      return sizes;
    } catch (_) {
      return const <Size>[];
    }
  }

  Future<void> _renderActiveExactSizesForKind({
    required String kind,
    required Widget Function() childBuilder,
  }) async {
    final activeSizes = await _resolveActiveSizesForKind(kind);
    if (activeSizes.isEmpty) return;
    final density = await _resolveDeviceDensity();
    for (final sizeDp in activeSizes) {
      await _renderPairAtExactSize(
        kind: kind,
        sizeDp: sizeDp,
        density: density,
        childBuilder: childBuilder,
      );
    }
  }

  Future<void> _renderPairAtExactSize({
    required String kind,
    required Size sizeDp,
    required double density,
    required Widget Function() childBuilder,
  }) async {
    final exactSize = Size(
      sizeDp.width.roundToDouble(),
      sizeDp.height.roundToDouble(),
    );
    final darkWidget = _wrapForOffscreenRender(
      theme: CoveTheme.darkTheme,
      size: exactSize,
      child: childBuilder(),
    );
    final lightWidget = _wrapForOffscreenRender(
      theme: CoveTheme.lightTheme,
      size: exactSize,
      child: childBuilder(),
    );
    await bridge.renderFlutterWidget(
      darkWidget,
      key: bitmapKeyForExactSize(kind, exactSize, isDark: true),
      logicalSize: exactSize,
      pixelRatio: density,
    );
    await bridge.renderFlutterWidget(
      lightWidget,
      key: bitmapKeyForExactSize(kind, exactSize, isDark: false),
      logicalSize: exactSize,
      pixelRatio: density,
    );
  }

  /// Renders a specific widget [kind] (`arc`, `slip`, `ledger`, `sheet`) at
  /// [sizeDp] (in dp) times [density] from its cached snapshot and triggers
  /// an `AppWidgetManager` update.
  Future<bool> renderWidgetAtExactSize({
    required String kind,
    required Size sizeDp,
    double? density,
    DateTime? nowOverride,
    SharedPreferences? prefsOverride,
  }) async {
    if (!bridge.isSupported) return false;
    final now = nowOverride ?? clock.now();
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final effectiveDensity = density ?? await _resolveDeviceDensity();

    try {
      switch (kind) {
        case 'arc':
          final raw = prefs.getString(cachedArcSnapshotPrefKey);
          if (raw == null || raw.isEmpty) return false;
          final summary = _restoreArcSnapshotFromJson(
            jsonDecode(raw) as Map<String, dynamic>,
            now: now,
          );
          if (summary == null) return false;
          await _renderPairAtExactSize(
            kind: 'arc',
            sizeDp: sizeDp,
            density: effectiveDensity,
            childBuilder: () => CoveDayArcCard(summary: summary),
          );
          await bridge.updateWidget(
            androidName: CoveWidgetProviderInfo.dayArc.androidName,
            qualifiedAndroidName:
                CoveWidgetProviderInfo.dayArc.qualifiedAndroidName,
          );
          return true;

        case 'slip':
          final raw = prefs.getString(cachedSlipSnapshotPrefKey);
          if (raw == null || raw.isEmpty) return false;
          final summary = SlipSummary.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
          await _renderPairAtExactSize(
            kind: 'slip',
            sizeDp: sizeDp,
            density: effectiveDensity,
            childBuilder: () => CoveSlipCard(summary: summary),
          );
          await bridge.updateWidget(
            androidName: CoveWidgetProviderInfo.slip.androidName,
            qualifiedAndroidName:
                CoveWidgetProviderInfo.slip.qualifiedAndroidName,
          );
          return true;

        case 'ledger':
          final raw = prefs.getString(cachedLedgerSnapshotPrefKey);
          if (raw == null || raw.isEmpty) return false;
          final restored = _restoreSnapshotFromJson(
            jsonDecode(raw) as Map<String, dynamic>,
            now: now,
          );
          if (restored == null) return false;
          await _renderPairAtExactSize(
            kind: 'ledger',
            sizeDp: sizeDp,
            density: effectiveDensity,
            childBuilder: () => CoveLedgerCard(
              expenses: restored.$1,
              commitments: restored.$2,
            ),
          );
          await bridge.updateWidget(
            androidName: CoveWidgetProviderInfo.ledger.androidName,
            qualifiedAndroidName:
                CoveWidgetProviderInfo.ledger.qualifiedAndroidName,
          );
          return true;

        case 'sheet':
          final raw = prefs.getString(cachedSheetSnapshotPrefKey);
          if (raw == null || raw.isEmpty) return false;
          final summary = DaySheetSummary.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          ).atTime(now);
          await _renderPairAtExactSize(
            kind: 'sheet',
            sizeDp: sizeDp,
            density: effectiveDensity,
            childBuilder: () => CoveDaySheetCard(summary: summary),
          );
          await bridge.updateWidget(
            androidName: CoveWidgetProviderInfo.daySheet.androidName,
            qualifiedAndroidName:
                CoveWidgetProviderInfo.daySheet.qualifiedAndroidName,
          );
          return true;

        default:
          return false;
      }
    } catch (e) {
      debugPrint(
        '[CoveWidgetService] Failed to render $kind at exact size $sizeDp: $e',
      );
      return false;
    }
  }
}

/// Top-level background callback registered with `HomeWidget.registerInteractivityCallback`
/// for home-screen widget ticks, list selection, and exact-size resize renders
/// (`design/specs/18-widgets.md` § Ticking & § Sizes).
@pragma('vm:entry-point')
Future<void> coveWidgetBackgroundCallback(Uri? uri) async {
  PendingDeleteService.markAsBackgroundIsolate();
  if (uri == null || uri.scheme != 'cove' || uri.host != 'widget') return;
  WidgetsFlutterBinding.ensureInitialized();

  final segments = uri.pathSegments;
  if (segments.isEmpty) return;

  if (segments.first == 'resize') {
    final kind = uri.queryParameters['kind'];
    final w = double.tryParse(uri.queryParameters['w'] ?? '');
    final h = double.tryParse(uri.queryParameters['h'] ?? '');
    final density = double.tryParse(uri.queryParameters['density'] ?? '');
    if (kind != null &&
        kind.isNotEmpty &&
        w != null &&
        h != null &&
        w > 0 &&
        h > 0) {
      final widgetService = CoveWidgetService();
      await widgetService.renderWidgetAtExactSize(
        kind: kind,
        sizeDp: Size(w, h),
        density: density,
      );
    }
    return;
  }

  if (segments.first == 'tick') {
    final kind = WidgetTickKind.fromWire(uri.queryParameters['kind']) ??
        WidgetTickKind.listItem;
    final recordId = uri.queryParameters['recordId'];
    if (recordId == null || recordId.isEmpty) return;
    final toDone = (uri.queryParameters['toDone'] ?? 'true') != 'false';
    final checkinDate = uri.queryParameters['checkinDate'];

    final widgetService = CoveWidgetService();
    await CoveWidgetTickService.handleWidgetTick(
      kind: kind,
      recordId: recordId,
      toDone: toDone,
      checkinDate: checkinDate,
      onOptimisticRender: (intent) async {
        if (intent.kind == WidgetTickKind.listItem) {
          await widgetService.renderOptimisticSlipTick(
            intent.recordId,
            toDone: intent.toDone,
          );
          await widgetService.renderOptimisticDaySheetTick(
            taskRecordId: intent.recordId,
            taskToDone: intent.toDone,
          );
        } else if (intent.kind == WidgetTickKind.habitCheckin) {
          await widgetService.renderOptimisticDaySheetTick(
            habitRecordId: intent.recordId,
            habitToDone: intent.toDone,
          );
        }
      },
    );
    return;
  }

  if (segments.first == 'slip' &&
      segments.length > 1 &&
      segments[1] == 'select') {
    final listId = uri.queryParameters['listId'];
    if (listId != null && listId.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SlipSelectedListIdNotifier.prefKey, listId);
      SlipSelectedListIdNotifier.cachedInitialListId = listId;
    }
  }
}

final widgetRefreshSchedulerProvider = Provider<WidgetRefreshScheduler>((ref) {
  return WorkmanagerWidgetRefreshScheduler();
});

final coveWidgetServiceProvider = Provider<CoveWidgetService>((ref) {
  return CoveWidgetService(
    scheduler: ref.watch(widgetRefreshSchedulerProvider),
  );
});

/// Reactive watcher that re-renders home-screen widgets whenever app data
/// affecting any widget changes (`design/specs/18-widgets.md` § Rendering).
final coveWidgetAutoSyncProvider = Provider<void>((ref) {
  final service = ref.watch(coveWidgetServiceProvider);
  final dayArc = ref.watch(dayArcSummaryProvider);
  final slip = ref.watch(slipSummaryProvider);
  final daySheet = ref.watch(daySheetSummaryProvider);
  final expenses = ref.watch(expensesStandingSummaryProvider);
  final commitments = ref.watch(commitmentsSummaryProvider);

  // Also watch the remaining widget data streams (Lists, Weather) so any
  // change to widget-relevant data triggers a refresh.
  ref.watch(activeHomeListsProvider);
  ref.watch(activeHomeAllListItemsProvider);
  ref.watch(weatherProvider);

  unawaited(
    service.renderAndPushDayArc(summary: dayArc),
  );
  unawaited(
    service.renderAndPushSlip(summary: slip),
  );
  unawaited(
    service.renderAndPushDaySheet(summary: daySheet),
  );
  unawaited(
    service.renderAndPushLedger(
      expenses: expenses,
      commitments: commitments,
    ),
  );
});
