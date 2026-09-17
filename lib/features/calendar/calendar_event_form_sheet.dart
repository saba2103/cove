import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../../sync/db/app_database.dart';
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

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    final baseDate = item?.startTime ?? widget.initialDate ?? DateTime.now();

    _titleController = TextEditingController(text: item?.title ?? '');
    _locationController = TextEditingController(text: item?.location ?? '');
    _descriptionController =
        TextEditingController(text: item?.description ?? '');

    _isAllDay = item?.isAllDay ?? false;
    _recurrence = item?.recurrence ?? 'none';
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
    final colors = context.colors;
    final current = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(
              primary: colors.accentPrimary,
              surface: colors.surfaceCard,
              onSurface: colors.textPrimary,
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
    final colors = context.colors;
    final current = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(
              primary: colors.accentPrimary,
              surface: colors.surfaceCard,
              onSurface: colors.textPrimary,
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
    final colors = context.colors;
    final typography = context.typography;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.existing != null;

    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: colors.borderHairline)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderHairline,
                    borderRadius: BorderRadius.circular(2),
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
                    style: typography.headline.copyWith(fontSize: 20),
                  ),
                  if (isEditing)
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: colors.accentSecondary, size: 20),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: colors.surfaceCard,
                            title: Text('Delete Event',
                                style: typography.headline.copyWith(fontSize: 18)),
                            content: Text('Remove this event from shared calendar?',
                                style: typography.bodyMedium),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: Text('Cancel',
                                    style: TextStyle(color: colors.textMuted)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: Text('Delete',
                                    style: TextStyle(color: colors.accentSecondary)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          await ref
                              .read(calendarControllerProvider)
                              .deleteEvent(widget.existing!.id);
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Event Title
              Text('EVENT TITLE', style: typography.caption),
              const SizedBox(height: 8),
              CovePillInput(
                controller: _titleController,
                hintText: 'e.g. Dinner with Friends, Flight to NYC',
              ),
              const SizedBox(height: 18),

              // All Day Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('All-day Event', style: typography.bodyMedium),
                  Switch.adaptive(
                    value: _isAllDay,
                    activeTrackColor: colors.accentPrimary,
                    onChanged: (val) => setState(() => _isAllDay = val),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Start Date & Time
              Text('STARTS', style: typography.caption),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.borderHairline),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        alignment: Alignment.centerLeft,
                      ),
                      icon: Icon(Icons.calendar_today,
                          size: 16, color: colors.textPrimary),
                      label: Text(
                        dateFormat.format(_startDate),
                        style: typography.bodyMedium
                            .copyWith(color: colors.textPrimary),
                      ),
                      onPressed: () => _pickDate(isStart: true),
                    ),
                  ),
                  if (!_isAllDay) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.borderHairline),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      icon: Icon(Icons.access_time,
                          size: 16, color: colors.textPrimary),
                      label: Text(
                        _startTime.format(context),
                        style: typography.bodyMedium
                            .copyWith(color: colors.textPrimary),
                      ),
                      onPressed: () => _pickTime(isStart: true),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // End Date & Time
              Text('ENDS', style: typography.caption),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.borderHairline),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        alignment: Alignment.centerLeft,
                      ),
                      icon: Icon(Icons.calendar_today,
                          size: 16, color: colors.textPrimary),
                      label: Text(
                        dateFormat.format(_endDate),
                        style: typography.bodyMedium
                            .copyWith(color: colors.textPrimary),
                      ),
                      onPressed: () => _pickDate(isStart: false),
                    ),
                  ),
                  if (!_isAllDay) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.borderHairline),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      icon: Icon(Icons.access_time,
                          size: 16, color: colors.textPrimary),
                      label: Text(
                        _endTime.format(context),
                        style: typography.bodyMedium
                            .copyWith(color: colors.textPrimary),
                      ),
                      onPressed: () => _pickTime(isStart: false),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),

              // Recurrence / Repeat Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('REPEAT', style: typography.caption),
                  if (_recurrence != 'none')
                    Text(
                      'Recurring event',
                      style: typography.caption.copyWith(
                        color: colors.accentPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
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
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _recurrence = rule.$1),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.accentPrimary.withValues(alpha: 0.18)
                                : colors.surfaceRow,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isSelected
                                  ? colors.accentPrimary
                                  : colors.borderHairline,
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
                                      ? colors.accentPrimary
                                      : colors.textMuted,
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                rule.$2,
                                style: TextStyle(
                                  fontFamily: 'GeneralSans',
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? colors.accentPrimary
                                      : colors.textMuted,
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
              Text('LOCATION (OPTIONAL)', style: typography.caption),
              const SizedBox(height: 8),
              CovePillInput(
                controller: _locationController,
                hintText: 'e.g. Chez Panisse, Home, Gate B12',
              ),
              const SizedBox(height: 18),

              // Notes / Description
              Text('NOTES (OPTIONAL)', style: typography.caption),
              const SizedBox(height: 8),
              CovePillInput(
                controller: _descriptionController,
                hintText: 'Confirmation codes, details, reminders...',
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: typography.caption
                      .copyWith(color: colors.accentSecondary),
                ),
                const SizedBox(height: 12),
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
}
