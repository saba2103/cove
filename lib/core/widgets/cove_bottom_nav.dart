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
    Icons.space_dashboard_outlined, // Dashboard
    Icons.autorenew_outlined, // Subscriptions / Recurring
    Icons.checklist_rtl_outlined, // Shared Lists
    Icons.account_balance_wallet_outlined, // Expenses
    Icons.more_horiz_outlined, // More / Settings / Profile
  ];

  static const List<String> navTooltips = [
    'Dashboard',
    'Subscriptions',
    'Lists',
    'Expenses',
    'More',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navIcons.length, (index) {
              final isSelected = index == currentIndex;
              final iconColor =
                  isSelected ? colors.accentPrimary : colors.textSubtle;

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
            }),
          ),
        ),
      ),
    );
  }
}
