import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';

class CoveTabRow extends StatelessWidget {
  final List<String> tabs;
  final List<Key>? tabKeys;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final ReorderCallback? onReorder;
  final Widget? trailing;

  static const double _kReorderRowHeight =
      44.0; // (literal) 44dp horizontal reorder tab strip height
  static const double _kProxyBorderWidth =
      1.0; // (literal) 1dp proxy border stroke
  static const double _kIndicatorHeight =
      2.0; // (literal) 2dp active tab underline rule

  const CoveTabRow({
    super.key,
    required this.tabs,
    this.tabKeys,
    required this.selectedIndex,
    required this.onTabSelected,
    this.onReorder,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    if (onReorder != null) {
      return SizedBox(
        height: _kReorderRowHeight,
        child: ReorderableListView.builder(
          scrollDirection: Axis.horizontal,
          buildDefaultDragHandles: false,
          itemCount: tabs.length,
          itemBuilder: (context, index) => _buildTabItem(context, index),
          onReorderItem: onReorder!,
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (BuildContext context, Widget? child) {
                final double animValue =
                    CoveMotion.easing.transform(animation.value);
                final double scale = ui.lerpDouble(1, 1.05, animValue)!;
                return Material(
                  color: Colors.transparent,
                  shadowColor: cv.surfaceScrim,
                  elevation: 6 * animValue,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(CoveRadius.inline),
                  ),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CoveSpace.xs,
                      ),
                      decoration: BoxDecoration(
                        color: cv.surfaceCard.withValues(alpha: 0.92),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(CoveRadius.inline),
                        ),
                        border: Border.all(
                          color: cv.accentFill.withValues(
                            alpha: 0.4 * animValue,
                          ),
                          width: _kProxyBorderWidth,
                        ),
                      ),
                      child: child,
                    ),
                  ),
                );
              },
              child: child,
            );
          },
          footer: trailing != null
              ? Padding(
                  padding: const EdgeInsets.only(
                    top: CoveSpace.xs,
                    bottom: CoveSpace.xs,
                  ),
                  child: trailing!,
                )
              : null,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(
            tabs.length,
            (index) => _buildTabItem(context, index),
          ),
          if (trailing != null) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: CoveSpace.xs,
                bottom: CoveSpace.xs,
              ),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, int index) {
    final cv = context.cv;
    final duration = CoveMotion.q(context);
    final isSelected = index == selectedIndex;
    final key = (tabKeys != null && index < tabKeys!.length)
        ? tabKeys![index]
        : ValueKey('tab_${tabs[index]}_$index');

    final tabWidget = InkWell(
      onTap: () => onTabSelected(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(
          right: CoveSpace.lg,
          top: CoveSpace.sm,
          bottom: CoveSpace.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tabs[index],
              style: CoveType.rowTitle.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? cv.textPrimary : cv.textTertiary,
              ),
            ),
            const SizedBox(height: CoveSpace.xs),
            AnimatedContainer(
              duration: duration,
              curve: CoveMotion.easing,
              height: _kIndicatorHeight,
              width: isSelected ? CoveSize.avatarRow : 0,
              decoration: BoxDecoration(
                color: isSelected ? cv.accentFill : Colors.transparent,
                borderRadius: const BorderRadius.all(
                  Radius.circular(CoveRadius.pill),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onReorder != null) {
      return ReorderableDelayedDragStartListener(
        key: key,
        index: index,
        child: tabWidget,
      );
    }

    return KeyedSubtree(
      key: key,
      child: tabWidget,
    );
  }
}
