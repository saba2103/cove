import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import 'routine_controller.dart';
import 'routine_models.dart';

class RoutineFormSheet extends ConsumerStatefulWidget {
  final Routine? routine;

  const RoutineFormSheet({super.key, this.routine});

  @override
  ConsumerState<RoutineFormSheet> createState() => _RoutineFormSheetState();
}

class _RoutineFormSheetState extends ConsumerState<RoutineFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final Set<int> _selectedDays = {};
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _daysInfo = const [
    {'day': 1, 'label': 'M', 'full': 'Monday'},
    {'day': 2, 'label': 'T', 'full': 'Tuesday'},
    {'day': 3, 'label': 'W', 'full': 'Wednesday'},
    {'day': 4, 'label': 'T', 'full': 'Thursday'},
    {'day': 5, 'label': 'F', 'full': 'Friday'},
    {'day': 6, 'label': 'S', 'full': 'Saturday'},
    {'day': 7, 'label': 'S', 'full': 'Sunday'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.routine?.name ?? '');
    if (widget.routine != null) {
      _selectedDays.addAll(widget.routine!.days);
    } else {
      _selectedDays.addAll([1, 2, 3, 4, 5]); // Default Weekday
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        if (_selectedDays.length > 1) {
          _selectedDays.remove(day);
        }
      } else {
        _selectedDays.add(day);
      }
    });
  }

  void _selectPreset(List<int> days, String name) {
    setState(() {
      _selectedDays.clear();
      _selectedDays.addAll(days);
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = name;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final controller = ref.read(routineControllerProvider);
    final isEditing = widget.routine != null;

    try {
      if (isEditing) {
        await controller.updateRoutine(
          id: widget.routine!.id,
          name: _nameController.text.trim(),
          days: _selectedDays.toList(),
        );
      } else {
        final newId = await controller.createRoutine(
          name: _nameController.text.trim(),
          days: _selectedDays.toList(),
        );
        ref.read(selectedRoutineIdProvider.notifier).select(newId);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving routine: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _delete() async {
    final routine = widget.routine;
    if (routine == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Routine'),
        content: Text('Are you sure you want to delete "${routine.name}" and all its scheduled events?'),
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
      await ref.read(routineControllerProvider).deleteRoutine(routine.id);
      if (mounted) {
        ref.read(selectedRoutineIdProvider.notifier).select(null);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting routine: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.routine != null;
    final theme = Theme.of(context);
    final colors = context.colors;

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
                    isEditing ? 'Edit Routine' : 'New Routine',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isEditing)
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: colors.accentSecondary),
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
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Routine Name',
                  hintText: 'e.g. Weekday, Weekend, Saturday',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Active Days',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              // Preset chips
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Mon – Fri'),
                    onPressed: () => _selectPreset([1, 2, 3, 4, 5], 'Weekday (Mon – Fri)'),
                  ),
                  ActionChip(
                    label: const Text('Saturday'),
                    onPressed: () => _selectPreset([6], 'Saturday'),
                  ),
                  ActionChip(
                    label: const Text('Sunday'),
                    onPressed: () => _selectPreset([7], 'Sunday'),
                  ),
                  ActionChip(
                    label: const Text('Weekend'),
                    onPressed: () => _selectPreset([6, 7], 'Weekend'),
                  ),
                  ActionChip(
                    label: const Text('Every day'),
                    onPressed: () => _selectPreset([1, 2, 3, 4, 5, 6, 7], 'Daily Routine'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Day circles
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _daysInfo.map((info) {
                  final day = info['day'] as int;
                  final label = info['label'] as String;
                  final isSelected = _selectedDays.contains(day);

                  return GestureDetector(
                    onTap: () => _toggleDay(day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? colors.accentPrimary : colors.surfaceRow,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? colors.accentPrimary : colors.borderHairline,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accentPrimary,
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
                        isEditing ? 'Save Changes' : 'Create Routine',
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
