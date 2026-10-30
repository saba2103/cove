import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_round_button.dart';
import '../../core/widgets/cove_row.dart';
import '../../core/widgets/cove_sheet.dart';
import '../../sync/db/app_database.dart';
import 'pet_controller.dart';

/// **"About a pet?"** multi-select chip row shown underneath every kind's
/// owner/who step in the Add flow when the home has at least one active pet
/// (`design/specs/19-owners-and-pets.md` §3).
class AddAboutAPetRow extends StatelessWidget {
  final List<LocalPet> pets;
  final Set<String> selectedPetIds;
  final ValueChanged<String> onTogglePet;

  static const double _kChipBorderWidth = 1.0; // (literal) 1dp hairline border
  static const double _kPawIconSize = 14.0; // (literal) 14dp paw glyph

  const AddAboutAPetRow({
    super.key,
    required this.pets,
    required this.selectedPetIds,
    required this.onTogglePet,
  });

  @override
  Widget build(BuildContext context) {
    if (pets.isEmpty) return const SizedBox.shrink();
    final cv = context.cv;

    return Column(
      key: const ValueKey('add_about_a_pet_row'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: CoveSpace.lg),
        Text(
          'About a pet?',
          style: CoveType.rowSub.copyWith(color: cv.textSecondary),
        ),
        const SizedBox(height: CoveSpace.sm),
        Wrap(
          spacing: CoveSpace.sm,
          runSpacing: CoveSpace.sm,
          children: [
            for (final pet in pets)
              _AddPetChip(
                key: ValueKey('add_pet_chip_${pet.id}'),
                pet: pet,
                selected: selectedPetIds.contains(pet.id),
                onTap: () => onTogglePet(pet.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _AddPetChip extends StatelessWidget {
  final LocalPet pet;
  final bool selected;
  final VoidCallback onTap;

  const _AddPetChip({
    super.key,
    required this.pet,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Semantics(
      button: true,
      selected: selected,
      label: pet.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CoveSpace.md,
            vertical: CoveSpace.sm,
          ),
          decoration: CoveShape.decoration(
            CoveRadius.pill,
            color: selected ? cv.accentWash : cv.surfaceRow,
            side: BorderSide(
              color: selected ? cv.accentFill : cv.lineHairline,
              width: AddAboutAPetRow._kChipBorderWidth,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pets_outlined,
                size: AddAboutAPetRow._kPawIconSize,
                color: selected ? cv.accentText : cv.textSecondary,
              ),
              const SizedBox(width: CoveSpace.xs),
              Text(
                pet.name,
                style: CoveType.readout.copyWith(
                  color: selected ? cv.accentText : cv.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pet tag chips rendered directly under the meaning panel in detail
/// sheets (`design/specs/19-owners-and-pets.md` §3).
///
/// Archived pets stay on old records, greyed out (`isArchived == true`).
class RecordPetTagChips extends StatelessWidget {
  final List<LocalPet> pets;
  final VoidCallback? onTap;

  static const double _kChipBorderWidth = 1.0; // (literal) 1dp chip border
  static const double _kPawIconSize = 13.0; // (literal) 13dp small paw icon

  const RecordPetTagChips({
    super.key,
    required this.pets,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (pets.isEmpty) return const SizedBox.shrink();

    return Wrap(
      key: const ValueKey('record_pet_tag_chips'),
      spacing: CoveSpace.sm,
      runSpacing: CoveSpace.xs,
      children: [
        for (final pet in pets)
          _RecordPetChip(
            key: ValueKey('record_pet_chip_${pet.id}'),
            pet: pet,
            onTap: onTap,
          ),
      ],
    );
  }
}

class _RecordPetChip extends StatelessWidget {
  final LocalPet pet;
  final VoidCallback? onTap;

  const _RecordPetChip({
    super.key,
    required this.pet,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final archived = pet.isArchived;

    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CoveSpace.md,
        vertical: CoveSpace.xs,
      ),
      decoration: CoveShape.decoration(
        CoveRadius.pill,
        color: archived ? cv.surfaceRow : cv.accentWash,
        side: BorderSide(
          color: cv.lineControl,
          width: RecordPetTagChips._kChipBorderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pets_outlined,
            size: RecordPetTagChips._kPawIconSize,
            color: archived ? cv.textTertiary : cv.accentText,
          ),
          const SizedBox(width: CoveSpace.xs),
          Text(
            pet.name,
            style: CoveType.rowSub.copyWith(
              color: archived ? cv.textTertiary : cv.accentText,
            ),
          ),
        ],
      ),
    );

    final wrapped = archived
        ? KeyedSubtree(
            key: ValueKey('record_pet_chip_archived_${pet.id}'),
            child: chip,
          )
        : chip;

    if (onTap == null) return wrapped;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: wrapped,
    );
  }
}

/// Returns the overflow menu label (`'Tag a pet…'` when untagged, or
/// `'Change pets…'` when at least one pet is tagged) for a detail sheet's `⋯`
/// menu (`design/specs/19-owners-and-pets.md` §3).
String petTagMenuLabel(List<LocalPet> taggedPets) {
  return taggedPets.isEmpty ? 'Tag a pet…' : 'Change pets…';
}

/// Modal picker sheet opened from `⋯` → `'Tag a pet…'` / `'Change pets…'` on
/// any record detail sheet (`design/specs/19-owners-and-pets.md` §3).
class PetTagPickerSheet extends ConsumerWidget {
  final String recordKind;
  final String recordId;
  final bool isPrivate;

  static const double _kLeadingOrbIconSize = 16.0; // (literal) 16dp orb icon
  static const double _kCheckBorderWidth = 1.5; // (literal) 1.5dp check border
  static const double _kCheckBoxSize = 22.0; // (literal) 22dp check indicator
  static const double _kCheckIconSize = 14.0; // (literal) 14dp check mark

  const PetTagPickerSheet({
    super.key,
    required this.recordKind,
    required this.recordId,
    this.isPrivate = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String recordKind,
    required String recordId,
    bool isPrivate = false,
  }) {
    return CoveSheet.show<void>(
      context: context,
      barrierLabel: 'Dismiss pet picker sheet',
      builder: (_) => PetTagPickerSheet(
        recordKind: recordKind,
        recordId: recordId,
        isPrivate: isPrivate,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cv = context.cv;
    final allPets =
        ref.watch(activeHomePetsProvider).value ?? const <LocalPet>[];
    final taggedPets = ref.watch(
      recordPetTagsProvider((recordKind: recordKind, recordId: recordId)),
    );
    final taggedIds = taggedPets.map((p) => p.id).toSet();

    // Show all active pets plus any archived pets currently tagged on this record.
    final visiblePets = allPets
        .where((p) => !p.isArchived || taggedIds.contains(p.id))
        .toList(growable: false);

    return CoveSheet(
      child: Column(
        key: const ValueKey('pet_tag_picker_sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  taggedIds.isEmpty ? 'Tag a pet' : 'Change pets',
                  style: CoveType.title.copyWith(color: cv.textPrimary),
                ),
              ),
              CoveRoundButton(
                key: const ValueKey('pet_tag_picker_close_button'),
                icon: Icons.close_rounded,
                variant: CoveRoundButtonVariant.ghost,
                semanticLabel: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: CoveSpace.md),
          if (visiblePets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CoveSpace.md),
              child: Text(
                'No pets in your home yet. Add one in Our home → Pets.',
                style: CoveType.body.copyWith(color: cv.textSecondary),
              ),
            )
          else
            for (var i = 0; i < visiblePets.length; i++)
              Builder(
                builder: (context) {
                  final pet = visiblePets[i];
                  final isTagged = taggedIds.contains(pet.id);
                  return CoveRow(
                    key: ValueKey('pet_picker_row_${pet.id}'),
                    leading: SizedBox(
                      width: CoveSize.avatarRow,
                      height: CoveSize.avatarRow,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cv.accentWash,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.pets_outlined,
                            size: _kLeadingOrbIconSize,
                            color: pet.isArchived
                                ? cv.textTertiary
                                : cv.accentText,
                          ),
                        ),
                      ),
                    ),
                    title: pet.name,
                    subtitle: pet.isArchived ? 'Archived' : null,
                    trailing: Container(
                      width: _kCheckBoxSize,
                      height: _kCheckBoxSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isTagged ? cv.accentFill : Colors.transparent,
                        border: isTagged
                            ? null
                            : Border.all(
                                color: cv.lineControl,
                                width: _kCheckBorderWidth,
                              ),
                      ),
                      alignment: Alignment.center,
                      child: isTagged
                          ? Icon(
                              Icons.check_rounded,
                              size: _kCheckIconSize,
                              color: cv.textOnAccent,
                            )
                          : null,
                    ),
                    isLast: i == visiblePets.length - 1,
                    onTap: () async {
                      final ctrl = ref.read(petControllerProvider);
                      if (isTagged) {
                        await ctrl.removePetTag(
                          petId: pet.id,
                          recordKind: recordKind,
                          recordId: recordId,
                          isPrivate: isPrivate,
                        );
                      } else {
                        await ctrl.addPetTag(
                          petId: pet.id,
                          recordKind: recordKind,
                          recordId: recordId,
                          isPrivate: isPrivate,
                        );
                      }
                    },
                  );
                },
              ),
          const SizedBox(height: CoveSpace.lg),
          CovePillButton(
            key: const ValueKey('pet_tag_picker_done_button'),
            label: 'Done',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
