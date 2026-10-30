import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
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
    final cv = context.cv;
    final mediaQuery = MediaQuery.of(context);
    final isEditing = widget.existing != null;
    final partnerName = ref.watch(partnerProfileProvider).displayName;

    return Container(
      decoration: CoveShape.topDecoration(
        CoveRadius.sheet,
        color: cv.surfaceSheet,
        side: BorderSide(color: cv.lineHairline, width: 1),
      ),
      padding: EdgeInsets.only(
        left: CoveSpace.gutter,
        right: CoveSpace.gutter,
        top: CoveSpace.gutter,
        bottom: mediaQuery.viewInsets.bottom + CoveSpace.lg,
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
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Habit' : 'New Habit',
                      style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: cv.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name Input
              Text(
                'HABIT NAME',
                style: CoveType.capsPage.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.sm),
              CovePillInput(
                controller: _nameController,
                hintText: 'e.g. Morning Walk, Water Plants, Reading',
                prefixIcon: Icon(
                  Icons.repeat_outlined,
                  size: 18,
                  color: cv.textSecondary,
                ),
              ),
              const SizedBox(height: CoveSpace.gutter),

              // Cadence Selector
              Text(
                'FREQUENCY',
                style: CoveType.capsPage.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.sm),
              Container(
                decoration: CoveShape.decoration(
                  MediaQuery.textScalerOf(context).scale(1.0) > 1.0
                      ? CoveRadius.inline
                      : CoveRadius.pill,
                  color: cv.surfaceRow,
                  side: BorderSide(color: cv.lineHairline, width: 1),
                ),
                padding: const EdgeInsets.all(3),
                child: MediaQuery.textScalerOf(context).scale(1.0) > 1.0
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildPill(
                            label: 'Daily',
                            isSelected: _cadence == 'daily',
                            onTap: () => setState(() {
                              _cadence = 'daily';
                              _selectedDays = {1, 2, 3, 4, 5, 6, 7};
                              _targetDays = 7;
                            }),
                          ),
                          _buildPill(
                            label: 'Weekly',
                            isSelected: _cadence == 'weekly',
                            onTap: () => setState(() {
                              _cadence = 'weekly';
                              if (_selectedDays.length != 1) {
                                _selectedDays = {clock.now().weekday};
                              }
                              _targetDays = 1;
                            }),
                          ),
                          _buildPill(
                            label: 'Custom',
                            isSelected: _cadence == 'custom',
                            onTap: () => setState(() {
                              _cadence = 'custom';
                              if (_selectedDays.isEmpty ||
                                  _selectedDays.length == 7) {
                                _selectedDays = {1, 3, 5}; // Mon, Wed, Fri
                              }
                              _targetDays = _selectedDays.length;
                            }),
                          ),
                        ],
                      )
                    : Row(
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
                                  _selectedDays = {clock.now().weekday};
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
                                if (_selectedDays.isEmpty ||
                                    _selectedDays.length == 7) {
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
                  style: CoveType.capsPage.copyWith(color: cv.textSecondary),
                ),
                const SizedBox(height: CoveSpace.sm),
                _buildDayOfWeekChips(),
              ],

              const SizedBox(height: 18),

              // Time of Day Picker
              Text(
                'TIME OF DAY',
                style: CoveType.capsPage.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.sm),
              InkWell(
                onTap: _pickTime,
                customBorder: CoveShape.border(CoveRadius.inline),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: CoveSpace.md,
                  ),
                  decoration: CoveShape.decoration(
                    CoveRadius.inline,
                    color: cv.surfaceRow,
                    side: BorderSide(color: cv.lineHairline, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 18,
                        color: _selectedTime != null
                            ? cv.accentText
                            : cv.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedTime != null
                              ? _formatTimeOfDay(_selectedTime!)
                              : 'Any time of day',
                          style: CoveType.readout.copyWith(
                            fontWeight: _selectedTime != null
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: _selectedTime != null
                                ? cv.textPrimary
                                : cv.textSecondary,
                          ),
                        ),
                      ),
                      if (_selectedTime != null)
                        GestureDetector(
                          onTap: () => setState(() => _selectedTime = null),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(CoveSpace.xs),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: cv.textSecondary,
                            ),
                          ),
                        )
                      else
                        Text(
                          'Set time',
                          style: CoveType.rowSub.copyWith(
                            fontWeight: FontWeight.w500,
                            color: cv.accentText,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Visibility Selector
              Text(
                'VISIBILITY & PRIVACY',
                style: CoveType.capsPage.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.sm),
              Container(
                decoration: CoveShape.decoration(
                  CoveRadius.inline,
                  color: cv.surfaceRow,
                  side: BorderSide(color: cv.lineHairline, width: 1),
                ),
                padding: const EdgeInsets.all(CoveSpace.xs),
                child: Column(
                  children: [
                    if (MediaQuery.textScalerOf(context).scale(1.0) > 1.0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildVisibilityPill(
                            icon: Icons.people_outline,
                            label: 'Shared with $partnerName',
                            isSelected:
                                _visibility == HabitVisibility.shared,
                            onTap: () => setState(
                                () => _visibility = HabitVisibility.shared),
                          ),
                          const SizedBox(height: CoveSpace.xs),
                          _buildVisibilityPill(
                            icon: Icons.lock_outline,
                            label: 'Private to Me',
                            isSelected:
                                _visibility == HabitVisibility.privateToMe,
                            onTap: () => setState(() =>
                                _visibility = HabitVisibility.privateToMe),
                          ),
                        ],
                      )
                    else
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
                          const SizedBox(width: CoveSpace.xs),
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
                      padding: const EdgeInsets.fromLTRB(
                        10,
                        CoveSpace.sm,
                        10,
                        6,
                      ),
                      child: Text(
                        _visibility == HabitVisibility.shared
                            ? '$partnerName sees a calm read-only view of your progress. Zero annoying push notifications or alarm bells.'
                            : 'Private habits stay strictly on this device. 0 bytes are emitted or transmitted to $partnerName.',
                        style: CoveType.barLabel.copyWith(
                          color: cv.textSecondary,
                          fontWeight: FontWeight.w400,
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
                  style: CoveType.readout.copyWith(
                    color: cv.statusAlertText,
                  ),
                ),
              ],

              const SizedBox(height: CoveSpace.lg),

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
    final cv = context.cv;
    const days = [
      (1, 'M', 'Mon'),
      (2, 'T', 'Tue'),
      (3, 'W', 'Wed'),
      (4, 'T', 'Thu'),
      (5, 'F', 'Fri'),
      (6, 'S', 'Sat'),
      (7, 'S', 'Sun'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final isScaled = textScale > 1.0;
        final chipSize = isScaled
            ? (CoveSize.buttonRound * (textScale > 1.35 ? 1.2 : 1.05))
                .ceilToDouble()
            : ((constraints.maxWidth - 6 * CoveSpace.xs) / 7)
                .clamp(32.0, CoveSize.buttonRound);

        final chipWidgets = days.map((day) {
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
            child: Container(
              width: chipSize,
              height: chipSize,
              decoration: BoxDecoration(
                color: isSelected
                    ? cv.accentFill
                    : cv.surfaceRow,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? cv.accentFill
                      : cv.lineHairline,
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: CoveType.readout.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? cv.textOnAccent
                      : cv.textPrimary,
                ),
              ),
            ),
          );
        }).toList();

        if (isScaled) {
          return Wrap(
            spacing: CoveSpace.sm,
            runSpacing: CoveSpace.sm,
            children: chipWidgets,
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: chipWidgets,
        );
      },
    );
  }

  Widget _buildPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final cv = context.cv;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: CoveMotion.q(context),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: CoveShape.decoration(
          CoveRadius.pill,
          color: isSelected
              ? (isDark ? cv.accentFill : cv.surfaceCard)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: CoveType.readout.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? (isDark ? cv.textOnAccent : cv.textPrimary)
                : cv.textSecondary,
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
    final cv = context.cv;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: CoveMotion.q(context),
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: CoveSpace.sm,
        ),
        decoration: CoveShape.decoration(
          CoveRadius.inline,
          color: isSelected
              ? cv.surfaceCard
              : Colors.transparent,
          side: isSelected
              ? BorderSide(color: cv.accentFill.withValues(alpha: 0.3), width: 1)
              : BorderSide.none,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? cv.textPrimary : cv.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines:
                    MediaQuery.textScalerOf(context).scale(1.0) > 1.0 ? null : 1,
                overflow: MediaQuery.textScalerOf(context).scale(1.0) > 1.0
                    ? null
                    : TextOverflow.ellipsis,
                style: CoveType.rowSub.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? cv.textPrimary : cv.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
