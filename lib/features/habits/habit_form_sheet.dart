import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../../sync/db/app_database.dart';
import '../profile/partner_profile_controller.dart';
import 'habit_controller.dart';
import 'habit_schedule.dart';

class HabitFormSheet extends ConsumerStatefulWidget {
  final LocalHabit? existing;

  const HabitFormSheet({super.key, this.existing});

  static Future<void> show(BuildContext context, {LocalHabit? existing}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HabitFormSheet(existing: existing),
    );
  }

  @override
  ConsumerState<HabitFormSheet> createState() => _HabitFormSheetState();
}

class _HabitFormSheetState extends ConsumerState<HabitFormSheet> {
  final TextEditingController _nameController = TextEditingController();
  String _cadence = 'daily'; // 'daily' | 'weekly' | 'custom'
  Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7}; // 1 = Mon, 7 = Sun
  TimeOfDay? _selectedTime;
  int _targetDays = 7;
  HabitVisibility _visibility = HabitVisibility.shared;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _visibility = existing.targetDaysPerWeek < 0
          ? HabitVisibility.privateToMe
          : HabitVisibility.shared;

      final schedule = HabitSchedule.parse(
        existing.cadence,
        targetDays: existing.targetDaysPerWeek,
      );
      _cadence = schedule.frequency;
      _selectedDays = Set<int>.from(schedule.daysOfWeek);
      _selectedTime = schedule.timeOfDay;
      _targetDays = existing.targetDaysPerWeek.abs();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    final p = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $p';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter a habit name.');
      return;
    }

    if (_cadence == 'weekly' && _selectedDays.isEmpty) {
      setState(() => _errorMessage = 'Please select a day of the week.');
      return;
    }

    if (_cadence == 'custom' && _selectedDays.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one day.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final controller = ref.read(habitControllerProvider);

      final schedule = HabitSchedule(
        frequency: _cadence,
        daysOfWeek: _selectedDays.toList(),
        timeOfDay: _selectedTime,
      );
      final cadenceString = schedule.toCadenceString();
      final effectiveTarget = _cadence == 'daily'
          ? 7
          : (_selectedDays.isNotEmpty ? _selectedDays.length : _targetDays);

      if (widget.existing != null) {
        await controller.updateHabit(
          habit: widget.existing!,
          name: name,
          cadence: cadenceString,
          targetDaysPerWeek: effectiveTarget,
          visibility: _visibility,
        );
      } else {
        await controller.createHabit(
          name: name,
          cadence: cadenceString,
          targetDaysPerWeek: effectiveTarget,
          visibility: _visibility,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final mediaQuery = MediaQuery.of(context);
    final isEditing = widget.existing != null;
    final partnerName = ref.watch(partnerProfileProvider).displayName;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: colors.borderHairline, width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: mediaQuery.viewInsets.bottom + 24,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Habit' : 'New Habit or Rhythm',
                    style: typography.title.copyWith(fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name Input
              Text('HABIT NAME', style: typography.caption),
              const SizedBox(height: 8),
              CovePillInput(
                controller: _nameController,
                hintText: 'e.g. Morning Walk, Water Plants, Reading',
                prefixIcon: Icon(Icons.repeat_outlined,
                    size: 18, color: colors.textMuted),
              ),
              const SizedBox(height: 20),

              // Cadence Selector
              Text('FREQUENCY', style: typography.caption),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: colors.surfaceRow,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.borderHairline, width: 1),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildPill(
                        label: 'Daily',
                        isSelected: _cadence == 'daily',
                        onTap: () => setState(() {
                          _cadence = 'daily';
                          _selectedDays = {1, 2, 3, 4, 5, 6, 7};
                          _targetDays = 7;
                        }),
                      ),
                    ),
                    Expanded(
                      child: _buildPill(
                        label: 'Weekly',
                        isSelected: _cadence == 'weekly',
                        onTap: () => setState(() {
                          _cadence = 'weekly';
                          if (_selectedDays.length != 1) {
                            _selectedDays = {DateTime.now().weekday};
                          }
                          _targetDays = 1;
                        }),
                      ),
                    ),
                    Expanded(
                      child: _buildPill(
                        label: 'Custom',
                        isSelected: _cadence == 'custom',
                        onTap: () => setState(() {
                          _cadence = 'custom';
                          if (_selectedDays.isEmpty || _selectedDays.length == 7) {
                            _selectedDays = {1, 3, 5}; // Mon, Wed, Fri
                          }
                          _targetDays = _selectedDays.length;
                        }),
                      ),
                    ),
                  ],
                ),
              ),

              // Days of week selector for Weekly & Custom
              if (_cadence == 'weekly' || _cadence == 'custom') ...[
                const SizedBox(height: 16),
                Text(
                  _cadence == 'weekly' ? 'REPEAT ON DAY' : 'REPEAT ON DAYS',
                  style: typography.caption,
                ),
                const SizedBox(height: 8),
                _buildDayOfWeekChips(),
              ],

              const SizedBox(height: 18),

              // Time of Day Picker
              Text('TIME OF DAY', style: typography.caption),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.surfaceRow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.borderHairline, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 18,
                        color: _selectedTime != null ? colors.accentPrimary : colors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedTime != null
                              ? _formatTimeOfDay(_selectedTime!)
                              : 'Any time of day',
                          style: TextStyle(
                            fontFamily: 'GeneralSans',
                            fontSize: 14,
                            fontWeight: _selectedTime != null ? FontWeight.w600 : FontWeight.w400,
                            color: _selectedTime != null ? colors.textPrimary : colors.textMuted,
                          ),
                        ),
                      ),
                      if (_selectedTime != null)
                        GestureDetector(
                          onTap: () => setState(() => _selectedTime = null),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.close, size: 16, color: colors.textMuted),
                          ),
                        )
                      else
                        Text(
                          'Set time',
                          style: TextStyle(
                            fontFamily: 'GeneralSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colors.accentPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Visibility Selector
              Text('VISIBILITY & PRIVACY', style: typography.caption),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: colors.surfaceRow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.borderHairline, width: 1),
                ),
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildVisibilityPill(
                            icon: Icons.people_outline,
                            label: 'Shared with $partnerName',
                            isSelected:
                                _visibility == HabitVisibility.shared,
                            onTap: () => setState(() =>
                                _visibility = HabitVisibility.shared),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildVisibilityPill(
                            icon: Icons.lock_outline,
                            label: 'Private to Me',
                            isSelected:
                                _visibility == HabitVisibility.privateToMe,
                            onTap: () => setState(() =>
                                _visibility = HabitVisibility.privateToMe),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                      child: Text(
                        _visibility == HabitVisibility.shared
                            ? '$partnerName sees a calm read-only view of your progress. Zero annoying push notifications or alarm bells.'
                            : 'Private habits stay strictly on this device. 0 bytes are emitted or transmitted to $partnerName.',
                        style: typography.caption.copyWith(
                          fontSize: 11,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 13,
                    color: colors.accentSecondary,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Save Button
              CovePillButton(
                label: isEditing ? 'Save Changes' : 'Create Habit',
                isLoading: _isSaving,
                onPressed: _handleSave,
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayOfWeekChips() {
    final colors = context.colors;
    final isDark = context.isDark;
    const days = [
      (1, 'M', 'Mon'),
      (2, 'T', 'Tue'),
      (3, 'W', 'Wed'),
      (4, 'T', 'Thu'),
      (5, 'F', 'Fri'),
      (6, 'S', 'Sat'),
      (7, 'S', 'Sun'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((day) {
        final dayNum = day.$1;
        final letter = day.$2;
        final isSelected = _selectedDays.contains(dayNum);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (_cadence == 'weekly') {
                // Weekly is single day selection
                _selectedDays = {dayNum};
              } else {
                // Custom allows multi-selection
                if (isSelected) {
                  if (_selectedDays.length > 1) {
                    _selectedDays.remove(dayNum);
                  }
                } else {
                  _selectedDays.add(dayNum);
                }
                _targetDays = _selectedDays.length;
              }
            });
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.accentPrimary
                  : colors.surfaceRow,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? colors.accentPrimary
                    : colors.borderHairline,
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: TextStyle(
                fontFamily: 'GeneralSans',
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? const Color(0xFF0B1F1E) : Colors.white)
                    : colors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final isDark = context.isDark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? colors.accentPrimary : colors.surfaceCard)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? (isDark ? const Color(0xFF0B1F1E) : colors.textPrimary)
                : colors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityPill({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final isDark = context.isDark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? colors.surfaceCard : colors.surfaceCard)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: colors.accentPrimary.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? colors.textPrimary : colors.textMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'GeneralSans',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? colors.textPrimary : colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
