import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
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

  static const double _kRowHorizontalPadding =
      16.0; // (literal) 16dp reminder row horizontal inset
  static const double _kSendIconSize =
      16.0; // (literal) 16dp preview notification send icon
  static const double _kDeleteIconSize =
      18.0; // (literal) 18dp delete reminder trash icon

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cv = context.cv;
    final reminders = ref.watch(checkinRemindersProvider);

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      appBar: AppBar(
        title: Text(
          'Check-in Reminders',
          style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: CoveSpace.gutter,
            vertical: CoveSpace.md,
          ),
          children: [
            // Warm Welcoming Intro Card
            CoveCard(
              padding: const EdgeInsets.all(CoveSpace.gutter),
              child: Row(
                children: [
                  Container(
                    width: CoveSize.buttonRound,
                    height: CoveSize.buttonRound,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cv.accentWash,
                    ),
                    child: Icon(
                      Icons.favorite_outline,
                      size: CoveSpace.gutter,
                      color: cv.accentFill,
                    ),
                  ),
                  const SizedBox(width: CoveSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A Gentle Invitation',
                          style: CoveType.rowTitle.copyWith(
                            color: cv.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: CoveSpace.xs),
                        Text(
                          'Warm daily nudges to step away from the rush, log in, and reflect together in your calm cove.',
                          style: CoveType.rowSub.copyWith(
                            color: cv.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CoveSpace.lg),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SCHEDULED REMINDERS',
                  style: CoveType.capsPage.copyWith(color: cv.textSecondary),
                ),
                Text(
                  '${reminders.where((r) => r.isEnabled).length} active',
                  style: CoveType.rowSub.copyWith(color: cv.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: CoveSpace.sm),

            if (reminders.isEmpty)
              CoveEmptyState(
                icon: Icons.notifications_none_outlined,
                title: 'No reminders set yet',
                description:
                    'Add daily check-ins to build a quiet, intentional habit for your shared home.',
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
                      horizontal: _kRowHorizontalPadding,
                      vertical: CoveSpace.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              reminder.formattedTime,
                              style: CoveType.slipTitle.copyWith(
                                color: reminder.isEnabled
                                    ? cv.accentTint
                                    : cv.textTertiary,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Preview Notification',
                                  icon: Icon(
                                    Icons.send_outlined,
                                    size: _kSendIconSize,
                                    color: cv.textSecondary,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(checkinRemindersProvider.notifier)
                                        .previewNotification(reminder);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Preview sent: "${reminder.message}"',
                                        ),
                                        backgroundColor: cv.surfaceCard,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Delete Reminder',
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: _kDeleteIconSize,
                                    color: cv.statusAlert,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(checkinRemindersProvider.notifier)
                                        .deleteReminder(reminder.id);
                                  },
                                ),
                                const SizedBox(width: CoveSpace.xs),
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
                        const SizedBox(height: CoveSpace.sm),
                        Text(
                          reminder.message,
                          style: CoveType.readout.copyWith(
                            color: reminder.isEnabled
                                ? cv.textPrimary
                                : cv.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: CoveSpace.lg),
              CovePillButton(
                label: '+ Add Another Reminder',
                variant: CoveButtonVariant.secondary,
                onPressed: () => _showAddReminderSheet(context, ref),
              ),
            ],
            const SizedBox(height: CoveSpace.section),
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
  static const double _kTopPadding =
      16.0; // (literal) 16dp add reminder sheet top inset and preset icon size
  static const double _kHandleWidth =
      36.0; // (literal) 36dp sheet drag handle width
  static const double _kHandleRadius =
      2.0; // (literal) 2dp sheet drag handle pill corner radius
  static const double _kTimeIconSize =
      18.0; // (literal) 18dp time picker button and custom input icon size
  static const double _kPresetBorderWidth =
      1.0; // (literal) 1dp preset option card border stroke

  TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 30);
  late final TextEditingController _customCopyController;
  String _selectedPreset = kDefaultWarmPresets.first;
  bool _useCustom = false;

  @override
  void initState() {
    super.initState();
    _customCopyController = TextEditingController(
      text: kDefaultWarmPresets.first,
    );
  }

  @override
  void dispose() {
    _customCopyController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final cv = context.cv;
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(
              primary: cv.accentFill,
              surface: cv.surfaceCard,
              onSurface: cv.textPrimary,
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

    ref
        .read(checkinRemindersProvider.notifier)
        .addReminder(
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
    final cv = context.cv;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: CoveShape.topDecoration(
        CoveRadius.sheet,
        color: cv.surfaceSheet,
        side: BorderSide(color: cv.lineHairline),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          CoveSpace.lg,
          _kTopPadding,
          CoveSpace.lg,
          CoveSpace.lg + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: _kHandleWidth,
                  height: CoveSpace.xs,
                  decoration: CoveShape.decoration(
                    _kHandleRadius,
                    color: cv.lineHairline,
                  ),
                ),
              ),
              const SizedBox(height: CoveSpace.gutter),
              Text(
                'New Check-in Reminder',
                style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
              ),
              const SizedBox(height: CoveSpace.sm),
              Text(
                'Choose a time and a warm message that feels inviting.',
                style: CoveType.rowSub.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.gutter),

              // Time selector button
              Text(
                'TIME',
                style: CoveType.capsCard.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.sm),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cv.lineHairline),
                  padding: const EdgeInsets.symmetric(
                    horizontal: _kTopPadding,
                    vertical: CoveSpace.md,
                  ),
                  alignment: Alignment.centerLeft,
                ),
                icon: Icon(
                  Icons.access_time,
                  size: _kTimeIconSize,
                  color: cv.accentFill,
                ),
                label: Text(
                  _selectedTime.format(context),
                  style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
                ),
                onPressed: _pickTime,
              ),
              const SizedBox(height: CoveSpace.gutter),

              // Warm Copy Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'WARM WELCOMING MESSAGE',
                    style: CoveType.capsCard.copyWith(color: cv.textSecondary),
                  ),
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
                      style: CoveType.rowSub.copyWith(
                        color: cv.accentText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CoveSpace.sm),

              if (_useCustom)
                CovePillInput(
                  controller: _customCopyController,
                  hintText: 'Write a tender, warm message to pause together...',
                  prefixIcon: Icon(
                    Icons.favorite_border,
                    size: _kTimeIconSize,
                    color: cv.textSecondary,
                  ),
                )
              else
                Column(
                  children: kDefaultWarmPresets.map((preset) {
                    final isSelected = _selectedPreset == preset;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: CoveSpace.sm),
                      child: InkWell(
                        onTap: () => setState(() => _selectedPreset = preset),
                        customBorder: CoveShape.border(CoveSpace.md),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: CoveSpace.md,
                            vertical: CoveSpace.md,
                          ),
                          decoration: CoveShape.decoration(
                            CoveSpace.md,
                            color: isSelected ? cv.accentWash : cv.surfaceRow,
                            side: BorderSide(
                              color: isSelected
                                  ? cv.accentFill
                                  : cv.lineHairline,
                              width: _kPresetBorderWidth,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: _kTopPadding,
                                color: isSelected
                                    ? cv.accentFill
                                    : cv.textTertiary,
                              ),
                              const SizedBox(width: CoveSpace.sm),
                              Expanded(
                                child: Text(
                                  preset,
                                  style: CoveType.readout.copyWith(
                                    color: isSelected
                                        ? cv.textPrimary
                                        : cv.textSecondary,
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
              const SizedBox(height: CoveSpace.lg),

              CovePillButton(label: 'Save Reminder', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
