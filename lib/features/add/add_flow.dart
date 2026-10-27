import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_avatar.dart';
import '../../core/widgets/cove_page_header.dart' show CovePageInsets;
import '../../core/widgets/cove_round_button.dart';
import '../../core/widgets/cove_sheet.dart';
import '../../core/widgets/slips/cove_add_mark.dart';
import '../../core/widgets/slips/cove_band.dart';
import '../../core/widgets/slips/cove_habit_card.dart';
import '../../core/widgets/slips/cove_note.dart';
import '../../core/widgets/slips/cove_slip.dart';
import '../../core/widgets/slips/cove_ticket.dart';
import '../../core/widgets/slips/cove_voucher.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../calendar/calendar_controller.dart';
import '../expenses/expense_controller.dart';
import '../expenses/expense_detail_sheet.dart';
import '../habits/habit_controller.dart';
import '../lists/list_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../profile/user_profile_controller.dart';
import '../routines/routine_controller.dart';
import '../subscriptions/subscription_controller.dart';
import 'add_draft.dart';
import 'widgets/add_step_pieces.dart';

/// Unified Add flow (`design/specs/14-add-flow.md`).
///
/// - When opened with `kind == null`, presents the 6-tile picker (§1).
/// - When opened with a [kind], skips the picker and opens on step 1 of that kind (§2).
/// - All six kinds (`expense`, `event`, `task`, `habit`, `commitment`, and
///   `routine`) are wired end-to-end through their feature controllers.
class AddFlow extends ConsumerStatefulWidget {
  final AddKind? initialKind;
  final DateTime? anchor;
  final String? listId;
  final String? routineId;
  final int? startMinutes;
  final bool presetEmi;
  final bool presetMonthly;

  /// Optional pre-populated draft for golden showcases or Again (§6).
  final AddDraft? initialDraft;

  /// Optional initial step index (`0..steps.length - 1`) for golden showcases.
  final int? initialStepIndex;

  /// Optional initial `Added.` confirmation state for golden showcases (§7).
  final bool initialIsAdded;

  /// Optional Again summary row on the picker (§6).
  final AddAgainSummary? againSummary;

  /// Optional carried line pill on the active step when repeating via Again (§6).
  final String? initialCarriedLine;

  static const double _kTileBorderWidth = 1.0; // (literal) 1dp picker tile border
  static const double _kInputUnderlineHeight = 1.5; // (literal) 1.5dp text input underline
  static const double _kRepeatIconSize = 18.0; // (literal) 18dp Again icon
  static const double _kViewportReserve = 96.0; // (literal) top sheet headroom

  const AddFlow({
    super.key,
    this.initialKind,
    this.anchor,
    this.listId,
    this.routineId,
    this.startMinutes,
    this.presetEmi = false,
    this.presetMonthly = false,
    this.initialDraft,
    this.initialStepIndex,
    this.initialIsAdded = false,
    this.againSummary,
    this.initialCarriedLine,
  });

  /// Presents the unified Add flow on a modal [CoveSheet].
  static Future<String?> show(
    BuildContext context, {
    AddKind? kind,
    DateTime? anchor,
    String? listId,
    String? routineId,
    int? startMinutes,
    bool presetEmi = false,
    bool presetMonthly = false,
  }) {
    return CoveSheet.show<String>(
      context: context,
      builder: (sheetContext) => AddFlow(
        initialKind: kind,
        anchor: anchor,
        listId: listId,
        routineId: routineId,
        startMinutes: startMinutes,
        presetEmi: presetEmi,
        presetMonthly: presetMonthly,
      ),
    );
  }

  @override
  ConsumerState<AddFlow> createState() => _AddFlowState();
}

/// Summary data for the optional **Again** row in the picker (`design/specs/14-add-flow.md` §6).
@immutable
class AddAgainSummary {
  final AddKind kind;
  final String titleAndContext;
  final String lastReadout;
  final VoidCallback? onTap;

  const AddAgainSummary({
    required this.kind,
    required this.titleAndContext,
    required this.lastReadout,
    this.onTap,
  });
}

class _AddFlowState extends ConsumerState<AddFlow> {
  static const List<(AddKind, String, String)> _pickerTiles =
      <(AddKind, String, String)>[
    (AddKind.event, 'Event', 'a plan, an outing'),
    (AddKind.expense, 'Expense', 'something spent'),
    (AddKind.task, 'Task', 'to do, by a day'),
    (AddKind.habit, 'Habit', 'something you keep up'),
    (AddKind.commitment, 'Commitment', 'a bill that renews'),
    (AddKind.routine, 'Routine', 'the shape of a day'),
  ];

  static const List<String> _defaultCategories = <String>[
    'Groceries',
    'Eating out',
    'Fuel',
    'Home',
    'Health',
    'Travel',
    'Gifts',
    'Pets',
  ];

  AddKind? _activeKind;
  AddDraft? _draft;
  int _stepIndex = 0;
  bool _editingFromReview = false;
  bool _startedFromAgain = false;
  String? _againCarriedLine;
  bool _isAdded = false;
  bool _isSubmitting = false;
  String? _toastMessage;
  bool _isErrorToast = false;
  bool _addingNewCategory = false;
  String? _pendingCreatedRoutineId;
  List<int>? _pendingCreatedRoutineDays;
  String? _seededRoutineId;

  late final TextEditingController _textController;
  late final TextEditingController _newCategoryController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _newCategoryController = TextEditingController();
    _activeKind = widget.initialDraft?.kind ?? widget.initialKind;
    _draft = widget.initialDraft;
    _stepIndex = widget.initialStepIndex ?? 0;
    _isAdded = widget.initialIsAdded;
    _againCarriedLine = widget.initialCarriedLine;
    _startedFromAgain = widget.initialCarriedLine != null;
  }

  @override
  void didUpdateWidget(covariant AddFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDraft != oldWidget.initialDraft ||
        widget.initialStepIndex != oldWidget.initialStepIndex ||
        widget.initialKind != oldWidget.initialKind ||
        widget.initialIsAdded != oldWidget.initialIsAdded ||
        widget.initialCarriedLine != oldWidget.initialCarriedLine) {
      _activeKind = widget.initialDraft?.kind ?? widget.initialKind;
      _draft = widget.initialDraft;
      _stepIndex = widget.initialStepIndex ?? 0;
      _isAdded = widget.initialIsAdded;
      _againCarriedLine = widget.initialCarriedLine;
      _startedFromAgain = widget.initialCarriedLine != null;
      _editingFromReview = false;
      _seededRoutineId = null;
      if (_activeKind != null && _draft == null) {
        final flowCtx = _buildFlowContext();
        _draft = _createInitialDraft(_activeKind!, flowCtx);
      }
      _syncTextControllerToCurrentStep();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_activeKind != null && _draft == null) {
      final flowCtx = _buildFlowContext();
      _draft = _createInitialDraft(_activeKind!, flowCtx);
    }
    _syncTextControllerToCurrentStep();
  }

  @override
  void dispose() {
    _textController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  AddFlowContext _buildFlowContext() {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final anchorDate = widget.anchor != null
        ? DateTime(
            widget.anchor!.year,
            widget.anchor!.month,
            widget.anchor!.day,
          )
        : today;

    final currentUser = ref.watch(authProvider).value;
    final partnerProfile = ref.watch(partnerProfileProvider);
    final lists = ref.watch(activeHomeListsProvider).value ?? const [];
    final existingRoutines =
        ref.watch(activeHomeRoutinesProvider).value ?? const [];
    final unarchivedLists = lists.where((l) => !l.isArchived).toList();

    final viewerId = currentUser?.id ?? 'user_alex';
    final hasPartner = (partnerProfile.userId != null &&
            partnerProfile.userId!.trim().isNotEmpty) ||
        partnerProfile.hasCustomName ||
        partnerProfile.displayName.trim().isNotEmpty;
    final partnerId = (partnerProfile.userId != null &&
            partnerProfile.userId!.trim().isNotEmpty)
        ? partnerProfile.userId!
        : 'partner_user';

    final td = _draft is TaskDraft ? _draft as TaskDraft : null;
    final keepTaskDraftListContext = td != null &&
        (_isSubmitting ||
            _isAdded ||
            (td.newListName != null && td.newListName!.trim().isNotEmpty) ||
            (widget.initialDraft != null && unarchivedLists.isEmpty));
    final effectiveListCount = keepTaskDraftListContext
        ? td.listCount
        : unarchivedLists.length;
    final effectiveOpenedFromList =
        (td != null && widget.initialDraft != null)
            ? td.openedFromList
            : (widget.listId != null);
    final resolvedActiveListId = widget.listId ??
        (unarchivedLists.length == 1 ? unarchivedLists.first.id : null);

    if (td != null &&
        widget.initialDraft == null &&
        !keepTaskDraftListContext &&
        (td.listCount != effectiveListCount ||
            td.openedFromList != effectiveOpenedFromList ||
            (td.listId == null && resolvedActiveListId != null))) {
      _draft = td.copyWith(
        listCount: effectiveListCount,
        openedFromList: effectiveOpenedFromList,
        listId: td.listId ?? resolvedActiveListId,
      );
    }

    final rd = _draft is RoutineDraft ? _draft as RoutineDraft : null;
    if (rd != null &&
        widget.initialDraft == null &&
        widget.routineId != null &&
        _seededRoutineId != widget.routineId) {
      for (final r in existingRoutines) {
        if (r.id == widget.routineId) {
          final valid = r.days.where((d) => d >= 1 && d <= 7).toSet();
          if (valid.isNotEmpty) {
            _draft = rd.copyWith(days: valid);
          }
          _seededRoutineId = widget.routineId;
          break;
        }
      }
    }

    return AddFlowContext(
      anchor: anchorDate,
      today: today,
      hasPartner: hasPartner,
      listCount: effectiveListCount,
      openedFromList: effectiveOpenedFromList,
      viewerUserId: viewerId,
      partnerUserId: partnerId,
      activeListId: resolvedActiveListId,
      routineId: widget.routineId,
      startMinutes: widget.startMinutes,
      presetEmi: widget.presetEmi,
      presetMonthly: widget.presetMonthly,
      existingRoutines: existingRoutines,
    );
  }

  AddDraft _createInitialDraft(AddKind kind, AddFlowContext ctx) {
    switch (kind) {
      case AddKind.expense:
        return ExpenseDraft.initial(ctx);
      case AddKind.event:
        return EventDraft.initial(ctx);
      case AddKind.task:
        return TaskDraft.initial(ctx);
      case AddKind.habit:
        return HabitDraft.initial(ctx);
      case AddKind.commitment:
        return CommitmentDraft.initial(ctx);
      case AddKind.routine:
        if (ctx.routineId != null &&
            ctx.existingRoutines.any((r) => r.id == ctx.routineId)) {
          _seededRoutineId = ctx.routineId;
        }
        return RoutineDraft.initial(ctx);
    }
  }

  List<AddStep> _currentSteps(AddFlowContext ctx) {
    final d = _draft;
    if (d == null) return const <AddStep>[];
    return d.stepsFor(ctx);
  }

  AddStep? _currentStep(AddFlowContext ctx) {
    final steps = _currentSteps(ctx);
    if (steps.isEmpty) return null;
    final idx = _stepIndex.clamp(0, steps.length - 1);
    return steps[idx];
  }

  void _syncTextControllerToCurrentStep() {
    final d = _draft;
    if (d == null) return;
    final ctx = _buildFlowContext();
    final step = _currentStep(ctx);
    String? desired;
    if (step == AddStep.expenseTitle && d is ExpenseDraft) {
      desired = d.title;
    } else if (step == AddStep.eventTitle && d is EventDraft) {
      desired = d.title;
    } else if (step == AddStep.eventLocation && d is EventDraft) {
      desired = d.location ?? '';
    } else if (step == AddStep.taskTitle && d is TaskDraft) {
      desired = d.title;
    } else if (step == AddStep.taskNameTheList && d is TaskDraft) {
      desired = d.newListName ?? '';
    } else if (step == AddStep.habitName && d is HabitDraft) {
      desired = d.name;
    } else if (step == AddStep.commitmentName && d is CommitmentDraft) {
      desired = d.name;
    } else if (step == AddStep.commitmentPaidFrom && d is CommitmentDraft) {
      desired = d.paidFrom ?? '';
    } else if (step == AddStep.routineTitle && d is RoutineDraft) {
      desired = d.title;
    }
    if (desired != null && _textController.text != desired) {
      _textController.value = TextEditingValue(
        text: desired,
        selection: TextSelection.collapsed(offset: desired.length),
      );
    }
  }

  void _showToast(String message, {bool isError = false}) {
    setState(() {
      _toastMessage = message;
      _isErrorToast = isError;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }

  void _selectKindFromPicker(AddKind kind) {
    final ctx = _buildFlowContext();
    setState(() {
      _activeKind = kind;
      _draft = _createInitialDraft(kind, ctx);
      _stepIndex = 0;
      _editingFromReview = false;
      _startedFromAgain = false;
      _againCarriedLine = null;
      _isAdded = false;
      _toastMessage = null;
      _addingNewCategory = false;
      _pendingCreatedRoutineId = null;
      _pendingCreatedRoutineDays = null;
    });
    _syncTextControllerToCurrentStep();
  }

  void _goToStep(int targetIndex, {bool fromReviewField = false}) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _stepIndex = targetIndex;
      _editingFromReview = fromReviewField;
      _startedFromAgain = false;
      _againCarriedLine = null;
      _toastMessage = null;
      _addingNewCategory = false;
    });
    _syncTextControllerToCurrentStep();
  }

  void _goToStepEnum(AddStep targetStep, AddFlowContext ctx,
      {bool fromReviewField = false}) {
    final steps = _currentSteps(ctx);
    final idx = steps.indexOf(targetStep);
    if (idx >= 0) {
      _goToStep(idx, fromReviewField: fromReviewField);
    }
  }

  void _advanceStep(AddFlowContext ctx) {
    final steps = _currentSteps(ctx);
    if (steps.isEmpty) return;

    if ((_editingFromReview || _startedFromAgain) && _draft!.isComplete) {
      final reviewIdx = steps.indexOf(AddStep.review);
      if (reviewIdx >= 0) {
        _goToStep(reviewIdx, fromReviewField: false);
        return;
      }
    }

    if (_stepIndex + 1 < steps.length) {
      _goToStep(_stepIndex + 1, fromReviewField: false);
    }
  }

  void _handleBack(AddFlowContext ctx) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_addingNewCategory) {
      setState(() => _addingNewCategory = false);
      return;
    }
    if (_editingFromReview && _draft != null && _draft!.isComplete) {
      final steps = _currentSteps(ctx);
      final reviewIdx = steps.indexOf(AddStep.review);
      if (reviewIdx >= 0) {
        _goToStep(reviewIdx, fromReviewField: false);
        return;
      }
    }
    if (_startedFromAgain) {
      if (widget.initialKind == null && widget.initialDraft == null) {
        setState(() {
          _activeKind = null;
          _draft = null;
          _stepIndex = 0;
          _editingFromReview = false;
          _startedFromAgain = false;
          _againCarriedLine = null;
          _toastMessage = null;
        });
      } else {
        Navigator.of(context).maybePop();
      }
      return;
    }
    if (_stepIndex > 0) {
      _goToStep(_stepIndex - 1, fromReviewField: false);
      return;
    }
    if (widget.initialKind == null) {
      setState(() {
        _activeKind = null;
        _draft = null;
        _stepIndex = 0;
        _editingFromReview = false;
        _startedFromAgain = false;
        _againCarriedLine = null;
        _toastMessage = null;
      });
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _handleCommit(AddFlowContext ctx) async {
    final d = _draft;
    if (d == null || !d.isComplete || _isSubmitting || _isAdded) return;

    setState(() {
      _isSubmitting = true;
      _toastMessage = null;
    });

    try {
      if (d is ExpenseDraft) {
        final currency = ref.read(currencyPreferenceProvider).code;
        final args = d.toCreateArgs(
          viewerUserId: ctx.viewerUserId,
          partnerUserId: ctx.partnerUserId,
          currency: currency,
        );
        final controller = ref.read(expenseControllerProvider);
        final createdId = await controller.logExpense(
          title: args.title,
          amount: args.amount,
          currency: args.currency,
          expenseDate: args.expenseDate,
          paidBy: args.paidBy,
          category: args.category,
          notes: args.notes,
          paymentMethod: args.paymentMethod,
          isTransfer: args.isTransfer,
          visibility: args.visibility,
        );
        await ref
            .read(addAgainPreferenceProvider.notifier)
            .setAgain(AddKind.expense, createdId);
      } else if (d is EventDraft) {
        final args = d.toCreateArgs();
        final controller = ref.read(calendarControllerProvider);
        final createdId = await controller.createEvent(
          title: args.title,
          description: args.description,
          startTime: args.startTime,
          endTime: args.endTime,
          isAllDay: args.isAllDay,
          location: args.location,
          recurrence: args.recurrence,
        );
        await ref
            .read(addAgainPreferenceProvider.notifier)
            .setAgain(AddKind.event, createdId);
      } else if (d is TaskDraft) {
        final args = d.toCreateArgs(fallbackListId: ctx.activeListId);
        final controller = ref.read(listControllerProvider);
        var targetListId = args.listId;
        if (args.newListName != null && args.newListName!.isNotEmpty) {
          targetListId = await controller.createList(name: args.newListName!);
        }
        if (targetListId == null || targetListId.isEmpty) {
          throw StateError('No list selected for task.');
        }
        final createdId = await controller.addItem(
          listId: targetListId,
          title: args.title,
          notes: args.notes,
          dueDate: args.dueDate,
          listName: args.newListName,
        );
        await ref
            .read(addAgainPreferenceProvider.notifier)
            .setAgain(AddKind.task, createdId);
      } else if (d is HabitDraft) {
        final args = d.toCreateArgs();
        final controller = ref.read(habitControllerProvider);
        await controller.createHabit(
          name: args.name,
          cadence: args.cadence,
          targetDaysPerWeek: args.targetDaysPerWeek,
          visibility: args.visibility,
        );
      } else if (d is CommitmentDraft) {
        final currency = ref.read(currencyPreferenceProvider).code;
        final args = d.toCreateArgs(
          today: ctx.today,
          viewerUserId: ctx.viewerUserId,
          partnerUserId: ctx.partnerUserId,
          currency: currency,
        );
        final controller = ref.read(subscriptionControllerProvider);
        await controller.createSubscription(
          name: args.name,
          amount: args.amount,
          currency: args.currency,
          billingCycle: args.billingCycle,
          nextBillingDate: args.nextBillingDate,
          category: args.category,
          isPrivate: args.isPrivate,
          endDate: args.endDate,
          paidBy: args.paidBy,
          financedThrough: args.financedThrough,
          totalInstallments: args.totalInstallments,
          paidInstallments: args.paidInstallments,
        );
      } else if (d is RoutineDraft) {
        final existingRoutines =
            ref.read(activeHomeRoutinesProvider).value ?? const [];
        final args = d.toCreateArgs(existingRoutines: existingRoutines);
        final controller = ref.read(routineControllerProvider);
        String targetRoutineId;
        var createdNewSet = false;
        final createdSetName = args.newRoutineName ??
            routineNameForDays(args.days);
        if (args.existingRoutineId != null) {
          targetRoutineId = args.existingRoutineId!;
        } else if (_pendingCreatedRoutineId != null &&
            _pendingCreatedRoutineDays != null &&
            listEquals(_pendingCreatedRoutineDays, args.days)) {
          targetRoutineId = _pendingCreatedRoutineId!;
          createdNewSet = true;
        } else {
          targetRoutineId = await controller.createRoutine(
            name: createdSetName,
            days: args.days,
          );
          _pendingCreatedRoutineId = targetRoutineId;
          _pendingCreatedRoutineDays = args.days;
          createdNewSet = true;
        }
        try {
          await controller.createRoutineEvent(
            routineId: targetRoutineId,
            title: args.title,
            startMinutes: args.startMinutes,
            endMinutes: args.endMinutes,
          );
          _pendingCreatedRoutineId = null;
          _pendingCreatedRoutineDays = null;
        } catch (eventErr) {
          if (createdNewSet) {
            if (mounted) {
              setState(() => _isSubmitting = false);
              _showToast(
                'Created the "$createdSetName" routine set, but could not add "${args.title}": $eventErr',
                isError: true,
              );
            }
            return;
          }
          rethrow;
        }
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isAdded = true;
          _editingFromReview = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showToast('Could not save: $e', isError: true);
      }
    }
  }

  void _handleAddAnother(AddFlowContext ctx) {
    final kind = _activeKind;
    if (kind == null) return;
    setState(() {
      _draft = _createInitialDraft(kind, ctx);
      _stepIndex = 0;
      _editingFromReview = false;
      _startedFromAgain = false;
      _againCarriedLine = null;
      _isAdded = false;
      _toastMessage = null;
      _addingNewCategory = false;
      _pendingCreatedRoutineId = null;
      _pendingCreatedRoutineDays = null;
    });
    _syncTextControllerToCurrentStep();
  }

  AddAgainSummary? _resolveLiveAgainSummary(AddFlowContext ctx) {
    if (widget.againSummary != null) return widget.againSummary;

    final pref = ref.watch(addAgainPreferenceProvider);
    final currency = ref.watch(currencyPreferenceProvider);
    final expenses = ref.watch(activeHomeExpensesProvider).value;
    final listItems = ref.watch(activeHomeAllListItemsProvider).value;
    final lists = ref.watch(activeHomeListsProvider).value;
    final events = ref.watch(activeHomeCalendarEventsProvider).value;

    if (pref == null) return null;

    switch (pref.kind) {
      case AddKind.expense:
        if (expenses == null) return null;
        LocalExpense? expense;
        for (final e in expenses) {
          if (e.id == pref.id && !e.isTransfer) {
            expense = e;
            break;
          }
        }
        if (expense == null) return null;
        final matchedExpense = expense;
        final cleanCategory = cleanExpenseCategoryName(matchedExpense.category);
        final titleAndContext = '${matchedExpense.title} · $cleanCategory';
        final formattedAmount =
            '${currency.symbol}${formatCoveAmount(matchedExpense.amount)}';
        final lastReadout = 'last $formattedAmount';
        final methodLabel =
            formatExpensePaymentMethod(matchedExpense.paymentMethod);
        final carriedParts = <String>[
          matchedExpense.title,
          cleanCategory,
          ?methodLabel,
        ];
        final carriedLine =
            '${carriedParts.join(' · ')} — last time $formattedAmount';
        return AddAgainSummary(
          kind: AddKind.expense,
          titleAndContext: titleAndContext,
          lastReadout: lastReadout,
          onTap: () => _startAgainExpense(ctx, matchedExpense, carriedLine),
        );

      case AddKind.task:
        if (listItems == null) return null;
        LocalListItem? item;
        for (final i in listItems) {
          if (i.id == pref.id) {
            item = i;
            break;
          }
        }
        if (item == null) return null;
        final matchedItem = item;
        String? listName;
        if (lists != null) {
          for (final l in lists) {
            if (l.id == matchedItem.listId) {
              listName = l.name;
              break;
            }
          }
        }
        final cleanListName =
            (listName != null && listName.trim().isNotEmpty)
                ? listName.trim()
                : null;
        final titleAndContext = cleanListName != null
            ? '${matchedItem.title} · $cleanListName'
            : matchedItem.title;
        final lastReadout = matchedItem.dueDate != null
            ? 'last by ${DateFormat('EEEE').format(matchedItem.dueDate!)}'
            : 'last no due date';
        final carriedParts = <String>[
          matchedItem.title,
          ?cleanListName,
        ];
        final lastTimePart = matchedItem.dueDate != null
            ? 'by ${DateFormat('EEEE').format(matchedItem.dueDate!)}'
            : 'no particular day';
        final carriedLine =
            '${carriedParts.join(' · ')} — last time $lastTimePart';
        return AddAgainSummary(
          kind: AddKind.task,
          titleAndContext: titleAndContext,
          lastReadout: lastReadout,
          onTap: () => _startAgainTask(ctx, matchedItem, carriedLine),
        );

      case AddKind.event:
        if (events == null) return null;
        LocalCalendarEvent? event;
        for (final ev in events) {
          if (ev.id == pref.id) {
            event = ev;
            break;
          }
        }
        if (event == null) return null;
        final matchedEvent = event;
        final hasLocation = matchedEvent.location != null &&
            matchedEvent.location!.trim().isNotEmpty;
        final titleAndContext = hasLocation
            ? '${matchedEvent.title} · ${matchedEvent.location!.trim()}'
            : matchedEvent.title;
        final weekday = DateFormat('EEEE').format(matchedEvent.startTime);
        final lastReadout = 'last $weekday';
        final timeLabel = matchedEvent.isAllDay
            ? 'All day'
            : _formatHourMinute(
                matchedEvent.startTime.hour,
                matchedEvent.startTime.minute,
              );
        final carriedParts = <String>[
          matchedEvent.title,
          timeLabel,
          if (hasLocation) matchedEvent.location!.trim(),
        ];
        final carriedLine = '${carriedParts.join(' · ')} — last time $weekday';
        return AddAgainSummary(
          kind: AddKind.event,
          titleAndContext: titleAndContext,
          lastReadout: lastReadout,
          onTap: () => _startAgainEvent(ctx, matchedEvent, carriedLine),
        );

      case AddKind.habit:
      case AddKind.commitment:
      case AddKind.routine:
        return null;
    }
  }

  void _startAgainExpense(
    AddFlowContext ctx,
    LocalExpense expense,
    String carriedLine,
  ) {
    final cleanCategory = cleanExpenseCategoryName(expense.category);
    final isPrivate = expense.splitRatio < 0.0;
    final isShared = expense.splitRatio > 0.0;
    final paidByPartner = !isPrivate &&
        ctx.hasPartner &&
        (expense.paidBy == ctx.partnerUserId ||
            (expense.paidBy != ctx.viewerUserId &&
                expense.paidBy != 'me' &&
                expense.paidBy != 'user_alex'));
    final rawMethod = expense.paymentMethod?.trim().toLowerCase();
    final hasMethod = rawMethod != null && rawMethod.isNotEmpty;

    final draft = ExpenseDraft(
      amount: null,
      title: expense.title,
      expenseDate: ctx.anchor,
      category: cleanCategory,
      payer: paidByPartner ? ExpensePayer.partner : ExpensePayer.you,
      splitHalfAndHalf: isPrivate ? false : isShared,
      isPrivate: isPrivate,
      paymentMethod: hasMethod ? rawMethod : null,
      paymentMethodSkipped: !hasMethod,
      viewerUserId: ctx.viewerUserId,
      partnerUserId: ctx.partnerUserId,
      hasPartner: ctx.hasPartner,
    );

    final steps = draft.stepsFor(ctx);
    final targetIdx = steps.indexOf(AddStep.expenseAmount);
    setState(() {
      _activeKind = AddKind.expense;
      _draft = draft;
      _stepIndex = targetIdx >= 0 ? targetIdx : 0;
      _startedFromAgain = true;
      _againCarriedLine = carriedLine;
      _editingFromReview = false;
      _isAdded = false;
      _toastMessage = null;
      _addingNewCategory = false;
      _pendingCreatedRoutineId = null;
      _pendingCreatedRoutineDays = null;
    });
    _syncTextControllerToCurrentStep();
  }

  void _startAgainTask(
    AddFlowContext ctx,
    LocalListItem item,
    String carriedLine,
  ) {
    final draft = TaskDraft(
      title: item.title,
      listId: item.listId,
      dueDate: null,
      noParticularDay: false,
      listCount: ctx.listCount,
      openedFromList: ctx.openedFromList,
    );

    final steps = draft.stepsFor(ctx);
    final targetIdx = steps.indexOf(AddStep.taskByWhen);
    setState(() {
      _activeKind = AddKind.task;
      _draft = draft;
      _stepIndex = targetIdx >= 0 ? targetIdx : 0;
      _startedFromAgain = true;
      _againCarriedLine = carriedLine;
      _editingFromReview = false;
      _isAdded = false;
      _toastMessage = null;
      _addingNewCategory = false;
      _pendingCreatedRoutineId = null;
      _pendingCreatedRoutineDays = null;
    });
    _syncTextControllerToCurrentStep();
  }

  void _startAgainEvent(
    AddFlowContext ctx,
    LocalCalendarEvent event,
    String carriedLine,
  ) {
    final hasLocation =
        event.location != null && event.location!.trim().isNotEmpty;
    final draft = EventDraft(
      title: event.title,
      day: null,
      hour: event.startTime.hour,
      minute: event.startTime.minute,
      isAllDay: event.isAllDay,
      location: hasLocation ? event.location!.trim() : null,
      locationSkipped: !hasLocation,
    );

    final steps = draft.stepsFor(ctx);
    final targetIdx = steps.indexOf(AddStep.eventDay);
    setState(() {
      _activeKind = AddKind.event;
      _draft = draft;
      _stepIndex = targetIdx >= 0 ? targetIdx : 0;
      _startedFromAgain = true;
      _againCarriedLine = carriedLine;
      _editingFromReview = false;
      _isAdded = false;
      _toastMessage = null;
      _addingNewCategory = false;
      _pendingCreatedRoutineId = null;
      _pendingCreatedRoutineDays = null;
    });
    _syncTextControllerToCurrentStep();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = _buildFlowContext();
    if (_activeKind == null || _draft == null) {
      return _buildPickerSheet(context, ctx);
    }
    return _buildStepSheet(context, ctx);
  }

  // ==========================================================================
  // 1. THE PICKER (§1)
  // ==========================================================================

  Widget _buildPickerSheet(BuildContext context, AddFlowContext ctx) {
    final cv = context.cv;
    final hasDatedAnchor = widget.anchor != null;
    final anchorUpper =
        DateFormat('EEE d MMM').format(ctx.anchor).toUpperCase();
    final resolvedAgain = _resolveLiveAgainSummary(ctx);

    return CoveSheet(
      onDismiss: () => Navigator.of(context).maybePop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Eyebrow row: ADD [· THU 8 OCT] + Close
          Row(
            children: [
              Expanded(
                child: RichText(
                  maxLines: 1,
                  text: TextSpan(
                    style: CoveType.capsPage.copyWith(color: cv.textTertiary),
                    children: [
                      const TextSpan(text: 'ADD'),
                      if (hasDatedAnchor)
                        TextSpan(
                          text: ' · $anchorUpper',
                          style: CoveType.capsPage.copyWith(
                            color: cv.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              CoveRoundButton(
                icon: Icons.close,
                semanticLabel: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: CoveSpace.md),

          // 2 × 3 grid of kind tiles
          for (var row = 0; row < 3; row++) ...[
            if (row > 0) const SizedBox(height: CoveSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildPickerTile(
                    context,
                    _pickerTiles[row * 2],
                  ),
                ),
                const SizedBox(width: CoveSpace.md),
                Expanded(
                  child: _buildPickerTile(
                    context,
                    _pickerTiles[row * 2 + 1],
                  ),
                ),
              ],
            ),
          ],

          // Optional Again row (§6)
          if (resolvedAgain != null) ...[
            const SizedBox(height: CoveSpace.md),
            _buildAgainRow(context, resolvedAgain),
          ],

          // Inline toast banner for Coming in 3.12e/f
          if (_toastMessage != null) ...[
            const SizedBox(height: CoveSpace.md),
            _buildToastBanner(context),
          ],
        ],
      ),
    );
  }

  Widget _buildPickerTile(
    BuildContext context,
    (AddKind, String, String) tile,
  ) {
    final cv = context.cv;
    final (kind, title, subtitle) = tile;

    return Semantics(
      container: true,
      button: true,
      label: '$title, $subtitle',
      onTap: () => _selectKindFromPicker(kind),
      child: ExcludeSemantics(
        child: GestureDetector(
          key: ValueKey('add_picker_tile_${kind.name}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _selectKindFromPicker(kind),
          child: Container(
            constraints: const BoxConstraints(
              minWidth: CoveSize.hit,
              minHeight: CoveSize.row,
            ),
            padding: const EdgeInsets.all(CoveSpace.md),
            decoration: CoveShape.decoration(
              CoveRadius.card,
              color: cv.surfaceRow,
              side: BorderSide(
                color: cv.lineStrong,
                width: AddFlow._kTileBorderWidth,
              ),
            ),
            child: Row(
              children: [
                CoveAddMark(kind),
                const SizedBox(width: CoveSpace.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: CoveType.rowTitle.copyWith(
                          color: cv.textPrimary,
                        ),
                      ),
                      const SizedBox(height: CoveSpace.xs),
                      Text(
                        subtitle,
                        style: CoveType.rowSub.copyWith(
                          color: cv.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAgainRow(BuildContext context, AddAgainSummary summary) {
    final cv = context.cv;

    return Semantics(
      container: true,
      button: true,
      label: 'Again: ${summary.titleAndContext}, ${summary.lastReadout}',
      onTap: summary.onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const ValueKey('add_picker_again_row'),
          behavior: HitTestBehavior.opaque,
          onTap: summary.onTap,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: CoveSize.hit,
              minHeight: CoveSize.row,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.md,
              vertical: CoveSpace.md,
            ),
            decoration: CoveShape.decoration(
              CoveRadius.inline,
              color: cv.surfaceRow,
              side: BorderSide(
                color: cv.lineHairline,
                width: AddFlow._kTileBorderWidth,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.autorenew,
                  size: AddFlow._kRepeatIconSize,
                  color: cv.accentText,
                ),
                const SizedBox(width: CoveSpace.sm),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: CoveType.rowTitle.copyWith(
                        color: cv.textSecondary,
                      ),
                      children: [
                        const TextSpan(text: 'Again: '),
                        TextSpan(
                          text: summary.titleAndContext,
                          style: CoveType.rowTitle.copyWith(
                            color: cv.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: CoveSpace.sm),
                Text(
                  summary.lastReadout,
                  style: CoveType.rowSub.copyWith(color: cv.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToastBanner(BuildContext context) {
    final cv = context.cv;
    return Container(
      key: ValueKey(
        _isErrorToast ? 'add_flow_error_toast' : 'add_flow_info_toast',
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: CoveSpace.md,
        vertical: CoveSpace.sm,
      ),
      decoration: CoveShape.decoration(
        CoveRadius.inline,
        color: _isErrorToast ? cv.statusAlert : cv.surfaceCard,
        side: BorderSide(
          color: _isErrorToast ? cv.statusAlertText : cv.lineStrong,
          width: AddFlow._kTileBorderWidth,
        ),
      ),
      child: Text(
        _toastMessage!,
        textAlign: TextAlign.center,
        style: CoveType.rowSub.copyWith(
          color: _isErrorToast ? cv.statusAlertText : cv.textPrimary,
        ),
      ),
    );
  }

  // ==========================================================================
  // 2. THE STEP PAGE (§2, §5, §7)
  // ==========================================================================

  Widget _buildStepSheet(BuildContext context, AddFlowContext ctx) {
    final cv = context.cv;
    final steps = _currentSteps(ctx);
    final step = _currentStep(ctx)!;
    final stepNumber = _stepIndex + 1;
    final totalSteps = steps.length;
    final kindCaps = _kindDisplayName(_activeKind!).toUpperCase();
    final crumbs = _buildCrumbsBeforeCurrent(ctx, steps);
    final question = _isAdded ? 'Added.' : _questionForStep(step);
    final visibility = _currentVisibility();
    final isReview = step == AddStep.review;

    final mediaSize = MediaQuery.sizeOf(context);
    final verticalInset =
        CovePageInsets.topOf(context) + CovePageInsets.bottomOf(context);
    final maxScrollableHeight = (mediaSize.height -
            verticalInset -
            AddFlow._kViewportReserve)
        .clamp(200.0, double.infinity);

    return CoveSheet(
      isMidCommit: true,
      child: SizedBox(
        height: maxScrollableHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top row: Back (hidden after Added), KIND · STEP OF TOTAL, Close
            Row(
              children: [
                if (!_isAdded) ...[
                  CoveRoundButton(
                    icon: Icons.arrow_back,
                    semanticLabel: 'Back',
                    onPressed: () => _handleBack(ctx),
                  ),
                  const SizedBox(width: CoveSpace.sm),
                ],
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    text: TextSpan(
                      style: CoveType.capsPage.copyWith(color: cv.textPrimary),
                      children: [
                        TextSpan(text: kindCaps),
                        TextSpan(
                          text: ' · $stepNumber OF $totalSteps',
                          style: CoveType.capsPage.copyWith(
                            color: cv.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                CoveRoundButton(
                  icon: Icons.close,
                  semanticLabel: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: CoveSpace.sm),

            // 2. Progress segments
            AddProgressSegments(
              currentStep: stepNumber,
              totalSteps: totalSteps,
            ),

            // 3. Answered crumbs (hidden after Added)
            if (!_isAdded && crumbs.isNotEmpty) ...[
              const SizedBox(height: CoveSpace.md),
              AddCrumbs(
                crumbs: crumbs,
                onSelectStep: (targetIdx) => _goToStep(targetIdx),
              ),
            ],

            const SizedBox(height: CoveSpace.lg),

            // 4–5. Question heading + Step body (scrolls inside fixed-height sheet)
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('add_flow_step_scroll'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      question,
                      textAlign: TextAlign.center,
                      style: CoveType.title.copyWith(color: cv.textPrimary),
                    ),
                    const SizedBox(height: CoveSpace.lg),
                    _buildStepBody(context, ctx, step),
                    if (_toastMessage != null) ...[
                      const SizedBox(height: CoveSpace.md),
                      _buildToastBanner(context),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: CoveSpace.lg),

            // 6. Step foot (pinned at bottom)
            if (_isAdded)
              AddStepFoot(
                secondaryLabel: 'Add another',
                onSecondaryTap: () => _handleAddAnother(ctx),
                primaryLabel: 'Done',
                showArrow: false,
                enabled: true,
                onPrimaryTap: () => Navigator.of(context).maybePop('added'),
              )
            else if (isReview)
              AddStepFoot(
                visibility: visibility,
                onToggleVisibility: _canToggleVisibility()
                    ? () => _toggleDraftPrivacy(ctx)
                    : null,
                primaryLabel:
                    'Add ${_kindDisplayName(_activeKind!).toLowerCase()}',
                showArrow: false,
                enabled: _draft!.isComplete && !_isSubmitting,
                onPrimaryTap:
                    _isSubmitting ? null : () => _handleCommit(ctx),
              )
            else
              AddStepFoot(
                visibility: visibility,
                onToggleVisibility: _canToggleVisibility()
                    ? () => _toggleDraftPrivacy(ctx)
                    : null,
                primaryLabel: 'Next',
                showArrow: true,
                enabled: _draft!.isAnswered(step),
                onPrimaryTap: () => _advanceStep(ctx),
              ),
          ],
        ),
      ),
    );
  }

  String _kindDisplayName(AddKind kind) {
    switch (kind) {
      case AddKind.event:
        return 'Event';
      case AddKind.expense:
        return 'Expense';
      case AddKind.task:
        return 'Task';
      case AddKind.habit:
        return 'Habit';
      case AddKind.commitment:
        return 'Commitment';
      case AddKind.routine:
        return 'Routine';
    }
  }

  String _questionForStep(AddStep step) {
    switch (step) {
      case AddStep.expenseAmount:
        return 'How much?';
      case AddStep.expenseTitle:
        return 'What for?';
      case AddStep.expenseWhen:
        return 'When?';
      case AddStep.expenseCategory:
        return 'Which category?';
      case AddStep.expenseWhoPaid:
        return 'Who paid?';
      case AddStep.expensePaymentMethod:
        return 'On what?';
      case AddStep.eventTitle:
        return 'What is it?';
      case AddStep.eventDay:
        return 'Which day?';
      case AddStep.eventTime:
        return 'What time?';
      case AddStep.eventLocation:
        return 'Where?';
      case AddStep.taskTitle:
        return 'What needs doing?';
      case AddStep.taskWhichList:
        return 'Which list?';
      case AddStep.taskNameTheList:
        return 'Name the list';
      case AddStep.taskByWhen:
        return 'By when?';
      case AddStep.habitName:
        return 'What is the habit?';
      case AddStep.habitHowOften:
        return 'How often?';
      case AddStep.habitVisibility:
        return 'Who can see it?';
      case AddStep.commitmentName:
        return 'What is it?';
      case AddStep.commitmentAmount:
        return 'How much, each time?';
      case AddStep.commitmentHowOften:
        return 'How often does it come?';
      case AddStep.commitmentEmiTotal:
        return 'How many instalments in all?';
      case AddStep.commitmentEmiPaid:
        return 'How many are paid already?';
      case AddStep.commitmentWhenDue:
        final d = _draft;
        if (d is CommitmentDraft &&
            (d.cycle == CommitmentCycleOption.everyQuarter ||
                d.cycle == CommitmentCycleOption.everyYear)) {
          return 'When is the next one due?';
        }
        return 'Which day of the month?';
      case AddStep.commitmentPaidFrom:
        return 'Paid from?';
      case AddStep.commitmentWhose:
        return 'Whose is it?';
      case AddStep.routineTitle:
        return 'What is it?';
      case AddStep.routineWhen:
        return 'When, usually?';
      case AddStep.routineDuration:
        return 'For how long?';
      case AddStep.routineDays:
        return 'Which days?';
      case AddStep.review:
        return 'Does this look right?';
    }
  }

  CoveSlipVisibility _currentVisibility() {
    final d = _draft;
    if (d is ExpenseDraft && d.isPrivate) {
      return CoveSlipVisibility.onlyYouCanSee;
    }
    if (d is HabitDraft && d.visibility == HabitVisibility.privateToMe) {
      return CoveSlipVisibility.onlyYouCanSee;
    }
    if (d is CommitmentDraft && d.isPrivate) {
      return CoveSlipVisibility.onlyYouCanSee;
    }
    return CoveSlipVisibility.bothCanSee;
  }

  bool _canToggleVisibility() =>
      _draft is ExpenseDraft ||
      _draft is HabitDraft ||
      _draft is CommitmentDraft;

  void _toggleDraftPrivacy(AddFlowContext ctx) {
    final d = _draft;
    if (d is ExpenseDraft) {
      setState(() {
        _draft = d.copyWith(isPrivate: !d.isPrivate);
      });
    } else if (d is HabitDraft) {
      final nextVis = d.visibility == HabitVisibility.privateToMe
          ? HabitVisibility.shared
          : HabitVisibility.privateToMe;
      if (nextVis == HabitVisibility.shared && !ctx.hasPartner) return;
      setState(() {
        _draft = d.copyWith(visibility: nextVis);
      });
    } else if (d is CommitmentDraft) {
      setState(() {
        _draft = d.copyWith(isPrivate: !d.isPrivate);
      });
    }
  }

  List<AddCrumbItem> _buildCrumbsBeforeCurrent(
    AddFlowContext ctx,
    List<AddStep> steps,
  ) {
    final d = _draft;
    if (d == null) return const <AddCrumbItem>[];
    final items = <AddCrumbItem>[];
    for (var i = 0; i < _stepIndex && i < steps.length; i++) {
      final s = steps[i];
      if (!d.isAnswered(s)) continue;
      final label = _crumbLabelForStep(ctx, d, s);
      if (label != null && label.isNotEmpty) {
        items.add(AddCrumbItem(stepIndex: i, label: label));
      }
    }
    return items;
  }

  String? _crumbLabelForStep(AddFlowContext ctx, AddDraft d, AddStep step) {
    final symbol = ref.read(currencyPreferenceProvider).symbol;
    if (d is ExpenseDraft) {
      switch (step) {
        case AddStep.expenseAmount:
          return d.amount != null && d.amount! > 0
              ? '$symbol${formatCoveAmount(d.amount!)}'
              : null;
        case AddStep.expenseTitle:
          return d.title.trim();
        case AddStep.expenseWhen:
          if (d.expenseDate == null) return null;
          return _shortDayCrumb(d.expenseDate!, ctx.today);
        case AddStep.expenseCategory:
          return d.category;
        case AddStep.expenseWhoPaid:
          final payerName = d.payer == ExpensePayer.partner
              ? _partnerName()
              : _viewerName();
          if (d.isPrivate) return '$payerName · private';
          if (d.splitHalfAndHalf) return '$payerName · split';
          return payerName;
        case AddStep.expensePaymentMethod:
          return formatExpensePaymentMethod(d.paymentMethod);
        default:
          return null;
      }
    }
    if (d is EventDraft) {
      switch (step) {
        case AddStep.eventTitle:
          return d.title.trim();
        case AddStep.eventDay:
          if (d.day == null) return null;
          return _shortDayCrumb(d.day!, ctx.today);
        case AddStep.eventTime:
          if (d.isAllDay) return 'All day';
          return _formatHourMinute(d.hour, d.minute);
        case AddStep.eventLocation:
          return d.location?.trim();
        default:
          return null;
      }
    }
    if (d is TaskDraft) {
      switch (step) {
        case AddStep.taskTitle:
          return d.title.trim();
        case AddStep.taskWhichList:
          return _resolveTaskListName(d);
        case AddStep.taskNameTheList:
          return d.newListName?.trim();
        case AddStep.taskByWhen:
          if (d.noParticularDay || d.dueDate == null) {
            return 'No particular day';
          }
          return _shortDayCrumb(d.dueDate!, ctx.today);
        default:
          return null;
      }
    }
    if (d is HabitDraft) {
      switch (step) {
        case AddStep.habitName:
          return d.name.trim();
        case AddStep.habitHowOften:
          return _habitFrequencyCrumb(d);
        case AddStep.habitVisibility:
          return d.visibility == HabitVisibility.privateToMe
              ? 'Only you'
              : 'Both of you';
        default:
          return null;
      }
    }
    if (d is CommitmentDraft) {
      switch (step) {
        case AddStep.commitmentName:
          return d.name.trim();
        case AddStep.commitmentAmount:
          return d.amount != null && d.amount! > 0
              ? '$symbol${formatCoveAmount(d.amount!)}'
              : null;
        case AddStep.commitmentHowOften:
          return _commitmentCycleCrumb(d.cycle);
        case AddStep.commitmentEmiTotal:
          return d.totalInstallments != null
              ? '${d.totalInstallments} instalments'
              : null;
        case AddStep.commitmentEmiPaid:
          return d.paidInstallments != null
              ? '${d.paidInstallments} paid'
              : null;
        case AddStep.commitmentWhenDue:
          if (d.cycle == CommitmentCycleOption.everyQuarter ||
              d.cycle == CommitmentCycleOption.everyYear) {
            final nextDate = d.resolveNextBillingDate(ctx.today);
            return DateFormat('d MMM').format(nextDate);
          }
          final day = d.dayOfMonth ?? ctx.today.day.clamp(1, 28);
          return 'the ${_ordinal(day)}';
        case AddStep.commitmentPaidFrom:
          return (d.paidFrom != null && d.paidFrom!.trim().isNotEmpty)
              ? d.paidFrom!.trim()
              : null;
        case AddStep.commitmentWhose:
          return _commitmentWhoseCrumb(d);
        default:
          return null;
      }
    }
    if (d is RoutineDraft) {
      switch (step) {
        case AddStep.routineTitle:
          return d.title.trim();
        case AddStep.routineWhen:
          final start = (d.startMinutes ?? 540).clamp(0, 1439);
          return _formatHourMinute(start ~/ 60, start % 60);
        case AddStep.routineDuration:
          return _routineDurationCrumb(d.durationMinutes);
        case AddStep.routineDays:
          return routineNameForDays(d.days);
        default:
          return null;
      }
    }
    return null;
  }

  String _commitmentCycleCrumb(CommitmentCycleOption cycle) {
    switch (cycle) {
      case CommitmentCycleOption.everyMonth:
        return 'Every month';
      case CommitmentCycleOption.everyQuarter:
        return 'Every quarter';
      case CommitmentCycleOption.everyYear:
        return 'Every year';
      case CommitmentCycleOption.emi:
        return 'EMI';
    }
  }

  String _commitmentWhoseCrumb(CommitmentDraft d) {
    if (d.isPrivate) return '${_viewerName()} · private';
    switch (d.owner) {
      case CommitmentOwner.you:
        return _viewerName();
      case CommitmentOwner.partner:
        return _partnerName();
      case CommitmentOwner.both:
        return 'Both of you';
    }
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  String? _routineDurationCrumb(int? minutes) {
    if (minutes == null) return null;
    switch (minutes) {
      case 15:
        return '15 min';
      case 30:
        return '30 min';
      case 45:
        return '45 min';
      case 60:
        return '1 hour';
      case 120:
        return '2 hours';
      default:
        return '$minutes min';
    }
  }

  String _resolveTaskListName(TaskDraft d) {
    if (d.newListName != null && d.newListName!.trim().isNotEmpty) {
      return d.newListName!.trim();
    }
    final targetId = d.listId ?? widget.listId;
    final lists = ref.watch(activeHomeListsProvider).value ?? const [];
    final unarchived = lists.where((l) => !l.isArchived).toList();
    if (targetId != null) {
      for (final l in unarchived) {
        if (l.id == targetId) return l.name;
      }
    }
    if (unarchived.length == 1) {
      return unarchived.first.name;
    }
    return 'To Do';
  }

  String? _habitFrequencyCrumb(HabitDraft d) {
    final opt = d.frequencyOption;
    if (opt == null) return null;
    switch (opt) {
      case HabitFrequencyOption.everyDay:
        return 'Every day';
      case HabitFrequencyOption.weekdays:
        return 'Weekdays';
      case HabitFrequencyOption.weekends:
        return 'Weekends';
      case HabitFrequencyOption.pickDays:
        return d.schedule.formatDisplayLabel(targetDays: d.targetDaysPerWeek);
    }
  }

  String _shortDayCrumb(DateTime date, DateTime today) {
    final full = dayLabel(date, today);
    final commaIdx = full.indexOf(',');
    if (commaIdx > 0 &&
        (full.startsWith('Today') ||
            full.startsWith('Yesterday') ||
            full.startsWith('Tomorrow'))) {
      return full.substring(0, commaIdx);
    }
    return full;
  }

  String _viewerName() {
    final profile = ref.watch(userProfileProvider);
    final name = profile.displayName.trim();
    return name.isNotEmpty ? name : 'You';
  }

  String _partnerName() {
    final partner = ref.watch(partnerProfileProvider);
    final name = partner.displayName.trim();
    return name.isNotEmpty ? name : 'Partner';
  }

  String _formatHourMinute(int hour24, int minute) {
    final isPm = hour24 >= 12;
    final h12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final mStr = minute.toString().padLeft(2, '0');
    return '$h12:$mStr ${isPm ? 'PM' : 'AM'}';
  }

  // ==========================================================================
  // 3. STEP BODIES
  // ==========================================================================

  Widget _buildStepBody(
    BuildContext context,
    AddFlowContext ctx,
    AddStep step,
  ) {
    final d = _draft!;
    if (d is ExpenseDraft) {
      return _buildExpenseStepBody(context, ctx, d, step);
    }
    if (d is EventDraft) {
      return _buildEventStepBody(context, ctx, d, step);
    }
    if (d is TaskDraft) {
      return _buildTaskStepBody(context, ctx, d, step);
    }
    if (d is HabitDraft) {
      return _buildHabitStepBody(context, ctx, d, step);
    }
    if (d is CommitmentDraft) {
      return _buildCommitmentStepBody(context, ctx, d, step);
    }
    if (d is RoutineDraft) {
      return _buildRoutineStepBody(context, ctx, d, step);
    }
    return const SizedBox.shrink();
  }

  Widget _buildExpenseStepBody(
    BuildContext context,
    AddFlowContext ctx,
    ExpenseDraft d,
    AddStep step,
  ) {
    switch (step) {
      case AddStep.expenseAmount:
        return AddKeypad(
          value: d.amount ?? 0,
          carriedLine: _againCarriedLine,
          onChanged: (val) {
            setState(() {
              _draft = d.copyWith(amount: val > 0 ? val : null);
            });
          },
        );

      case AddStep.expenseTitle:
        final suggestions = _recentExpenseTitles(ctx.today);
        return _buildTextStepBody(
          context: context,
          ctx: ctx,
          placeholder: 'Type a name',
          suggestions: suggestions,
          optional: false,
          onTextChanged: (text) {
            setState(() {
              _draft = d.copyWith(title: text);
            });
          },
          onPickSuggestion: (suggestion) {
            _textController.text = suggestion;
            setState(() {
              _draft = d.copyWith(title: suggestion);
            });
            _advanceStep(ctx);
          },
        );

      case AddStep.expenseWhen:
        final days = anchoredDays(AddKind.expense, ctx.anchor);
        return AddDayStrip(
          days: days,
          anchorDate: ctx.anchor,
          today: ctx.today,
          selectedDate: d.expenseDate,
          onSelected: (picked) {
            final now = clock.now();
            final isToday = picked.year == ctx.today.year &&
                picked.month == ctx.today.month &&
                picked.day == ctx.today.day;
            final nextDate = isToday
                ? now
                : DateTime(picked.year, picked.month, picked.day);
            setState(() {
              _draft = d.copyWith(expenseDate: nextDate);
            });
            _advanceStep(ctx);
          },
        );

      case AddStep.expenseCategory:
        return _buildExpenseCategoryBody(context, ctx, d);

      case AddStep.expenseWhoPaid:
        return _buildExpenseWhoPaidBody(context, ctx, d);

      case AddStep.expensePaymentMethod:
        final currentVal = d.paymentMethodSkipped ? 'skip' : d.paymentMethod;
        return AddChoiceList<String>(
          selectedValue: currentVal,
          onSelected: (val) {
            setState(() {
              if (val == 'skip') {
                _draft = d.copyWith(
                  paymentMethod: null,
                  paymentMethodSkipped: true,
                );
              } else {
                _draft = d.copyWith(
                  paymentMethod: val,
                  paymentMethodSkipped: false,
                );
              }
            });
            _advanceStep(ctx);
          },
          options: const <AddChoiceOption<String>>[
            AddChoiceOption<String>(value: 'card', label: 'Card'),
            AddChoiceOption<String>(value: 'upi', label: 'UPI'),
            AddChoiceOption<String>(value: 'cash', label: 'Cash'),
            AddChoiceOption<String>(value: 'skip', label: 'Skip'),
          ],
        );

      case AddStep.review:
        return _buildExpenseReviewBody(context, ctx, d);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildExpenseCategoryBody(
    BuildContext context,
    AddFlowContext ctx,
    ExpenseDraft d,
  ) {
    final cv = context.cv;
    final customCategories = ref.watch(customCategoriesProvider);
    final allCategories = <String>[
      ..._defaultCategories,
      for (final c in customCategories)
        if (!_defaultCategories.contains(c)) c,
    ];

    if (_addingNewCategory) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('add_new_category_input'),
            controller: _newCategoryController,
            autofocus: true,
            textAlign: TextAlign.center,
            style: CoveType.title.copyWith(color: cv.textPrimary),
            decoration: InputDecoration(
              hintText: 'Category name',
              hintStyle: CoveType.title.copyWith(color: cv.textTertiary),
              border: InputBorder.none,
            ),
            onSubmitted: (val) async {
              final clean = val.trim();
              if (clean.isEmpty) return;
              await ref
                  .read(customCategoriesProvider.notifier)
                  .addCategory(clean);
              if (!mounted) return;
              setState(() {
                _addingNewCategory = false;
                _draft = d.copyWith(category: clean);
              });
              _advanceStep(ctx);
            },
          ),
          Container(
            height: AddFlow._kInputUnderlineHeight,
            color: cv.accentFill,
          ),
        ],
      );
    }

    return AddChoiceList<String>(
      selectedValue: d.category,
      onSelected: (val) {
        if (val == '__new_category__') {
          _newCategoryController.clear();
          setState(() => _addingNewCategory = true);
          return;
        }
        setState(() {
          _draft = d.copyWith(category: val);
        });
        _advanceStep(ctx);
      },
      options: <AddChoiceOption<String>>[
        for (final cat in allCategories)
          AddChoiceOption<String>(
            value: cat,
            label: cat,
            swatchColor: _categorySwatchColor(cv, cat),
          ),
        const AddChoiceOption<String>(
          value: '__new_category__',
          label: 'New category',
        ),
      ],
    );
  }

  Color _categorySwatchColor(CoveTokens cv, String category) {
    final lower = category.toLowerCase();
    if (lower.contains('grocer')) return cv.categoryGroceries;
    if (lower.contains('eat') || lower.contains('din')) {
      return cv.categoryEatingOut;
    }
    if (lower.contains('fuel')) return cv.categoryFuel;
    if (lower.contains('home')) return cv.categoryHome;
    if (lower.contains('health')) return cv.categoryHealth;
    if (lower.contains('travel')) return cv.categoryTravel;
    if (lower.contains('gift')) return cv.categoryGifts;
    if (lower.contains('pet') || lower.contains('lyla')) return cv.categoryPets;
    return cv.accentFill;
  }

  Widget _buildExpenseWhoPaidBody(
    BuildContext context,
    AddFlowContext ctx,
    ExpenseDraft d,
  ) {
    final viewerName = _viewerName();
    final partnerName = _partnerName();
    final home = ref.watch(activeHomeProvider).value;
    final creatorId = home?.createdBy ?? ctx.viewerUserId;
    final viewerPerson = CoveAvatar.resolvePerson(
      homeCreatedBy: creatorId,
      actorUserId: ctx.viewerUserId,
    );
    final partnerPerson = viewerPerson == CovePerson.a
        ? CovePerson.b
        : CovePerson.a;

    final people = <AddPersonTileData<ExpensePayer>>[
      AddPersonTileData<ExpensePayer>(
        value: ExpensePayer.you,
        person: viewerPerson,
        label: viewerName,
        nameOrInitial: viewerName,
        enabled: true,
      ),
      if (ctx.hasPartner)
        AddPersonTileData<ExpensePayer>(
          value: ExpensePayer.partner,
          person: partnerPerson,
          label: partnerName,
          nameOrInitial: partnerName,
          enabled: !d.isPrivate,
        ),
    ];

    final toggles = <AddToggleRowData>[
      if (ctx.hasPartner)
        AddToggleRowData(
          id: 'split',
          title: 'Split it half and half',
          icon: Icons.call_split,
          value: d.splitHalfAndHalf,
          onChanged: d.canToggleSplit()
              ? (next) {
                  setState(() {
                    _draft = d.copyWith(splitHalfAndHalf: next);
                  });
                }
              : null,
        ),
      AddToggleRowData(
        id: 'private',
        title: 'Keep it private',
        subtitle:
            'Only you will see it — it stays out of $partnerName’s Cove',
        icon: Icons.lock_outline,
        value: d.isPrivate,
        onChanged: (next) {
          setState(() {
            _draft = d.copyWith(isPrivate: next);
          });
        },
      ),
    ];

    return AddPersonPicker<ExpensePayer>(
      people: people,
      selectedValue: d.payer,
      onSelected: (payer) {
        setState(() {
          _draft = d.copyWith(payer: payer);
        });
      },
      toggles: toggles,
    );
  }

  Widget _buildExpenseReviewBody(
    BuildContext context,
    AddFlowContext ctx,
    ExpenseDraft d,
  ) {
    final cv = context.cv;
    final currency = ref.watch(currencyPreferenceProvider);
    final home = ref.watch(activeHomeProvider).value;
    final partnerProfile = ref.watch(partnerProfileProvider);

    final args = d.toCreateArgs(
      viewerUserId: ctx.viewerUserId,
      partnerUserId: ctx.partnerUserId,
      currency: currency.code,
    );
    final splitRatio = args.visibility == ExpenseVisibility.privateToMe
        ? -1.0
        : (args.visibility == ExpenseVisibility.partnerCanSee ? 0.0 : 0.5);

    final previewExpense = LocalExpense(
      id: 'add-expense-${args.title}-${args.amount.round()}',
      homeId: home?.id ?? 'home_1',
      title: args.title,
      amount: args.amount,
      currency: args.currency ?? currency.code,
      paidBy: args.paidBy,
      splitRatio: splitRatio,
      expenseDate: args.expenseDate,
      category: args.category,
      paymentMethod: args.paymentMethod,
      isTransfer: args.isTransfer,
      createdAt: args.expenseDate,
    );

    final fieldTaps = _isAdded
        ? null
        : <CoveSlipField, VoidCallback>{
            CoveSlipField.title: () => _goToStepEnum(
                  AddStep.expenseTitle,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.amount: () => _goToStepEnum(
                  AddStep.expenseAmount,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.category: () => _goToStepEnum(
                  AddStep.expenseCategory,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.paidBy: () => _goToStepEnum(
                  AddStep.expenseWhoPaid,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.paymentMethod: () => _goToStepEnum(
                  AddStep.expensePaymentMethod,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.date: () => _goToStepEnum(
                  AddStep.expenseWhen,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.visibility: () => _goToStepEnum(
                  AddStep.expenseWhoPaid,
                  ctx,
                  fromReviewField: true,
                ),
          };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildExpenseReceipt(
          expense: previewExpense,
          currencySymbol: currency.symbol,
          currentUserId: ctx.viewerUserId,
          homeCreatedBy: home?.createdBy,
          partnerDisplayName: partnerProfile.displayName,
          viewerDisplayName: _viewerName(),
          visibility: _currentVisibility(),
          stamp: _isAdded ? 'ADDED' : null,
          fieldTaps: fieldTaps,
        ),
        if (!_isAdded) ...[
          const SizedBox(height: CoveSpace.md),
          Text(
            'Tap anything above to change it.',
            textAlign: TextAlign.center,
            style: CoveType.rowSub.copyWith(color: cv.textTertiary),
          ),
        ],
      ],
    );
  }

  Widget _buildEventStepBody(
    BuildContext context,
    AddFlowContext ctx,
    EventDraft d,
    AddStep step,
  ) {
    switch (step) {
      case AddStep.eventTitle:
        final suggestions = _recentEventTitles(ctx.today);
        return _buildTextStepBody(
          context: context,
          ctx: ctx,
          placeholder: 'Type a name',
          suggestions: suggestions,
          optional: false,
          onTextChanged: (text) {
            setState(() {
              _draft = d.copyWith(title: text);
            });
          },
          onPickSuggestion: (suggestion) {
            _textController.text = suggestion;
            setState(() {
              _draft = d.copyWith(title: suggestion);
            });
            _advanceStep(ctx);
          },
        );

      case AddStep.eventDay:
        final days = anchoredDays(AddKind.event, ctx.anchor);
        return AddDayStrip(
          days: days,
          anchorDate: ctx.anchor,
          today: ctx.today,
          selectedDate: d.day,
          carriedLine: _againCarriedLine,
          onSelected: (picked) {
            setState(() {
              _draft = d.copyWith(day: picked);
            });
            _advanceStep(ctx);
          },
        );

      case AddStep.eventTime:
        return AddClockFace(
          hour: d.hour,
          minute: d.minute,
          showAllDay: true,
          isAllDay: d.isAllDay,
          onChanged: (h, m) {
            setState(() {
              _draft = d.copyWith(hour: h, minute: m, isAllDay: false);
            });
          },
          onAllDayChanged: (allDay) {
            setState(() {
              _draft = d.copyWith(isAllDay: allDay);
            });
          },
        );

      case AddStep.eventLocation:
        return _buildTextStepBody(
          context: context,
          ctx: ctx,
          placeholder: 'Type a place',
          suggestions: const <String>[],
          optional: true,
          onTextChanged: (text) {
            setState(() {
              _draft = d.copyWith(
                location: text,
                locationSkipped: false,
              );
            });
          },
          onPickSuggestion: (_) {},
          onSkip: () {
            _textController.clear();
            setState(() {
              _draft = d.copyWith(
                location: null,
                locationSkipped: true,
              );
            });
            _advanceStep(ctx);
          },
        );

      case AddStep.review:
        return _buildEventReviewBody(context, ctx, d);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEventReviewBody(
    BuildContext context,
    AddFlowContext ctx,
    EventDraft d,
  ) {
    final cv = context.cv;
    final eventDay = d.day ?? ctx.anchor;
    final dateFormatted = dayLabel(eventDay, ctx.today);
    final isPm = d.hour >= 12;
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mStr = d.minute.toString().padLeft(2, '0');
    final hourDisplay = d.isAllDay ? 'ALL' : '$h12:$mStr';
    final meridiemDisplay = d.isAllDay ? 'DAY' : (isPm ? 'PM' : 'AM');

    final fieldTaps = _isAdded
        ? null
        : <CoveSlipField, VoidCallback>{
            CoveSlipField.title: () => _goToStepEnum(
                  AddStep.eventTitle,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.location: () => _goToStepEnum(
                  AddStep.eventLocation,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.date: () => _goToStepEnum(
                  AddStep.eventDay,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.time: () => _goToStepEnum(
                  AddStep.eventTime,
                  ctx,
                  fromReviewField: true,
                ),
          };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoveTicket(
          variant: CoveSlipVariant.paper,
          title: d.title.trim(),
          location: (d.location != null && d.location!.trim().isNotEmpty)
              ? 'at ${d.location!.trim()}'
              : 'Add location',
          date: dateFormatted,
          owner: 'Both of you',
          hour: hourDisplay,
          meridiem: meridiemDisplay,
          visibility: CoveSlipVisibility.bothCanSee,
          stamp: _isAdded ? 'ADDED' : null,
          fieldTaps: fieldTaps,
        ),
        if (!_isAdded) ...[
          const SizedBox(height: CoveSpace.md),
          Text(
            'Tap anything above to change it.',
            textAlign: TextAlign.center,
            style: CoveType.rowSub.copyWith(color: cv.textTertiary),
          ),
        ],
      ],
    );
  }

  Widget _buildTaskStepBody(
    BuildContext context,
    AddFlowContext ctx,
    TaskDraft d,
    AddStep step,
  ) {
    switch (step) {
      case AddStep.taskTitle:
        final suggestions = _recentTaskTitles();
        return _buildTextStepBody(
          context: context,
          ctx: ctx,
          placeholder: 'Type a task',
          suggestions: suggestions,
          optional: false,
          onTextChanged: (text) {
            setState(() {
              _draft = d.copyWith(title: text);
            });
          },
          onPickSuggestion: (suggestion) {
            _textController.text = suggestion;
            setState(() {
              _draft = d.copyWith(title: suggestion);
            });
            _advanceStep(ctx);
          },
        );

      case AddStep.taskWhichList:
        final lists = ref.watch(activeHomeListsProvider).value ?? const [];
        final unarchived = lists.where((l) => !l.isArchived).toList();
        return AddChoiceList<String>(
          selectedValue: d.listId,
          onSelected: (listId) {
            setState(() {
              _draft = d.copyWith(listId: listId);
            });
            _advanceStep(ctx);
          },
          options: <AddChoiceOption<String>>[
            for (final list in unarchived)
              AddChoiceOption<String>(
                value: list.id,
                label: list.name,
              ),
          ],
        );

      case AddStep.taskNameTheList:
        return _buildTextStepBody(
          context: context,
          ctx: ctx,
          placeholder: 'Type a list name',
          suggestions: const <String>[],
          optional: false,
          onTextChanged: (text) {
            setState(() {
              _draft = d.copyWith(newListName: text);
            });
          },
          onPickSuggestion: (_) {},
        );

      case AddStep.taskByWhen:
        final days = anchoredDays(AddKind.task, ctx.anchor);
        return AddDayStrip(
          days: days,
          anchorDate: ctx.anchor,
          today: ctx.today,
          selectedDate: d.noParticularDay ? null : d.dueDate,
          showNoParticularDay: true,
          isNoParticularDaySelected: d.noParticularDay,
          carriedLine: _againCarriedLine,
          onSelected: (picked) {
            setState(() {
              _draft = d.copyWith(
                dueDate: picked,
                noParticularDay: false,
              );
            });
            _advanceStep(ctx);
          },
          onSelectNoParticularDay: () {
            setState(() {
              _draft = d.copyWith(
                dueDate: null,
                noParticularDay: true,
              );
            });
            _advanceStep(ctx);
          },
        );

      case AddStep.review:
        return _buildTaskReviewBody(context, ctx, d);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTaskReviewBody(
    BuildContext context,
    AddFlowContext ctx,
    TaskDraft d,
  ) {
    final cv = context.cv;
    final listName = _resolveTaskListName(d);
    final dueLine = (d.noParticularDay || d.dueDate == null)
        ? 'No particular day'
        : 'By ${dayLabel(d.dueDate!, ctx.today)}';
    final steps = _currentSteps(ctx);

    final fieldTaps = _isAdded
        ? null
        : <CoveSlipField, VoidCallback>{
            CoveSlipField.title: () => _goToStepEnum(
                  AddStep.taskTitle,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.dueDate: () => _goToStepEnum(
                  AddStep.taskByWhen,
                  ctx,
                  fromReviewField: true,
                ),
            if (steps.contains(AddStep.taskWhichList))
              CoveSlipField.list: () => _goToStepEnum(
                    AddStep.taskWhichList,
                    ctx,
                    fromReviewField: true,
                  )
            else if (steps.contains(AddStep.taskNameTheList))
              CoveSlipField.list: () => _goToStepEnum(
                    AddStep.taskNameTheList,
                    ctx,
                    fromReviewField: true,
                  ),
          };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoveNote(
          variant: CoveSlipVariant.paper,
          capsLabel: 'COVE · ${listName.toUpperCase()}',
          items: <CoveNoteItem>[
            CoveNoteItem(
              title: d.title.trim(),
              addedBy: dueLine,
              isDone: false,
            ),
          ],
          visibility: CoveSlipVisibility.bothCanSee,
          stamp: _isAdded ? 'ADDED' : null,
          fieldTaps: fieldTaps,
        ),
        if (!_isAdded) ...[
          const SizedBox(height: CoveSpace.md),
          Text(
            'Tap anything above to change it.',
            textAlign: TextAlign.center,
            style: CoveType.rowSub.copyWith(color: cv.textTertiary),
          ),
        ],
      ],
    );
  }

  Widget _buildHabitStepBody(
    BuildContext context,
    AddFlowContext ctx,
    HabitDraft d,
    AddStep step,
  ) {
    switch (step) {
      case AddStep.habitName:
        final suggestions = _recentHabitNames();
        return _buildTextStepBody(
          context: context,
          ctx: ctx,
          placeholder: 'Type a habit',
          suggestions: suggestions,
          optional: false,
          onTextChanged: (text) {
            setState(() {
              _draft = d.copyWith(name: text);
            });
          },
          onPickSuggestion: (suggestion) {
            _textController.text = suggestion;
            setState(() {
              _draft = d.copyWith(name: suggestion);
            });
            _advanceStep(ctx);
          },
        );

      case AddStep.habitHowOften:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AddChoiceList<HabitFrequencyOption>(
              selectedValue: d.frequencyOption,
              onSelected: (opt) {
                setState(() {
                  _draft = d.copyWith(frequencyOption: opt);
                });
                if (opt != HabitFrequencyOption.pickDays) {
                  _advanceStep(ctx);
                }
              },
              options: const <AddChoiceOption<HabitFrequencyOption>>[
                AddChoiceOption<HabitFrequencyOption>(
                  value: HabitFrequencyOption.everyDay,
                  label: 'Every day',
                ),
                AddChoiceOption<HabitFrequencyOption>(
                  value: HabitFrequencyOption.weekdays,
                  label: 'Weekdays',
                ),
                AddChoiceOption<HabitFrequencyOption>(
                  value: HabitFrequencyOption.weekends,
                  label: 'Weekends',
                ),
                AddChoiceOption<HabitFrequencyOption>(
                  value: HabitFrequencyOption.pickDays,
                  label: 'Pick the days',
                ),
              ],
            ),
            if (d.frequencyOption == HabitFrequencyOption.pickDays) ...[
              const SizedBox(height: CoveSpace.lg),
              AddWeekToggles(
                selectedDays: d.customDays,
                onChanged: (days) {
                  setState(() {
                    _draft = d.copyWith(customDays: days);
                  });
                },
              ),
            ],
          ],
        );

      case AddStep.habitVisibility:
        final options = <AddChoiceOption<HabitVisibility>>[
          if (ctx.hasPartner)
            const AddChoiceOption<HabitVisibility>(
              value: HabitVisibility.shared,
              label: 'Both of you',
            ),
          const AddChoiceOption<HabitVisibility>(
            value: HabitVisibility.privateToMe,
            label: 'Only you',
          ),
        ];
        return AddChoiceList<HabitVisibility>(
          selectedValue: d.visibility,
          onSelected: (vis) {
            setState(() {
              _draft = d.copyWith(visibility: vis);
            });
            _advanceStep(ctx);
          },
          options: options,
        );

      case AddStep.review:
        return _buildHabitReviewBody(context, ctx, d);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHabitReviewBody(
    BuildContext context,
    AddFlowContext ctx,
    HabitDraft d,
  ) {
    final cv = context.cv;
    final cadenceLabel = d.schedule.formatDisplayLabel(
      targetDays: d.targetDaysPerWeek,
    );
    final isPrivate = d.visibility == HabitVisibility.privateToMe;
    final String slipCadenceLine;
    if (isPrivate) {
      slipCadenceLine = '$cadenceLabel · Yours alone';
    } else {
      slipCadenceLine = ctx.hasPartner
          ? '$cadenceLabel · Shared with ${_partnerName()}'
          : '$cadenceLabel · Created by you';
    }

    final fieldTaps = _isAdded
        ? null
        : <CoveSlipField, VoidCallback>{
            CoveSlipField.title: () => _goToStepEnum(
                  AddStep.habitName,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.cadence: () => _goToStepEnum(
                  AddStep.habitHowOften,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.visibility: () => _goToStepEnum(
                  AddStep.habitVisibility,
                  ctx,
                  fromReviewField: true,
                ),
          };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoveHabitCard(
          variant: CoveSlipVariant.paper,
          title: d.name.trim(),
          cadence: slipCadenceLine,
          isDoneToday: false,
          daysRunning: 0,
          showCheckbox: false,
          showHistory: false,
          visibility: _currentVisibility(),
          stamp: _isAdded ? 'ADDED' : null,
          fieldTaps: fieldTaps,
        ),
        if (!_isAdded) ...[
          const SizedBox(height: CoveSpace.md),
          Text(
            'Tap anything above to change it.',
            textAlign: TextAlign.center,
            style: CoveType.rowSub.copyWith(color: cv.textTertiary),
          ),
        ],
      ],
    );
  }

  Widget _buildCommitmentStepBody(
    BuildContext context,
    AddFlowContext ctx,
    CommitmentDraft d,
    AddStep step,
  ) {
    switch (step) {
      case AddStep.commitmentName:
        final suggestions = _recentCommitmentNames();
        return _buildTextStepBody(
          context: context,
          ctx: ctx,
          placeholder: 'Type a name',
          suggestions: suggestions,
          optional: false,
          onTextChanged: (text) {
            setState(() {
              _draft = d.copyWith(name: text);
            });
          },
          onPickSuggestion: (suggestion) {
            _textController.text = suggestion;
            setState(() {
              _draft = d.copyWith(name: suggestion);
            });
            _advanceStep(ctx);
          },
        );

      case AddStep.commitmentAmount:
        return AddKeypad(
          value: d.amount ?? 0,
          showCurrencySymbol: true,
          onChanged: (val) {
            setState(() {
              _draft = d.copyWith(amount: val > 0 ? val : null);
            });
          },
        );

      case AddStep.commitmentHowOften:
        return AddChoiceList<CommitmentCycleOption>(
          selectedValue: d.cycle,
          onSelected: (cycle) {
            setState(() {
              _draft = d.copyWith(cycle: cycle);
            });
            _advanceStep(ctx);
          },
          options: const <AddChoiceOption<CommitmentCycleOption>>[
            AddChoiceOption<CommitmentCycleOption>(
              value: CommitmentCycleOption.everyMonth,
              label: 'Every month',
              subtitle: 'twelve times a year',
            ),
            AddChoiceOption<CommitmentCycleOption>(
              value: CommitmentCycleOption.everyQuarter,
              label: 'Every quarter',
              subtitle: 'four times a year',
            ),
            AddChoiceOption<CommitmentCycleOption>(
              value: CommitmentCycleOption.everyYear,
              label: 'Every year',
              subtitle: 'once, on a date',
            ),
            AddChoiceOption<CommitmentCycleOption>(
              value: CommitmentCycleOption.emi,
              label: 'It ends — an EMI',
              subtitle: 'a number of instalments',
            ),
          ],
        );

      case AddStep.commitmentEmiTotal:
        return AddKeypad(
          value: d.totalInstallments ?? 0,
          showCurrencySymbol: false,
          onChanged: (val) {
            setState(() {
              _draft = d.copyWith(
                totalInstallments: val >= 1 ? val : null,
              );
            });
          },
        );

      case AddStep.commitmentEmiPaid:
        return AddKeypad(
          value: d.paidInstallments ?? 0,
          showCurrencySymbol: false,
          onChanged: (val) {
            setState(() {
              _draft = d.copyWith(paidInstallments: val);
            });
          },
        );

      case AddStep.commitmentWhenDue:
        if (d.cycle == CommitmentCycleOption.everyQuarter ||
            d.cycle == CommitmentCycleOption.everyYear) {
          return AddNextDatePicker(
            today: ctx.today,
            selectedMonth: (d.dueMonth ?? ctx.today.month).clamp(1, 12),
            selectedDay: (d.dayOfMonth ?? ctx.today.day).clamp(1, 28),
            showHint: false,
            onChanged: (month, day, resolvedDate) {
              setState(() {
                _draft = d.copyWith(
                  dueMonth: month,
                  dayOfMonth: day,
                  nextDueDate: resolvedDate,
                );
              });
            },
          );
        }
        return AddMonthDayGrid(
          selectedDay: d.dayOfMonth,
          onSelected: (day) {
            setState(() {
              _draft = d.copyWith(dayOfMonth: day);
            });
            _advanceStep(ctx);
          },
        );

      case AddStep.commitmentPaidFrom:
        final suggestions = _existingFinancedThroughValues();
        return _buildTextStepBody(
          context: context,
          ctx: ctx,
          placeholder: 'Type an account or card',
          suggestions: suggestions,
          optional: true,
          onTextChanged: (text) {
            setState(() {
              _draft = d.copyWith(
                paidFrom: text,
                paidFromSkipped: false,
              );
            });
          },
          onPickSuggestion: (suggestion) {
            _textController.text = suggestion;
            setState(() {
              _draft = d.copyWith(
                paidFrom: suggestion,
                paidFromSkipped: false,
              );
            });
            _advanceStep(ctx);
          },
          onSkip: () {
            _textController.clear();
            setState(() {
              _draft = d.copyWith(
                paidFrom: null,
                paidFromSkipped: true,
              );
            });
            _advanceStep(ctx);
          },
        );

      case AddStep.commitmentWhose:
        return _buildCommitmentWhoseBody(context, ctx, d);

      case AddStep.review:
        return _buildCommitmentReviewBody(context, ctx, d);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCommitmentWhoseBody(
    BuildContext context,
    AddFlowContext ctx,
    CommitmentDraft d,
  ) {
    final viewerName = _viewerName();
    final partnerName = _partnerName();
    final home = ref.watch(activeHomeProvider).value;
    final creatorId = home?.createdBy ?? ctx.viewerUserId;
    final viewerPerson = CoveAvatar.resolvePerson(
      homeCreatedBy: creatorId,
      actorUserId: ctx.viewerUserId,
    );
    final partnerPerson = viewerPerson == CovePerson.a
        ? CovePerson.b
        : CovePerson.a;

    final people = <AddPersonTileData<CommitmentOwner>>[
      AddPersonTileData<CommitmentOwner>(
        value: CommitmentOwner.you,
        person: viewerPerson,
        label: viewerName,
        nameOrInitial: viewerName,
        enabled: true,
      ),
      if (ctx.hasPartner) ...[
        AddPersonTileData<CommitmentOwner>(
          value: CommitmentOwner.partner,
          person: partnerPerson,
          label: partnerName,
          nameOrInitial: partnerName,
          enabled: !d.isPrivate,
        ),
        AddPersonTileData<CommitmentOwner>(
          value: CommitmentOwner.both,
          person: CovePerson.both,
          label: 'Both of you',
          enabled: !d.isPrivate,
        ),
      ],
    ];

    final toggles = <AddToggleRowData>[
      AddToggleRowData(
        id: 'private',
        title: 'Keep it private',
        subtitle: ctx.hasPartner
            ? 'Only you will see it — it stays out of $partnerName’s Cove'
            : 'Only you will see it',
        icon: Icons.lock_outline,
        value: d.isPrivate,
        onChanged: (next) {
          setState(() {
            _draft = d.copyWith(isPrivate: next);
          });
        },
      ),
    ];

    return AddPersonPicker<CommitmentOwner>(
      people: people,
      selectedValue: d.owner,
      onSelected: (owner) {
        setState(() {
          _draft = d.copyWith(owner: owner);
        });
      },
      toggles: toggles,
    );
  }

  Widget _buildCommitmentReviewBody(
    BuildContext context,
    AddFlowContext ctx,
    CommitmentDraft d,
  ) {
    final cv = context.cv;
    final currency = ref.watch(currencyPreferenceProvider);
    final nextDate = d.resolveNextBillingDate(ctx.today);
    final formattedAmount =
        '${currency.symbol}${formatCoveAmount((d.amount ?? 0).toDouble())}';
    final cleanPaidFrom =
        (d.paidFrom != null && d.paidFrom!.trim().isNotEmpty)
            ? d.paidFrom!.trim()
            : null;
    final whoseLabel = _commitmentReviewWhoseLabel(d);

    final fieldTaps = _isAdded
        ? null
        : <CoveSlipField, VoidCallback>{
            CoveSlipField.title: () => _goToStepEnum(
                  AddStep.commitmentName,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.amount: () => _goToStepEnum(
                  AddStep.commitmentAmount,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.cadence: () => _goToStepEnum(
                  AddStep.commitmentHowOften,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.dueDate: () => _goToStepEnum(
                  AddStep.commitmentWhenDue,
                  ctx,
                  fromReviewField: true,
                ),
            if (d.isEmi)
              CoveSlipField.installments: () => _goToStepEnum(
                    AddStep.commitmentEmiTotal,
                    ctx,
                    fromReviewField: true,
                  ),
            if (cleanPaidFrom != null)
              CoveSlipField.paidFrom: () => _goToStepEnum(
                    AddStep.commitmentPaidFrom,
                    ctx,
                    fromReviewField: true,
                  ),
            CoveSlipField.owner: () => _goToStepEnum(
                  AddStep.commitmentWhose,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.visibility: () => _goToStepEnum(
                  AddStep.commitmentWhose,
                  ctx,
                  fromReviewField: true,
                ),
          };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoveVoucher(
          variant: CoveSlipVariant.paper,
          title: d.name.trim(),
          amount: formattedAmount,
          dueDay: DateFormat('d').format(nextDate),
          dueMonth: DateFormat('MMM').format(nextDate).toUpperCase(),
          dueMonthSemantic: DateFormat('MMMM').format(nextDate),
          capsLabel: 'COVE · ${_commitmentCapsCadence(d.cycle)}',
          cadenceSuffix: _commitmentCadenceSuffix(d.cycle),
          state: CoveVoucherState.due,
          totalInstallments: d.isEmi ? d.totalInstallments : null,
          paidInstallments: d.isEmi ? (d.paidInstallments ?? 0) : 0,
          paidFrom: cleanPaidFrom,
          whose: whoseLabel,
          visibility: _currentVisibility(),
          stamp: _isAdded ? 'ADDED' : null,
          fieldTaps: fieldTaps,
        ),
        if (!_isAdded) ...[
          const SizedBox(height: CoveSpace.md),
          Text(
            'Tap anything above to change it.',
            textAlign: TextAlign.center,
            style: CoveType.rowSub.copyWith(color: cv.textTertiary),
          ),
        ],
      ],
    );
  }

  String _commitmentCapsCadence(CommitmentCycleOption cycle) {
    switch (cycle) {
      case CommitmentCycleOption.everyMonth:
      case CommitmentCycleOption.emi:
        return 'EVERY MONTH';
      case CommitmentCycleOption.everyQuarter:
        return 'EVERY QUARTER';
      case CommitmentCycleOption.everyYear:
        return 'EVERY YEAR';
    }
  }

  String _commitmentCadenceSuffix(CommitmentCycleOption cycle) {
    switch (cycle) {
      case CommitmentCycleOption.everyMonth:
      case CommitmentCycleOption.emi:
        return 'a month';
      case CommitmentCycleOption.everyQuarter:
        return 'a quarter';
      case CommitmentCycleOption.everyYear:
        return 'a year';
    }
  }

  String _commitmentReviewWhoseLabel(CommitmentDraft d) {
    if (d.isPrivate) return _viewerName();
    switch (d.owner) {
      case CommitmentOwner.you:
        return _viewerName();
      case CommitmentOwner.partner:
        return _partnerName();
      case CommitmentOwner.both:
        return 'Both of you';
    }
  }

  Widget _buildRoutineStepBody(
    BuildContext context,
    AddFlowContext ctx,
    RoutineDraft d,
    AddStep step,
  ) {
    switch (step) {
      case AddStep.routineTitle:
        final suggestions = _recentRoutineEventTitles();
        return _buildTextStepBody(
          context: context,
          ctx: ctx,
          placeholder: 'Type a routine',
          suggestions: suggestions,
          optional: false,
          onTextChanged: (text) {
            setState(() {
              _draft = d.copyWith(title: text);
            });
          },
          onPickSuggestion: (suggestion) {
            _textController.text = suggestion;
            setState(() {
              _draft = d.copyWith(title: suggestion);
            });
            _advanceStep(ctx);
          },
        );

      case AddStep.routineWhen:
        final start = (d.startMinutes ?? 540).clamp(0, 1439);
        return AddClockFace(
          hour: start ~/ 60,
          minute: start % 60,
          showAllDay: false,
          onChanged: (h, m) {
            setState(() {
              _draft = d.copyWith(startMinutes: h * 60 + m);
            });
          },
        );

      case AddStep.routineDuration:
        return AddChoiceList<int>(
          selectedValue: d.durationMinutes,
          onSelected: (mins) {
            setState(() {
              _draft = d.copyWith(durationMinutes: mins);
            });
            _advanceStep(ctx);
          },
          options: const <AddChoiceOption<int>>[
            AddChoiceOption<int>(value: 15, label: '15 min'),
            AddChoiceOption<int>(value: 30, label: '30 min'),
            AddChoiceOption<int>(value: 45, label: '45 min'),
            AddChoiceOption<int>(value: 60, label: '1 hour'),
            AddChoiceOption<int>(value: 120, label: '2 hours'),
          ],
        );

      case AddStep.routineDays:
        return AddWeekToggles(
          selectedDays: d.days,
          onChanged: (days) {
            setState(() {
              _draft = d.copyWith(days: days);
            });
          },
        );

      case AddStep.review:
        return _buildRoutineReviewBody(context, ctx, d);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildRoutineReviewBody(
    BuildContext context,
    AddFlowContext ctx,
    RoutineDraft d,
  ) {
    final cv = context.cv;
    final start = (d.startMinutes ?? 540).clamp(0, 1439);
    final end = d.resolvedEndMinutes;

    final fieldTaps = _isAdded
        ? null
        : <CoveSlipField, VoidCallback>{
            CoveSlipField.title: () => _goToStepEnum(
                  AddStep.routineTitle,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.duration: () => _goToStepEnum(
                  AddStep.routineDuration,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.days: () => _goToStepEnum(
                  AddStep.routineDays,
                  ctx,
                  fromReviewField: true,
                ),
            CoveSlipField.time: () => _goToStepEnum(
                  AddStep.routineWhen,
                  ctx,
                  fromReviewField: true,
                ),
          };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoveBand(
          variant: CoveSlipVariant.paper,
          title: d.title.trim(),
          startMinutes: start,
          endMinutes: end,
          days: d.days,
          visibility: CoveSlipVisibility.bothCanSee,
          stamp: _isAdded ? 'ADDED' : null,
          fieldTaps: fieldTaps,
        ),
        if (!_isAdded) ...[
          const SizedBox(height: CoveSpace.md),
          Text(
            'Tap anything above to change it.',
            textAlign: TextAlign.center,
            style: CoveType.rowSub.copyWith(color: cv.textTertiary),
          ),
        ],
      ],
    );
  }

  Widget _buildTextStepBody({
    required BuildContext context,
    required AddFlowContext ctx,
    required String placeholder,
    required List<String> suggestions,
    required bool optional,
    required ValueChanged<String> onTextChanged,
    required ValueChanged<String> onPickSuggestion,
    VoidCallback? onSkip,
  }) {
    final cv = context.cv;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('add_flow_text_input'),
          controller: _textController,
          autofocus: true,
          textAlign: TextAlign.center,
          style: CoveType.title.copyWith(color: cv.textPrimary),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: CoveType.title.copyWith(color: cv.textTertiary),
            border: InputBorder.none,
          ),
          onChanged: onTextChanged,
          onSubmitted: (_) {
            final step = _currentStep(ctx);
            if (step != null && _draft!.isAnswered(step)) {
              _advanceStep(ctx);
            }
          },
        ),
        Container(
          height: AddFlow._kInputUnderlineHeight,
          color: cv.accentFill,
        ),
        if (suggestions.isNotEmpty || optional) ...[
          const SizedBox(height: CoveSpace.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: CoveSpace.sm,
            runSpacing: CoveSpace.sm,
            children: [
              for (final s in suggestions)
                _SuggestionChip(
                  label: s,
                  onTap: () => onPickSuggestion(s),
                ),
              if (optional && onSkip != null)
                _SuggestionChip(
                  label: 'Skip',
                  onTap: onSkip,
                ),
            ],
          ),
        ],
      ],
    );
  }

  List<String> _recentExpenseTitles(DateTime today) {
    final expenses = ref.watch(activeHomeExpensesProvider).value ?? const [];
    final cutoff = today.subtract(const Duration(days: 90));
    final counts = <String, int>{};
    final canonical = <String, String>{};
    for (final e in expenses) {
      if (e.isTransfer || e.expenseDate.isBefore(cutoff)) continue;
      final t = e.title.trim();
      if (t.isEmpty) continue;
      final key = t.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
      canonical.putIfAbsent(key, () => t);
    }
    final sortedKeys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sortedKeys.take(5).map((k) => canonical[k]!).toList();
  }

  List<String> _recentEventTitles(DateTime today) {
    final events =
        ref.watch(activeHomeCalendarEventsProvider).value ?? const [];
    final cutoff = today.subtract(const Duration(days: 90));
    final counts = <String, int>{};
    final canonical = <String, String>{};
    for (final e in events) {
      if (e.startTime.isBefore(cutoff)) continue;
      final t = e.title.trim();
      if (t.isEmpty) continue;
      final key = t.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
      canonical.putIfAbsent(key, () => t);
    }
    final sortedKeys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sortedKeys.take(5).map((k) => canonical[k]!).toList();
  }

  List<String> _recentTaskTitles() {
    final items =
        ref.watch(activeHomeAllListItemsProvider).value ?? const [];
    final counts = <String, int>{};
    final canonical = <String, String>{};
    for (final item in items) {
      final t = item.title.trim();
      if (t.isEmpty) continue;
      final key = t.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
      canonical.putIfAbsent(key, () => t);
    }
    final sortedKeys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sortedKeys.take(5).map((k) => canonical[k]!).toList();
  }

  List<String> _recentHabitNames() {
    final habits = ref.watch(activeHomeHabitsProvider).value ?? const [];
    final seen = <String>{};
    final result = <String>[];
    for (final h in habits) {
      if (h.isArchived) continue;
      final t = h.name.trim();
      if (t.isEmpty) continue;
      if (seen.add(t.toLowerCase())) {
        result.add(t);
        if (result.length >= 5) break;
      }
    }
    return result;
  }

  List<String> _recentCommitmentNames() {
    final subs = ref.watch(activeHomeSubscriptionsProvider).value ?? const [];
    final seen = <String>{};
    final result = <String>[];
    for (final s in subs) {
      if (!s.isActive) continue;
      final t = s.name.trim();
      if (t.isEmpty) continue;
      if (seen.add(t.toLowerCase())) {
        result.add(t);
        if (result.length >= 5) break;
      }
    }
    return result;
  }

  List<String> _existingFinancedThroughValues() {
    final subs = ref.watch(activeHomeSubscriptionsProvider).value ?? const [];
    final counts = <String, int>{};
    final canonical = <String, String>{};
    for (final s in subs) {
      final ft = s.financedThrough?.trim();
      if (ft == null || ft.isEmpty) continue;
      final key = ft.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
      canonical.putIfAbsent(key, () => ft);
    }
    final sortedKeys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sortedKeys.take(5).map((k) => canonical[k]!).toList();
  }

  List<String> _recentRoutineEventTitles() {
    final events =
        ref.watch(activeHomeAllRoutineEventsProvider).value ?? const [];
    final seen = <String>{};
    final result = <String>[];
    for (final e in events) {
      final t = e.title.trim();
      if (t.isEmpty) continue;
      if (seen.add(t.toLowerCase())) {
        result.add(t);
        if (result.length >= 5) break;
      }
    }
    return result;
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  static const double _kBorderWidth = 1.0; // (literal) 1dp chip border

  const _SuggestionChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: CoveSize.hit,
              minHeight: CoveSize.hit,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.gutter,
              vertical: CoveSpace.sm,
            ),
            decoration: CoveShape.decoration(
              CoveRadius.pill,
              color: cv.surfaceRow,
              side: BorderSide(
                color: cv.lineStrong,
                width: _kBorderWidth,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: CoveType.rowTitle.copyWith(color: cv.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
