import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_page_header.dart';
import '../../core/widgets/cove_undo_toast.dart';
import '../../sync/pending_delete_service.dart';
import 'routine_controller.dart';
import 'routine_models.dart';

class RoutineEventFormSheet extends ConsumerStatefulWidget {
  final String routineId;
  final RoutineEvent? event;
  final int? initialStartMinutes;

  const RoutineEventFormSheet({
    super.key,
    required this.routineId,
    this.event,
    this.initialStartMinutes,
  });

  @override
  ConsumerState<RoutineEventFormSheet> createState() => _RoutineEventFormSheetState();
}

class _RoutineEventFormSheetState extends ConsumerState<RoutineEventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late int _startMinutes;
  late int _endMinutes;
  String _selectedCategory = 'General';
  bool _isSubmitting = false;

  final List<String> _categories = const [
    'General',
    'Work',
    'Fitness',
    'Meals',
    'Sleep',
    'Study',
    'Household',
    'Leisure',
  ];

  @override
  void initState() {
    super.initState();
    final ev = widget.event;
    _titleController = TextEditingController(text: ev?.title ?? '');
    _notesController = TextEditingController(text: ev?.notes ?? '');

    if (ev != null) {
      _startMinutes = ev.startMinutes;
      _endMinutes = ev.endMinutes;
      _selectedCategory = ev.category ?? 'General';
    } else {
      final base = widget.initialStartMinutes ?? 9 * 60; // 9:00 AM default
      _startMinutes = base;
      _endMinutes = (base + 60) % 1440; // 1 hour duration
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  TimeOfDay _minutesToTimeOfDay(int minutes) {
    final norm = minutes % 1440;
    return TimeOfDay(hour: norm ~/ 60, minute: norm % 60);
  }

  int _timeOfDayToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  Future<void> _pickStartTime() async {
    final initial = _minutesToTimeOfDay(_startMinutes);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      final pickedMinutes = _timeOfDayToMinutes(picked);
      setState(() {
        _startMinutes = pickedMinutes;
        if (_endMinutes <= _startMinutes) {
          _endMinutes = (_startMinutes + 60) % 1440;
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final initial = _minutesToTimeOfDay(_endMinutes);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        _endMinutes = _timeOfDayToMinutes(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final controller = ref.read(routineControllerProvider);
    final isEditing = widget.event != null;

    try {
      if (isEditing) {
        await controller.updateRoutineEvent(
          id: widget.event!.id,
          routineId: widget.routineId,
          title: _titleController.text.trim(),
          startMinutes: _startMinutes,
          endMinutes: _endMinutes,
          category: _selectedCategory,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      } else {
        await controller.createRoutineEvent(
          routineId: widget.routineId,
          title: _titleController.text.trim(),
          startMinutes: _startMinutes,
          endMinutes: _endMinutes,
          category: _selectedCategory,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving event: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _delete() async {
    final ev = widget.event;
    if (ev == null) return;
    final cv = context.cv;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cv.surfaceCard,
        title: Text(
          'Delete Event',
          style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
        ),
        content: Text(
          'Delete "${ev.title}" from this routine?',
          style: CoveType.body.copyWith(color: cv.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: CoveType.rowTitle.copyWith(color: cv.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cv.statusAlert),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      final pendingDelete = ref.read(pendingDeleteServiceProvider);
      await pendingDelete.scheduleDelete(
        kind: PendingDeleteKind.routineEvent,
        id: ev.id,
      );
      if (mounted) {
        Navigator.of(context).pop();
        CoveUndoToast.show(
          context,
          message: 'Deleted "${ev.title}"',
          onUndo: () async {
            await pendingDelete.undoDelete(
              kind: PendingDeleteKind.routineEvent,
              id: ev.id,
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting event: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;
    final cv = context.cv;

    return Container(
      decoration: CoveShape.topDecoration(
        CoveRadius.sheet,
        color: cv.surfaceSheet,
      ),
      padding: EdgeInsets.only(
        left: CoveSpace.gutter,
        right: CoveSpace.gutter,
        top: CoveSpace.gutter,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            CovePageInsets.bottomOf(context) +
            CoveSpace.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      isEditing ? 'Edit Routine Event' : 'New Routine Event',
                      style: CoveType.slipTitle.copyWith(
                        color: cv.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isEditing)
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: cv.statusAlertText),
                      onPressed: _isSubmitting ? null : _delete,
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.close, color: cv.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                style: CoveType.body.copyWith(color: cv.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Event Title',
                  hintText: 'e.g. Morning Workout, Deep Work, Lunch',
                  border: CoveInputBorder(
                    radius: CoveRadius.inline,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Time pickers row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickStartTime,
                      customBorder: CoveShape.border(CoveRadius.inline),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: CoveSpace.md,
                        ),
                        decoration: CoveShape.decoration(
                          CoveRadius.inline,
                          side: BorderSide(color: cv.lineHairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Time',
                              style: CoveType.rowSub.copyWith(
                                color: cv.textSecondary,
                              ),
                            ),
                            const SizedBox(height: CoveSpace.xs),
                            Text(
                              RoutineEvent.formatMinutes(_startMinutes),
                              style: CoveType.rowTitle.copyWith(
                                color: cv.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: CoveSpace.md),
                  Expanded(
                    child: InkWell(
                      onTap: _pickEndTime,
                      customBorder: CoveShape.border(CoveRadius.inline),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: CoveSpace.md,
                        ),
                        decoration: CoveShape.decoration(
                          CoveRadius.inline,
                          side: BorderSide(color: cv.lineHairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End Time',
                              style: CoveType.rowSub.copyWith(
                                color: cv.textSecondary,
                              ),
                            ),
                            const SizedBox(height: CoveSpace.xs),
                            Text(
                              RoutineEvent.formatMinutes(_endMinutes),
                              style: CoveType.rowTitle.copyWith(
                                color: cv.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Category',
                style: CoveType.readout.copyWith(
                  color: cv.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: CoveSpace.sm),
              Wrap(
                spacing: CoveSpace.sm,
                runSpacing: CoveSpace.sm,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: cv.accentWash,
                    labelStyle: CoveType.readout.copyWith(
                      color: isSelected ? cv.accentText : cv.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = cat);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                style: CoveType.body.copyWith(color: cv.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g. Focus blocks, items to prepare',
                  border: CoveInputBorder(
                    radius: CoveRadius.inline,
                  ),
                ),
              ),
              const SizedBox(height: CoveSpace.lg),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cv.accentFill,
                  foregroundColor: cv.textOnAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: CoveShape.border(CoveRadius.inline),
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? SizedBox(
                        height: CoveSpace.gutter,
                        width: CoveSpace.gutter,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cv.textOnAccent,
                        ),
                      )
                    : Text(
                        isEditing ? 'Save Changes' : 'Add Event',
                        style: CoveType.rowTitle.copyWith(
                          color: cv.textOnAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
