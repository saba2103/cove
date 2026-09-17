import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../../sync/crypto/deterministic_home_icon.dart';
import '../../sync/providers/active_home_provider.dart';
import 'home_metadata_controller.dart';

class EditHomeDialog extends ConsumerStatefulWidget {
  const EditHomeDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EditHomeDialog(),
    );
  }

  @override
  ConsumerState<EditHomeDialog> createState() => _EditHomeDialogState();
}

class _EditHomeDialogState extends ConsumerState<EditHomeDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  DateTime? _selectedAnniversary;

  @override
  void initState() {
    super.initState();
    final activeHome = ref.read(activeHomeProvider).value;
    final meta = ref.read(homeMetadataProvider);
    _nameController = TextEditingController(text: activeHome?.name ?? '');
    _descController = TextEditingController(text: activeHome?.description ?? '');
    _selectedAnniversary = meta.anniversaryDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final activeHome = ref.watch(activeHomeProvider).value;
    final formattedDuration = HomeMetadataState.formatDuration(_selectedAnniversary);

    if (activeHome == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 24,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('About Us & Home', style: typography.headline.copyWith(fontSize: 20)),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textMuted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Home Icon preview
            Center(
              child: Column(
                children: [
                  DeterministicHomeIcon(homeId: activeHome.id, size: 52),
                  const SizedBox(height: 8),
                  Text(
                    'Unique cryptographic mark derived from your Home key',
                    style: typography.caption.copyWith(color: colors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Home Name
            Text('HOME NAME', style: typography.caption),
            const SizedBox(height: 8),
            CovePillInput(
              controller: _nameController,
              hintText: 'e.g. Our Haven, Brooklyn Apt',
            ),
            const SizedBox(height: 18),

            // Description
            Text('DESCRIPTION', style: typography.caption),
            const SizedBox(height: 8),
            CovePillInput(
              controller: _descController,
              hintText: 'A quiet place for both of us',
            ),
            const SizedBox(height: 18),

            // Anniversary / Moved-in date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ANNIVERSARY OR MOVED-IN DATE', style: typography.caption),
                if (_selectedAnniversary != null)
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedAnniversary = null);
                    },
                    child: Text('Clear', style: typography.caption.copyWith(color: colors.accentSecondary)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedAnniversary ?? DateTime.now(),
                  firstDate: DateTime(1980),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.dark(
                          primary: colors.accentPrimary,
                          surface: colors.surfaceCard,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() => _selectedAnniversary = picked);
                }
              },
              child: CoveCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 18, color: colors.accentPrimary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedAnniversary != null
                                ? DateFormat('MMMM d, yyyy').format(_selectedAnniversary!)
                                : 'Select date (optional)',
                            style: typography.bodyMedium,
                          ),
                          if (formattedDuration != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              formattedDuration,
                              style: typography.caption.copyWith(
                                color: colors.accentPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: colors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Shared quietly between the two of you. Never external or public.',
              style: typography.caption.copyWith(color: colors.textMuted, fontSize: 11),
            ),

            const SizedBox(height: 28),

            // Save Button
            CovePillButton(
              label: 'Save Home Details',
              onPressed: () async {
                final newName = _nameController.text.trim();
                if (newName.isNotEmpty) {
                  await ref.read(homeMetadataProvider.notifier).updateHomeDetails(
                    name: newName,
                    description: _descController.text.trim(),
                    anniversaryDate: _selectedAnniversary,
                  );
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
