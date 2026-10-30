import 'package:flutter/material.dart';

import '../../../core/shape/cove_shape.dart';
import '../../../core/theme/cove_tokens.dart';
import '../../../core/widgets/cove_avatar.dart';
import '../../../core/widgets/cove_toggle_switch.dart';

/// Data for a person tile in [AddPersonPicker] (`design/specs/14-add-flow.md` §3 **person**).
@immutable
class AddPersonTileData<T> {
  final T value;
  final CovePerson person;
  final String label;
  final String? nameOrInitial;
  final bool enabled;

  const AddPersonTileData({
    required this.value,
    required this.person,
    required this.label,
    this.nameOrInitial,
    this.enabled = true,
  });
}

/// Data for a toggle row beneath the person tiles in [AddPersonPicker]
/// (`design/specs/14-add-flow.md` §3 **person** & §5).
@immutable
class AddToggleRowData {
  final String id;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AddToggleRowData({
    required this.id,
    required this.title,
    this.subtitle,
    this.icon,
    required this.value,
    this.onChanged,
  });
}

/// Person tiles (`CoveAvatar.profile`) and toggle rows (`CoveToggleSwitch`)
/// for **person** steps (`design/specs/14-add-flow.md` §3 **person**, matching
/// `05-expense-5-who.png` and `12-event-5-who.png`).
///
/// - Renders the individual person tiles (`CovePerson.a` / `CovePerson.b`) side
///   by side, and an optional joint `Both of you` tile (`CovePerson.both`) as a
///   full-width horizontal card below them.
/// - Renders [toggles] beneath the tiles using [CoveToggleSwitch].
/// - Every interactive tile and toggle row is at least `48 × 48dp` ([CoveSize.hit]).
class AddPersonPicker<T> extends StatelessWidget {
  final List<AddPersonTileData<T>> people;
  final T? selectedValue;
  final ValueChanged<T> onSelected;
  final List<AddToggleRowData> toggles;

  static const double _kSelectedBorder = 1.5; // (literal) 1.5dp selected border
  static const double _kNormalBorder = 1.0; // (literal) 1dp card border
  static const double _kDisabledOpacity = 0.4; // (literal) disabled partner tile opacity
  static const double _kToggleIconSize = 18.0; // (literal) 18dp leading toggle icon

  const AddPersonPicker({
    super.key,
    required this.people,
    required this.selectedValue,
    required this.onSelected,
    this.toggles = const <AddToggleRowData>[],
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final stackIndividuals = textScale > 1.0 &&
        (MediaQuery.sizeOf(context).width / textScale) <
            CoveSize.compactThreshold;
    final individuals =
        people.where((p) => p.person != CovePerson.both).toList();
    final bothTiles =
        people.where((p) => p.person == CovePerson.both).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (individuals.isNotEmpty)
          if (stackIndividuals)
            for (var i = 0; i < individuals.length; i++) ...[
              if (i > 0) const SizedBox(height: CoveSpace.md),
              _IndividualPersonTile<T>(
                tile: individuals[i],
                selected: selectedValue == individuals[i].value,
                onTap: individuals[i].enabled
                    ? () => onSelected(individuals[i].value)
                    : null,
              ),
            ]
          else
            Row(
              children: [
                for (var i = 0; i < individuals.length; i++) ...[
                  if (i > 0) const SizedBox(width: CoveSpace.md),
                  Expanded(
                    child: _IndividualPersonTile<T>(
                      tile: individuals[i],
                      selected: selectedValue == individuals[i].value,
                      onTap: individuals[i].enabled
                          ? () => onSelected(individuals[i].value)
                          : null,
                    ),
                  ),
                ],
              ],
            ),
        for (final both in bothTiles) ...[
          const SizedBox(height: CoveSpace.md),
          _BothPersonTile<T>(
            tile: both,
            selected: selectedValue == both.value,
            onTap: both.enabled ? () => onSelected(both.value) : null,
          ),
        ],
        if (toggles.isNotEmpty) ...[
          const SizedBox(height: CoveSpace.md),
          for (var i = 0; i < toggles.length; i++) ...[
            if (i > 0) const SizedBox(height: CoveSpace.sm),
            _PersonToggleRow(row: toggles[i]),
          ],
        ],
      ],
    );
  }
}

class _IndividualPersonTile<T> extends StatelessWidget {
  final AddPersonTileData<T> tile;
  final bool selected;
  final VoidCallback? onTap;

  const _IndividualPersonTile({
    required this.tile,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    final card = Opacity(
      opacity: tile.enabled ? 1.0 : AddPersonPicker._kDisabledOpacity,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: CoveSize.hit,
          minHeight: CoveSize.hit,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: CoveSpace.md,
          vertical: CoveSpace.lg,
        ),
        decoration: CoveShape.decoration(
          CoveRadius.card,
          color: selected ? cv.accentWash : cv.surfaceRow,
          side: BorderSide(
            color: selected ? cv.accentFill : cv.lineStrong,
            width: selected
                ? AddPersonPicker._kSelectedBorder
                : AddPersonPicker._kNormalBorder,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoveAvatar.profile(
              person: tile.person,
              nameOrInitial: tile.nameOrInitial ?? tile.label,
            ),
            const SizedBox(height: CoveSpace.md),
            Text(
              tile.label,
              textAlign: TextAlign.center,
              style: CoveType.rowTitle.copyWith(
                color: selected ? cv.textPrimary : cv.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      button: true,
      enabled: tile.enabled,
      selected: selected,
      label: tile.label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: card,
        ),
      ),
    );
  }
}

class _BothPersonTile<T> extends StatelessWidget {
  final AddPersonTileData<T> tile;
  final bool selected;
  final VoidCallback? onTap;

  const _BothPersonTile({
    required this.tile,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    final card = Opacity(
      opacity: tile.enabled ? 1.0 : AddPersonPicker._kDisabledOpacity,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: CoveSize.hit,
          minHeight: CoveSize.hit,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: CoveSpace.gutter,
          vertical: CoveSpace.md,
        ),
        decoration: CoveShape.decoration(
          CoveRadius.card,
          color: selected ? cv.accentWash : cv.surfaceRow,
          side: BorderSide(
            color: selected ? cv.accentFill : cv.lineStrong,
            width: selected
                ? AddPersonPicker._kSelectedBorder
                : AddPersonPicker._kNormalBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CoveAvatar.profile(person: CovePerson.both),
            const SizedBox(width: CoveSpace.md),
            Flexible(
              child: Text(
                tile.label,
                style: CoveType.rowTitle.copyWith(
                  color: selected ? cv.textPrimary : cv.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      button: true,
      enabled: tile.enabled,
      selected: selected,
      label: tile.label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: card,
        ),
      ),
    );
  }
}

class _PersonToggleRow extends StatelessWidget {
  final AddToggleRowData row;

  const _PersonToggleRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final hasSubtitle =
        row.subtitle != null && row.subtitle!.trim().isNotEmpty;
    final canToggle = row.onChanged != null;

    return Semantics(
      container: true,
      toggled: row.value,
      enabled: canToggle,
      label: hasSubtitle ? '${row.title}, ${row.subtitle}' : row.title,
      onTap: canToggle ? () => row.onChanged!(!row.value) : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canToggle ? () => row.onChanged!(!row.value) : null,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: CoveSize.hit,
              minHeight: CoveSize.row,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.gutter,
              vertical: CoveSpace.md,
            ),
            decoration: CoveShape.decoration(
              CoveRadius.card,
              color: cv.surfaceRow,
              side: BorderSide(
                color: cv.lineStrong,
                width: AddPersonPicker._kNormalBorder,
              ),
            ),
            child: Row(
              children: [
                if (row.icon != null) ...[
                  Icon(
                    row.icon,
                    size: AddPersonPicker._kToggleIconSize,
                    color: cv.textTertiary,
                  ),
                  const SizedBox(width: CoveSpace.md),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title,
                        style: CoveType.rowTitle.copyWith(
                          color: cv.textPrimary,
                        ),
                      ),
                      if (hasSubtitle) ...[
                        const SizedBox(height: CoveSpace.xs),
                        Text(
                          row.subtitle!,
                          style: CoveType.rowSub.copyWith(
                            color: cv.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: CoveSpace.md),
                // Pass onChanged: null so the entire row GestureDetector (≥ 48×48dp)
                // handles the tap without a nested 46×26dp GestureDetector.
                CoveToggleSwitch(
                  value: row.value,
                  onChanged: null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
