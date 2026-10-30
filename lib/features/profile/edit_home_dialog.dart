import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
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
  static const double _kDateCardRadius =
      12.0; // (literal) 12dp anniversary picker tap ripple radius
  static const double _kCardPaddingH =
      16.0; // (literal) 16dp anniversary card horizontal inset
  static const double _kCalendarIconSize =
      18.0; // (literal) 18dp calendar icon size
  static const double _kSaveButtonTopGap =
      28.0; // (literal) 28dp gap above save home details button

  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  DateTime? _selectedAnniversary;

  @override
  void initState() {
    super.initState();
    final activeHome = ref.read(activeHomeProvider).value;
    final meta = ref.read(homeMetadataProvider);
    _nameController = TextEditingController(text: activeHome?.name ?? '');
    _descController =
        TextEditingController(text: activeHome?.description ?? '');
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
    final cv = context.cv;
    final activeHome = ref.watch(activeHomeProvider).value;
    final formattedDuration =
        HomeMetadataState.formatDuration(_selectedAnniversary);

    if (activeHome == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + CoveSpace.lg,
        left: CoveSpace.gutter,
        right: CoveSpace.gutter,
        top: CoveSpace.lg,
      ),
      decoration: CoveShape.topDecoration(
        CoveRadius.sheet,
        color: cv.surfaceSheet,
      ),
      child: SingleChildScrollView(
        child: Builder(
          builder: (context) {
            final isScaled = MediaQuery.textScalerOf(context).scale(1.0) > 1.0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'About Us & Home',
                        style: CoveType.slipTitle.copyWith(
                          color: cv.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: cv.textSecondary,
                        size: CoveSpace.gutter,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: CoveSpace.gutter),

                // Home Icon preview
                Center(
                  child: Column(
                    children: [
                      DeterministicHomeIcon(
                        homeId: activeHome.id,
                        size: CoveSize.row,
                      ),
                      const SizedBox(height: CoveSpace.sm),
                      Text(
                        'Unique cryptographic mark derived from your Home key',
                        textAlign: isScaled ? TextAlign.center : null,
                        style: CoveType.rowSub.copyWith(
                          color: cv.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CoveSpace.gutter),

                // Home Name
                Text(
                  'HOME NAME',
                  style: CoveType.capsCard.copyWith(color: cv.textSecondary),
                ),
                const SizedBox(height: CoveSpace.sm),
                CovePillInput(
                  controller: _nameController,
                  hintText: 'e.g. Our Haven, Brooklyn Apt',
                ),
                const SizedBox(height: CoveSpace.gutter),

                // Description
                Text(
                  'DESCRIPTION',
                  style: CoveType.capsCard.copyWith(color: cv.textSecondary),
                ),
                const SizedBox(height: CoveSpace.sm),
                CovePillInput(
                  controller: _descController,
                  hintText: 'A quiet place for both of us',
                ),
                const SizedBox(height: CoveSpace.gutter),

                // Anniversary / Moved-in date
                if (isScaled)
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: CoveSpace.sm,
                    runSpacing: CoveSpace.xs,
                    children: [
                      Text(
                        'ANNIVERSARY OR MOVED-IN DATE',
                        style: CoveType.capsCard.copyWith(
                          color: cv.textSecondary,
                        ),
                      ),
                      if (_selectedAnniversary != null)
                        GestureDetector(
                          onTap: () {
                            setState(() => _selectedAnniversary = null);
                          },
                          child: Text(
                            'Clear',
                            style: CoveType.rowSub.copyWith(
                              color: cv.statusAlertText,
                            ),
                          ),
                        ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ANNIVERSARY OR MOVED-IN DATE',
                        style: CoveType.capsCard.copyWith(
                          color: cv.textSecondary,
                        ),
                      ),
                      if (_selectedAnniversary != null)
                        GestureDetector(
                          onTap: () {
                            setState(() => _selectedAnniversary = null);
                          },
                          child: Text(
                            'Clear',
                            style: CoveType.rowSub.copyWith(
                              color: cv.statusAlertText,
                            ),
                          ),
                        ),
                    ],
                  ),
            const SizedBox(height: CoveSpace.sm),
            InkWell(
              customBorder: CoveShape.border(_kDateCardRadius),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedAnniversary ?? clock.now(),
                  firstDate: DateTime(1980),
                  lastDate: clock.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.dark(
                          primary: cv.accentFill,
                          surface: cv.surfaceCard,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: _kCardPaddingH,
                  vertical: CoveSpace.md,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: _kCalendarIconSize,
                      color: cv.accentFill,
                    ),
                    const SizedBox(width: CoveSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedAnniversary != null
                                ? DateFormat('MMMM d, yyyy')
                                    .format(_selectedAnniversary!)
                                : 'Select date (optional)',
                            style: CoveType.rowTitle.copyWith(
                              color: cv.textPrimary,
                            ),
                          ),
                          if (formattedDuration != null) ...[
                            const SizedBox(height: CoveSpace.xs),
                            Text(
                              formattedDuration,
                              style: CoveType.rowSub.copyWith(
                                color: cv.accentText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: cv.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: CoveSpace.sm),
            Text(
              'Shared quietly between the two of you. Never external or public.',
              style: CoveType.rowSub.copyWith(color: cv.textSecondary),
            ),

            const SizedBox(height: _kSaveButtonTopGap),

            // Save Button
            CovePillButton(
              label: 'Save Home Details',
              onPressed: () async {
                final newName = _nameController.text.trim();
                if (newName.isNotEmpty) {
                  await ref
                      .read(homeMetadataProvider.notifier)
                      .updateHomeDetails(
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
        );
          },
        ),
      ),
    );
  }
}
