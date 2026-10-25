import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';
import 'cove_page_header.dart';

/// High-level navigation mode for [CoveFloatingBar] (`design/specs/09-floating-bar.md`).
enum CoveFloatingBarMode {
  /// `[Home · Money · Tasks · Calendar]  (+)`
  rest,

  /// `(Home)  [Expenses · Bills · More]  (+)`
  money,

  /// `(Home)  [Todo · Habits]  (+)`
  tasks,

  /// `(Home)  [Day · Routines]  (+)`
  calendar,

  /// Money state with the third seat (`More`) open showing `EMIs`, `The year`.
  more,
}

/// Immutable descriptor for a seat or overflow item in [CoveFloatingBar].
@immutable
class CoveFloatingBarItem {
  final String id;
  final String label;
  final IconData icon;

  const CoveFloatingBarItem({
    required this.id,
    required this.label,
    required this.icon,
  });
}

/// Explicit state object driving [CoveFloatingBar] (`design/specs/09-floating-bar.md`).
///
/// [CoveFloatingBar] is stateless and owns no navigation state of its own;
/// callers pass a [CoveFloatingBarState] and handle tap callbacks.
@immutable
class CoveFloatingBarState {
  final CoveFloatingBarMode mode;
  final String selectedId;
  final String commitmentsLabel;

  const CoveFloatingBarState({
    required this.mode,
    required this.selectedId,
    this.commitmentsLabel = 'Bills',
  });

  /// Rest state: `[Home · Money · Tasks · Calendar]  (+)`.
  const CoveFloatingBarState.rest({
    this.selectedId = 'home',
  }) : mode = CoveFloatingBarMode.rest,
       commitmentsLabel = 'Bills';

  /// Money category detached state: `(Home)  [Expenses · Bills · More]  (+)`.
  const CoveFloatingBarState.money({
    this.selectedId = 'expenses',
    this.commitmentsLabel = 'Bills',
  }) : mode = CoveFloatingBarMode.money;

  /// Tasks category detached state: `(Home)  [Todo · Habits]  (+)`.
  const CoveFloatingBarState.tasks({
    this.selectedId = 'todo',
  }) : mode = CoveFloatingBarMode.tasks,
       commitmentsLabel = 'Bills';

  /// Calendar category detached state: `(Home)  [Day · Routines]  (+)`.
  const CoveFloatingBarState.calendar({
    this.selectedId = 'day',
  }) : mode = CoveFloatingBarMode.calendar,
       commitmentsLabel = 'Bills';

  /// Money overflow menu open from the third seat (`EMIs`, `The year`).
  const CoveFloatingBarState.more({
    this.selectedId = 'more',
    this.commitmentsLabel = 'Bills',
  }) : mode = CoveFloatingBarMode.more;

  bool get isHomeDetached => mode != CoveFloatingBarMode.rest;

  bool get isMoreMenuOpen => mode == CoveFloatingBarMode.more;

  static const CoveFloatingBarItem homeItem = CoveFloatingBarItem(
    id: 'home',
    label: 'Home',
    icon: Icons.home_outlined,
  );

  static const List<CoveFloatingBarItem> restLeftItems = [
    homeItem,
    CoveFloatingBarItem(
      id: 'money',
      label: 'Money',
      icon: Icons.account_balance_wallet_outlined,
    ),
  ];

  static const List<CoveFloatingBarItem> restRightItems = [
    CoveFloatingBarItem(
      id: 'tasks',
      label: 'Tasks',
      icon: Icons.check_circle_outline_rounded,
    ),
    CoveFloatingBarItem(
      id: 'calendar',
      label: 'Calendar',
      icon: Icons.calendar_today_outlined,
    ),
  ];

  static const List<CoveFloatingBarItem> restItems = [
    ...restLeftItems,
    ...restRightItems,
  ];

  static const List<CoveFloatingBarItem> tasksItems = [
    CoveFloatingBarItem(
      id: 'todo',
      label: 'Todo',
      icon: Icons.checklist_rounded,
    ),
    CoveFloatingBarItem(
      id: 'habits',
      label: 'Habits',
      icon: Icons.repeat_rounded,
    ),
  ];

  static const List<CoveFloatingBarItem> calendarItems = [
    CoveFloatingBarItem(
      id: 'day',
      label: 'Day',
      icon: Icons.wb_sunny_outlined,
    ),
    CoveFloatingBarItem(
      id: 'routines',
      label: 'Routines',
      icon: Icons.schedule_rounded,
    ),
  ];

  static const List<CoveFloatingBarItem> moneyOverflowItems = [
    CoveFloatingBarItem(
      id: 'emis',
      label: 'EMIs',
      icon: Icons.pie_chart_outline_rounded,
    ),
    CoveFloatingBarItem(
      id: 'year',
      label: 'The year',
      icon: Icons.date_range_outlined,
    ),
  ];

  List<CoveFloatingBarItem> get categoryItems {
    switch (mode) {
      case CoveFloatingBarMode.rest:
        return restItems;
      case CoveFloatingBarMode.money:
      case CoveFloatingBarMode.more:
        return [
          const CoveFloatingBarItem(
            id: 'expenses',
            label: 'Expenses',
            icon: Icons.receipt_long_outlined,
          ),
          CoveFloatingBarItem(
            id: 'commitments',
            label: commitmentsLabel,
            icon: Icons.event_repeat_outlined,
          ),
          const CoveFloatingBarItem(
            id: 'more',
            label: 'More',
            icon: Icons.more_horiz_rounded,
          ),
        ];
      case CoveFloatingBarMode.tasks:
        return tasksItems;
      case CoveFloatingBarMode.calendar:
        return calendarItems;
    }
  }
}

/// The floating bottom navigation bar (`design/specs/09-floating-bar.md`).
///
/// Built to the contract in `design/specs/09-floating-bar.md`:
/// - Height: `56` `(literal)`
/// - Radius: [CoveRadius.pill] (`999dp`) for pill & detached Home circle,
///   [CoveRadius.card] (`20dp`) for the More card
/// - Fill: `surface.card` at `92%` + backdrop blur behind
/// - Border: `accent.fill` at `14%`, `1dp` hairline
/// - Shadow: `elevationBar`
/// - Fade behind the bar: `136dp` `(literal)` gradient from transparent to `surface.canvas`
/// - Side margin: [CoveSpace.gutter] (`20dp`)
/// - Bottom margin: [CoveSpace.md] (`12dp`) + bottom inset
/// - Seat: pill, [CoveSpace.sm] (`8dp`) vertical / [CoveSpace.xs] (`4dp`)
///   horizontal padding, [CoveSpace.xs] (`4dp`) icon→label gap
/// - Selected seat: `accent.wash` fill, `accent.text` icon and label
/// - Icon: `20` `(literal)` · Label [CoveType.barLabel]
/// - Below [CoveSize.compactThreshold] (`360dp`) viewport width: icons only, no seat labels
/// - Detached Home circle: `56` `(literal)` on the left in category modes, muted icon (`text.secondary`)
/// - Right `+` orb: `56` `(literal)`, `accent.fill`, `text.onAccent`, separated by [CoveSpace.sm]
class CoveFloatingBar extends StatelessWidget {
  final CoveFloatingBarState state;
  final ValueChanged<String>? onSeatTap;
  final VoidCallback? onAddTap;
  final ValueChanged<String>? onOverflowItemTap;
  final VoidCallback? onDismissMore;

  static const double kHeight = 56.0; // (literal) per 09-floating-bar.md
  static const double kIconSize = 20.0; // (literal) per 09-floating-bar.md
  static const double kOrbSize = 56.0; // (literal) per 09-floating-bar.md
  static const double kFadeHeight =
      136.0; // (literal) 136dp bottom dissolve gradient per 09-floating-bar.md
  static const double kLabelThreshold =
      CoveSize.compactThreshold; // 360dp per 09-floating-bar.md
  static const double _kSurfaceAlpha =
      0.92; // (literal) 92% per 09-floating-bar.md
  static const double _kAccentBorderAlpha =
      0.14; // (literal) accent at 14% hairline per 09-floating-bar.md
  static const double _kBlurSigma = 16.0; // (literal) backdrop blur sigma
  static const double _kBorderWidth = 1.0; // (literal) 1dp hairline border

  const CoveFloatingBar({
    super.key,
    required this.state,
    this.onSeatTap,
    this.onAddTap,
    this.onOverflowItemTap,
    this.onDismissMore,
  });

  void _handleDismissMore() {
    if (onDismissMore != null) {
      onDismissMore!();
    } else if (onSeatTap != null) {
      onSeatTap!('more');
    }
  }

  Widget _buildGlassPill({
    required BuildContext context,
    required Widget child,
    double borderRadius = CoveRadius.pill,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: CoveSpace.xs,
    ),
  }) {
    final cv = context.cv;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        boxShadow: cv.elevationBar,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _kBlurSigma, sigmaY: _kBlurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: cv.surfaceCard.withValues(alpha: _kSurfaceAlpha),
              borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
              border: Border.all(
                color: cv.accentFill.withValues(alpha: _kAccentBorderAlpha),
                width: _kBorderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildSeat({
    required BuildContext context,
    required CoveFloatingBarItem item,
    required bool selected,
  }) {
    final cv = context.cv;
    final duration = CoveMotion.q(context);
    final fg = selected ? cv.accentText : cv.textSecondary;
    final showLabels = MediaQuery.sizeOf(context).width >= kLabelThreshold;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        key: ValueKey('cove_bar_seat_${item.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onSeatTap == null ? null : () => onSeatTap!(item.id),
        child: AnimatedContainer(
          key: ValueKey('cove_bar_seat_box_${item.id}'),
          duration: duration,
          curve: CoveMotion.easing,
          padding: const EdgeInsets.symmetric(
            vertical: CoveSpace.sm,
            horizontal: CoveSpace.xs,
          ),
          decoration: BoxDecoration(
            color: selected ? cv.accentWash : Colors.transparent,
            borderRadius: const BorderRadius.all(
              Radius.circular(CoveRadius.pill),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: kIconSize,
                color: fg,
              ),
              if (showLabels) ...[
                const SizedBox(height: CoveSpace.xs),
                Text(
                  item.label,
                  key: ValueKey('cove_bar_label_${item.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CoveType.barLabel.copyWith(color: fg),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetachedHome({required BuildContext context}) {
    final cv = context.cv;
    final item = CoveFloatingBarState.homeItem;

    return Semantics(
      button: true,
      selected: false,
      label: item.label,
      child: GestureDetector(
        key: ValueKey('cove_bar_seat_${item.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onSeatTap == null ? null : () => onSeatTap!(item.id),
        child: SizedBox(
          key: ValueKey('cove_bar_seat_box_${item.id}'),
          width: kOrbSize,
          height: kOrbSize,
          child: _buildGlassPill(
            context: context,
            padding: EdgeInsets.zero,
            child: Center(
              child: Icon(
                item.icon,
                size: kIconSize,
                color: cv.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddOrb({required BuildContext context}) {
    final cv = context.cv;

    return Semantics(
      button: true,
      label: 'Add',
      child: GestureDetector(
        key: const ValueKey('cove_bar_add_orb'),
        behavior: HitTestBehavior.opaque,
        onTap: onAddTap,
        child: Container(
          width: kOrbSize,
          height: kOrbSize,
          decoration: BoxDecoration(
            color: cv.accentFill,
            shape: BoxShape.circle,
            boxShadow: cv.elevationBar,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.add_rounded,
            size: kIconSize,
            color: cv.textOnAccent,
          ),
        ),
      ),
    );
  }

  Widget _buildOverflowMenu({required BuildContext context}) {
    final cv = context.cv;
    final items = CoveFloatingBarState.moneyOverflowItems;

    return Padding(
      padding: const EdgeInsets.only(bottom: CoveSpace.sm),
      child: SizedBox(
        key: const ValueKey('cove_bar_more_menu'),
        width: double.infinity,
        child: _buildGlassPill(
          context: context,
          borderRadius: CoveRadius.card,
          padding: const EdgeInsets.symmetric(vertical: CoveSpace.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CoveSpace.md,
                    ),
                    child: ColoredBox(
                      color: cv.lineHairline,
                      child: const SizedBox(height: _kBorderWidth),
                    ),
                  ),
                _buildOverflowRow(
                  context: context,
                  item: items[i],
                  selected: state.selectedId == items[i].id,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverflowRow({
    required BuildContext context,
    required CoveFloatingBarItem item,
    required bool selected,
  }) {
    final cv = context.cv;
    final fg = selected ? cv.accentText : cv.textPrimary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        key: ValueKey('cove_bar_overflow_${item.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onOverflowItemTap == null
            ? null
            : () => onOverflowItemTap!(item.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CoveSize.hit),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: CoveSpace.md),
            decoration: BoxDecoration(
              color: selected ? cv.accentWash : Colors.transparent,
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.inline),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: kIconSize,
                  color: fg,
                ),
                const SizedBox(width: CoveSpace.md),
                Expanded(
                  child: Text(
                    item.label,
                    key: ValueKey('cove_bar_overflow_label_${item.id}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoveType.rowTitle.copyWith(color: fg),
                  ),
                ),
                const SizedBox(width: CoveSpace.sm),
                Icon(
                  Icons.chevron_right_rounded,
                  key: ValueKey('cove_bar_overflow_chevron_${item.id}'),
                  size: kIconSize,
                  color: cv.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestBar({required BuildContext context}) {
    final items = state.categoryItems;

    return SizedBox(
      height: kHeight,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: kHeight,
              child: _buildGlassPill(
                context: context,
                child: Row(
                  children: [
                    for (final item in items)
                      Expanded(
                        child: _buildSeat(
                          context: context,
                          item: item,
                          selected: state.selectedId == item.id,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: CoveSpace.sm),
          _buildAddOrb(context: context),
        ],
      ),
    );
  }

  Widget _buildDetachedBar({required BuildContext context}) {
    final items = state.categoryItems;

    return SizedBox(
      height: kHeight,
      child: Row(
        children: [
          _buildDetachedHome(context: context),
          const SizedBox(width: CoveSpace.sm),
          Expanded(
            child: SizedBox(
              height: kHeight,
              child: _buildGlassPill(
                context: context,
                child: Row(
                  children: [
                    for (final item in items)
                      Expanded(
                        child: _buildSeat(
                          context: context,
                          item: item,
                          selected: state.selectedId == item.id ||
                              (item.id == 'more' && state.isMoreMenuOpen),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: CoveSpace.sm),
          _buildAddOrb(context: context),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final bottomInset = CovePageInsets.bottomOf(context);
    final duration = CoveMotion.q(context);
    final fadeTotalHeight = kFadeHeight + bottomInset;

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: fadeTotalHeight,
          child: IgnorePointer(
            child: DecoratedBox(
              key: const ValueKey('cove_bar_bottom_fade'),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cv.surfaceCanvas.withValues(alpha: 0.0),
                    cv.surfaceCanvas,
                  ],
                ),
              ),
            ),
          ),
        ),
        if (state.isMoreMenuOpen)
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey('cove_bar_more_dismiss_area'),
              behavior: HitTestBehavior.translucent,
              onTap: _handleDismissMore,
            ),
          ),
        Padding(
          padding: EdgeInsets.only(
            left: CoveSpace.gutter,
            right: CoveSpace.gutter,
            bottom: CoveSpace.md + bottomInset,
          ),
          child: Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: CoveSize.maxContent),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.isMoreMenuOpen)
                    _buildOverflowMenu(context: context),
                  AnimatedSwitcher(
                    duration: duration,
                    switchInCurve: CoveMotion.easing,
                    switchOutCurve: CoveMotion.easing,
                    child: state.isHomeDetached
                        ? _buildDetachedBar(context: context)
                        : _buildRestBar(context: context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
