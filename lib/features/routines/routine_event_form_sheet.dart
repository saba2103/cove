import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Delete "${ev.title}" from this routine?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.accentSecondary),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(routineControllerProvider).deleteRoutineEvent(ev.id);
      if (mounted) {
        Navigator.of(context).pop();
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
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                  Text(
                    isEditing ? 'Edit Routine Event' : 'New Routine Event',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isEditing)
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: context.colors.accentSecondary),
                      onPressed: _isSubmitting ? null : _delete,
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Event Title',
                  hintText: 'e.g. Morning Workout, Deep Work, Lunch',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
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
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Time',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              RoutineEvent.formatMinutes(_startMinutes),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickEndTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End Time',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              RoutineEvent.formatMinutes(_endMinutes),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: context.colors.accentPrimary.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? context.colors.accentPrimary : theme.textTheme.bodyMedium?.color,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g. Focus blocks, items to prepare',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.accentPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isEditing ? 'Save Changes' : 'Add Event',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
