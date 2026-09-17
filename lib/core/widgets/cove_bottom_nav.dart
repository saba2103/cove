import 'package:flutter/material.dart';
import '../theme/cove_theme.dart';

class CoveBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CoveBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<IconData> navIcons = [
    Icons.home_outlined, // 0: Home
    Icons.autorenew_outlined, // 1: Commitments
    Icons.calendar_month_rounded, // 2: Calendar (Protruding Middle)
    Icons.checklist_rtl_outlined, // 3: Lists
    Icons.account_balance_wallet_outlined, // 4: Expenses
  ];

  static const List<String> navTooltips = [
    'Home',
    'Commitments',
    'Calendar',
    'Lists',
    'Expenses',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Main bottom nav bar container
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            border: Border(
              top: BorderSide(
                color: colors.borderHairline,
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  _buildNavItem(0, colors),
                  _buildNavItem(1, colors),
                  // Middle item space for the protruding circle button
                  Expanded(
                    child: InkWell(
                      onTap: () => onTap(2),
                      splashColor: colors.accentPrimary.withValues(alpha: 0.08),
                      highlightColor: Colors.transparent,
                      child: const SizedBox(height: 60),
                    ),
                  ),
                  _buildNavItem(3, colors),
                  _buildNavItem(4, colors),
                ],
              ),
            ),
          ),
        ),

        // Special protruding circular Calendar button
        Positioned(
          top: -18,
          child: _buildCenterCalendarButton(context, colors),
        ),
      ],
    );
  }

  Widget _buildNavItem(int index, CoveColors colors) {
    final isSelected = index == currentIndex;
    final iconColor = isSelected ? colors.accentPrimary : colors.textSubtle;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        splashColor: colors.accentPrimary.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: Center(
          child: Tooltip(
            message: navTooltips[index],
            child: Icon(
              navIcons[index],
              size: 22,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterCalendarButton(BuildContext context, CoveColors colors) {
    final isSelected = currentIndex == 2;
    final isDark = context.isDark;

    return Semantics(
      button: true,
      label: 'Calendar',
      selected: isSelected,
      child: GestureDetector(
        onTap: () => onTap(2),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? colors.accentPrimary : colors.surfaceCard,
            border: Border.all(
              color: isSelected
                  ? (isDark ? const Color(0xFF1E2D2B) : Colors.white)
                  : colors.borderHairline,
              width: isSelected ? 3 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? colors.accentPrimary.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: isSelected ? 12 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.calendar_month_rounded,
              size: 23,
              color: isSelected
                  ? (isDark ? const Color(0xFF0B1F1E) : Colors.white)
                  : colors.accentPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
