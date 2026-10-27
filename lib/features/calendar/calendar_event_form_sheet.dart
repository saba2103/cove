import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_avatar.dart';
import '../../core/widgets/cove_page_header.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../../core/widgets/cove_undo_toast.dart';
import '../../sync/db/app_database.dart';
import '../../sync/pending_delete_service.dart';
import '../../sync/providers/active_home_provider.dart';
import '../add/widgets/add_person_picker.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/user_profile_controller.dart';
import 'calendar_controller.dart';

class CalendarEventFormSheet extends ConsumerStatefulWidget {
  final LocalCalendarEvent? existing;
  final DateTime? initialDate;

  const CalendarEventFormSheet({
    super.key,
    this.existing,
    this.initialDate,
  });

  static Future<void> show(
    BuildContext context, {
    LocalCalendarEvent? existing,
    DateTime? initialDate,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CalendarEventFormSheet(
        existing: existing,
        initialDate: initialDate,
      ),
    );
  }

  @override
  ConsumerState<CalendarEventFormSheet> createState() =>
      _CalendarEventFormSheetState();
}

class _CalendarEventFormSheetState
    extends ConsumerState<CalendarEventFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  late bool _isAllDay;
  String _recurrence = 'none';
  late String _owner;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    final baseDate = item?.startTime ?? widget.initialDate ?? clock.now();

    _titleController = TextEditingController(text: item?.title ?? '');
    _locationController = TextEditingController(text: item?.location ?? '');
    _descriptionController =
        TextEditingController(text: item?.description ?? '');

    _isAllDay = item?.isAllDay ?? false;
    _recurrence = item?.recurrence ?? 'none';
    _owner = (item?.owner != null && item!.owner!.trim().isNotEmpty)
        ? item.owner!.trim()
        : 'both';
    _startDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    _startTime = TimeOfDay(hour: baseDate.hour, minute: baseDate.minute);

    final endBase = item?.endTime ?? baseDate.add(const Duration(hours: 1));
    _endDate = DateTime(endBase.year, endBase.month, endBase.day);
    _endTime = TimeOfDay(hour: endBase.hour, minute: endBase.minute);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final cv = context.cv;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: (isDark
                    ? const ColorScheme.dark()
                    : const ColorScheme.light())
                .copyWith(
              primary: cv.accentFill,
              onPrimary: cv.textOnAccent,
              surface: cv.surfaceCard,
              onSurface: cv.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final cv = context.cv;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: (isDark
                    ? const ColorScheme.dark()
                    : const ColorScheme.light())
                .copyWith(
              primary: cv.accentFill,
              onPrimary: cv.textOnAccent,
              surface: cv.surfaceCard,
              onSurface: cv.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please enter an event title.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _isAllDay ? 0 : _startTime.hour,
      _isAllDay ? 0 : _startTime.minute,
    );

    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _isAllDay ? 23 : _endTime.hour,
      _isAllDay ? 59 : _endTime.minute,
    );

    try {
      final controller = ref.read(calendarControllerProvider);
      final recValue = _recurrence == 'none' ? null : _recurrence;
      if (widget.existing != null) {
        await controller.updateEvent(
          id: widget.existing!.id,
          title: title,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          startTime: startDateTime,
          endTime: endDateTime,
          isAllDay: _isAllDay,
          location: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          recurrence: recValue,
          owner: _owner,
        );
      } else {
        await controller.createEvent(
          title: title,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          startTime: startDateTime,
          endTime: endDateTime,
          isAllDay: _isAllDay,
          location: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          recurrence: recValue,
          owner: _owner,
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save event: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom +
        CovePageInsets.bottomOf(context);
    final isEditing = widget.existing != null;

    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: CoveShape.topDecoration(
        CoveRadius.sheet,
        color: cv.surfaceSheet,
        side: BorderSide(color: cv.lineHairline),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          CoveSpace.lg,
          16,
          CoveSpace.lg,
          CoveSpace.lg + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: CoveSpace.xs,
                  decoration: CoveShape.decoration(
                    CoveRadius.pill,
                    color: cv.lineHairline,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Event' : 'Add Calendar Event',
                    style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
                  ),
                  if (isEditing)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: cv.statusAlertText,
                        size: 20,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: cv.surfaceCard,
                            title: Text(
                              'Delete Event',
                              style: CoveType.slipTitle.copyWith(
                                color: cv.textPrimary,
                              ),
                            ),
                            content: Text(
                              'Remove this event from shared calendar?',
                              style: CoveType.body.copyWith(
                                color: cv.textSecondary,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: Text(
                                  'Cancel',
                                  style: CoveType.rowTitle.copyWith(
                                    color: cv.textSecondary,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: Text(
                                  'Delete',
                                  style: CoveType.rowTitle.copyWith(
                                    color: cv.statusAlertText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          final existing = widget.existing!;
                          final pendingDelete = ref.read(pendingDeleteServiceProvider);
                          await pendingDelete.scheduleDelete(
                            kind: PendingDeleteKind.event,
                            id: existing.id,
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            CoveUndoToast.show(
                              context,
                              message: 'Deleted "${existing.title}"',
                              onUndo: () async {
                                await pendingDelete.undoDelete(
                                  kind: PendingDeleteKind.event,
                                  id: existing.id,
                                );
                              },
                            );
                          }
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: CoveSpace.gutter),

              // Event Title
              Text(
                'EVENT TITLE',
                style: CoveType.capsPage.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.sm),
              CovePillInput(
                controller: _titleController,
                hintText: 'e.g. Dinner with Friends, Flight to NYC',
              ),
              const SizedBox(height: 18),

              // All Day Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All-day Event',
                    style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                  ),
                  Switch.adaptive(
                    value: _isAllDay,
                    activeTrackColor: cv.accentFill,
                    onChanged: (val) => setState(() => _isAllDay = val),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Start Date & Time
              Text(
                'STARTS',
                style: CoveType.capsPage.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cv.lineHairline),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: CoveSpace.md,
                        ),
                        alignment: Alignment.centerLeft,
                      ),
                      icon: Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: cv.textPrimary,
                      ),
                      label: Text(
                        dateFormat.format(_startDate),
                        style: CoveType.rowTitle.copyWith(
                          color: cv.textPrimary,
                        ),
                      ),
                      onPressed: () => _pickDate(isStart: true),
                    ),
                  ),
                  if (!_isAllDay) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cv.lineHairline),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: CoveSpace.md,
                        ),
                      ),
                      icon: Icon(
                        Icons.access_time,
                        size: 16,
                        color: cv.textPrimary,
                      ),
                      label: Text(
                        _startTime.format(context),
                        style: CoveType.rowTitle.copyWith(
                          color: cv.textPrimary,
                        ),
                      ),
                      onPressed: () => _pickTime(isStart: true),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // End Date & Time
              Text(
                'ENDS',
                style: CoveType.capsPage.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cv.lineHairline),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: CoveSpace.md,
                        ),
                        alignment: Alignment.centerLeft,
                      ),
                      icon: Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: cv.textPrimary,
                      ),
                      label: Text(
                        dateFormat.format(_endDate),
                        style: CoveType.rowTitle.copyWith(
                          color: cv.textPrimary,
                        ),
                      ),
                      onPressed: () => _pickDate(isStart: false),
                    ),
                  ),
                  if (!_isAllDay) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cv.lineHairline),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: CoveSpace.md,
                        ),
                      ),
                      icon: Icon(
                        Icons.access_time,
                        size: 16,
                        color: cv.textPrimary,
                      ),
                      label: Text(
                        _endTime.format(context),
                        style: CoveType.rowTitle.copyWith(
                          color: cv.textPrimary,
                        ),
                      ),
                      onPressed: () => _pickTime(isStart: false),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),

              // Recurrence / Repeat Selector
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: CoveSpace.section,
                  runSpacing: CoveSpace.xs,
                  children: [
                    Text(
                      'REPEAT',
                      style: CoveType.capsPage.copyWith(color: cv.textSecondary),
                    ),
                    if (_recurrence != 'none')
                      Text(
                        'Recurring event',
                        style: CoveType.rowSub.copyWith(
                          color: cv.accentText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: CoveSpace.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ('none', 'Does not repeat'),
                    ('daily', 'Daily'),
                    ('weekly', 'Weekly'),
                    ('biweekly', 'Bi-weekly'),
                    ('monthly', 'Monthly'),
                    ('yearly', 'Yearly'),
                  ].map((rule) {
                    final isSelected = _recurrence == rule.$1;
                    return Padding(
                      padding: const EdgeInsets.only(right: CoveSpace.sm),
                      child: InkWell(
                        onTap: () => setState(() => _recurrence = rule.$1),
                        customBorder: CoveShape.border(CoveRadius.pill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: CoveSpace.sm,
                          ),
                          decoration: CoveShape.decoration(
                            CoveRadius.pill,
                            color: isSelected
                                ? cv.accentWash
                                : cv.surfaceRow,
                            side: BorderSide(
                              color: isSelected
                                  ? cv.accentFill
                                  : cv.lineHairline,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (rule.$1 != 'none') ...[
                                Icon(
                                  Icons.repeat,
                                  size: 13,
                                  color: isSelected
                                      ? cv.accentText
                                      : cv.textSecondary,
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                rule.$2,
                                style: CoveType.readout.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? cv.accentText
                                      : cv.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // Location
              Text(
                'LOCATION (OPTIONAL)',
                style: CoveType.capsPage.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.sm),
              CovePillInput(
                controller: _locationController,
                hintText: 'e.g. Chez Panisse, Home, Gate B12',
              ),
              const SizedBox(height: 18),

              // Notes / Description
              Text(
                'NOTES (OPTIONAL)',
                style: CoveType.capsPage.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.sm),
              CovePillInput(
                controller: _descriptionController,
                hintText: 'Confirmation codes, details, reminders...',
              ),
              const SizedBox(height: 18),

              // Whose is it?
              Text(
                'WHOSE IS IT?',
                style: CoveType.capsPage.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.sm),
              _buildOwnerPicker(),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: CoveType.rowSub.copyWith(color: cv.statusAlertText),
                ),
                const SizedBox(height: CoveSpace.md),
              ],

              // Save Action
              CovePillButton(
                label: _isSaving
                    ? 'Saving...'
                    : (isEditing ? 'Save Changes' : 'Create Shared Event'),
                onPressed: _isSaving ? null : _handleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerPicker() {
    final user = ref.watch(authProvider).value;
    final userProfile = ref.watch(userProfileProvider);
    final partnerProfile = ref.watch(partnerProfileProvider);
    final home = ref.watch(activeHomeProvider).value;

    final viewerId = user?.id ?? 'user_alex';
    final partnerId = partnerProfile.userId ?? 'partner_user';
    final viewerName = userProfile.displayName.trim().isNotEmpty
        ? userProfile.displayName.trim()
        : 'You';
    final partnerName = partnerProfile.displayName.trim().isNotEmpty
        ? partnerProfile.displayName.trim()
        : 'Partner';

    final creatorId = home?.createdBy ?? viewerId;
    final viewerPerson = CoveAvatar.resolvePerson(
      homeCreatedBy: creatorId,
      actorUserId: viewerId,
    );
    final partnerPerson =
        viewerPerson == CovePerson.a ? CovePerson.b : CovePerson.a;

    final selectedValue = _owner == 'both'
        ? 'both'
        : (_owner == partnerId ||
                (_owner != viewerId &&
                    _owner != 'me' &&
                    _owner != 'user_alex' &&
                    _owner != 'local_user')
            ? partnerId
            : viewerId);

    return AddPersonPicker<String>(
      people: <AddPersonTileData<String>>[
        AddPersonTileData<String>(
          value: viewerId,
          person: viewerPerson,
          label: viewerName,
          nameOrInitial: viewerName,
        ),
        AddPersonTileData<String>(
          value: partnerId,
          person: partnerPerson,
          label: partnerName,
          nameOrInitial: partnerName,
        ),
        const AddPersonTileData<String>(
          value: 'both',
          person: CovePerson.both,
          label: 'Both of you',
        ),
      ],
      selectedValue: selectedValue,
      onSelected: (val) => setState(() => _owner = val),
    );
  }
}
