import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_empty_state.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../../core/widgets/cove_toggle_switch.dart';
import 'reminder_controller.dart';
import 'reminder_models.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final reminders = ref.watch(checkinRemindersProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Check-in Reminders',
            style: typography.headline.copyWith(fontSize: 20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Warm Welcoming Intro Card
            CoveCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accentPrimary.withValues(alpha: 0.12),
                    ),
                    child: Icon(Icons.favorite_outline,
                        size: 20, color: colors.accentPrimary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A Gentle Invitation',
                          style: typography.title.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Warm daily nudges to step away from the rush, log in, and reflect together in your calm cove.',
                          style: typography.caption.copyWith(
                            color: colors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SCHEDULED REMINDERS', style: typography.caption),
                Text(
                  '${reminders.where((r) => r.isEnabled).length} active',
                  style: typography.caption.copyWith(color: colors.textSubtle),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (reminders.isEmpty)
              CoveEmptyState(
                icon: Icons.notifications_none_outlined,
                title: 'No reminders set yet',
                description:
                    'Add daily check-ins to build a quiet, intentional rhythm for your shared home.',
                action: CovePillButton(
                  label: '+ Add Check-in Reminder',
                  onPressed: () => _showAddReminderSheet(context, ref),
                ),
              )
            else ...[
              CoveGroupedCard(
                children: reminders.map((reminder) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              reminder.formattedTime,
                              style: typography.headline.copyWith(
                                fontSize: 24,
                                color: reminder.isEnabled
                                    ? colors.accentTint
                                    : colors.textSubtle,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Preview Notification',
                                  icon: Icon(Icons.send_outlined,
                                      size: 16, color: colors.textMuted),
                                  onPressed: () {
                                    ref
                                        .read(checkinRemindersProvider.notifier)
                                        .previewNotification(reminder);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Preview sent: "${reminder.message}"'),
                                        backgroundColor: colors.surfaceCard,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Delete Reminder',
                                  icon: Icon(Icons.delete_outline,
                                      size: 18, color: colors.accentSecondary),
                                  onPressed: () {
                                    ref
                                        .read(checkinRemindersProvider.notifier)
                                        .deleteReminder(reminder.id);
                                  },
                                ),
                                const SizedBox(width: 4),
                                CoveToggleSwitch(
                                  value: reminder.isEnabled,
                                  onChanged: (val) {
                                    ref
                                        .read(checkinRemindersProvider.notifier)
                                        .toggleReminder(reminder.id, val);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          reminder.message,
                          style: typography.bodyMedium.copyWith(
                            fontSize: 14,
                            color: reminder.isEnabled
                                ? colors.textPrimary
                                : colors.textSubtle,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              CovePillButton(
                label: '+ Add Another Reminder',
                variant: CoveButtonVariant.secondary,
                onPressed: () => _showAddReminderSheet(context, ref),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showAddReminderSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddReminderSheet(),
    );
  }
}

class _AddReminderSheet extends ConsumerStatefulWidget {
  const _AddReminderSheet();

  @override
  ConsumerState<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<_AddReminderSheet> {
  TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 30);
  late final TextEditingController _customCopyController;
  String _selectedPreset = kDefaultWarmPresets.first;
  bool _useCustom = false;

  @override
  void initState() {
    super.initState();
    _customCopyController = TextEditingController(text: kDefaultWarmPresets.first);
  }

  @override
  void dispose() {
    _customCopyController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final colors = context.colors;
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
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
      setState(() => _selectedTime = picked);
    }
  }

  void _save() {
    final message = _useCustom
        ? _customCopyController.text.trim()
        : _selectedPreset;

    ref.read(checkinRemindersProvider.notifier).addReminder(
          hour: _selectedTime.hour,
          minute: _selectedTime.minute,
          message: message.isNotEmpty
              ? message
              : 'A quiet moment for us • Check in on our sanctuary',
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
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
              Text(
                'New Check-in Reminder',
                style: typography.headline.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a time and a warm message that feels inviting.',
                style: typography.caption.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: 20),

              // Time selector button
              Text('TIME', style: typography.caption),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.borderHairline),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  alignment: Alignment.centerLeft,
                ),
                icon: Icon(Icons.access_time, size: 18, color: colors.accentPrimary),
                label: Text(
                  _selectedTime.format(context),
                  style: typography.headline.copyWith(
                    fontSize: 22,
                    color: colors.textPrimary,
                  ),
                ),
                onPressed: _pickTime,
              ),
              const SizedBox(height: 20),

              // Warm Copy Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('WARM WELCOMING MESSAGE', style: typography.caption),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _useCustom = !_useCustom;
                        if (_useCustom) {
                          _customCopyController.text = _selectedPreset;
                        }
                      });
                    },
                    child: Text(
                      _useCustom ? 'Pick a preset' : '+ Custom message',
                      style: typography.caption.copyWith(
                        color: colors.accentPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_useCustom)
                CovePillInput(
                  controller: _customCopyController,
                  hintText: 'Write a tender, warm message to pause together...',
                  prefixIcon: Icon(Icons.favorite_border,
                      size: 18, color: colors.textMuted),
                )
              else
                Column(
                  children: kDefaultWarmPresets.map((preset) {
                    final isSelected = _selectedPreset == preset;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedPreset = preset),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.accentPrimary.withValues(alpha: 0.14)
                                : colors.surfaceRow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? colors.accentPrimary
                                  : colors.borderHairline,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: 16,
                                color: isSelected
                                    ? colors.accentPrimary
                                    : colors.textSubtle,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  preset,
                                  style: typography.bodyMedium.copyWith(
                                    fontSize: 13,
                                    color: isSelected
                                        ? colors.textPrimary
                                        : colors.textMuted,
                                    fontWeight: isSelected
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 24),

              CovePillButton(
                label: 'Save Reminder',
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
