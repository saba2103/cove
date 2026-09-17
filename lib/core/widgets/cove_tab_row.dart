import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/cove_theme.dart';

class CoveTabRow extends StatelessWidget {
  final List<String> tabs;
  final List<Key>? tabKeys;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final ReorderCallback? onReorder;
  final Widget? trailing;

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
    final colors = context.colors;

    if (onReorder != null) {
      return SizedBox(
        height: 44,
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
                final double animValue = Curves.easeInOut.transform(animation.value);
                final double scale = ui.lerpDouble(1, 1.05, animValue)!;
                return Material(
                  color: Colors.transparent,
                  shadowColor: Colors.black.withValues(alpha: 0.35),
                  elevation: 6 * animValue,
                  borderRadius: BorderRadius.circular(8),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: colors.surfaceCard.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colors.accentPrimary.withValues(alpha: 0.4 * animValue),
                          width: 1,
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
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
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
          ...List.generate(tabs.length, (index) => _buildTabItem(context, index)),
          if (trailing != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, int index) {
    final colors = context.colors;
    final isSelected = index == selectedIndex;
    final key = (tabKeys != null && index < tabKeys!.length)
        ? tabKeys![index]
        : ValueKey('tab_${tabs[index]}_$index');

    final tabWidget = InkWell(
      onTap: () => onTabSelected(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(right: 24, top: 8, bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tabs[index],
              style: TextStyle(
                fontFamily: 'GeneralSans',
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? colors.textPrimary : colors.textSubtle,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              height: 2,
              width: isSelected ? 28 : 0,
              decoration: BoxDecoration(
                color: isSelected ? colors.accentPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
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
