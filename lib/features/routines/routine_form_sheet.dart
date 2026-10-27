import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_page_header.dart';
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
    final cv = context.cv;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cv.surfaceCard,
        title: Text(
          'Delete Routine',
          style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${routine.name}" and all its scheduled events?',
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
                  Text(
                    isEditing ? 'Edit Routine' : 'New Routine',
                    style: CoveType.slipTitle.copyWith(
                      color: cv.textPrimary,
                      fontWeight: FontWeight.w700,
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
                controller: _nameController,
                style: CoveType.body.copyWith(color: cv.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Routine Name',
                  hintText: 'e.g. Weekday, Weekend, Saturday',
                  border: CoveInputBorder(
                    radius: CoveRadius.inline,
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
                style: CoveType.readout.copyWith(
                  color: cv.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: CoveSpace.sm),
              // Preset chips
              Wrap(
                spacing: CoveSpace.sm,
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
                      duration: CoveMotion.q(context),
                      width: CoveSize.buttonRound,
                      height: CoveSize.buttonRound,
                      decoration: BoxDecoration(
                        color: isSelected ? cv.accentFill : cv.surfaceRow,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? cv.accentFill : cv.lineHairline,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: CoveType.readout.copyWith(
                          color: isSelected ? cv.textOnAccent : cv.textPrimary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
                        isEditing ? 'Save Changes' : 'Create Routine',
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
