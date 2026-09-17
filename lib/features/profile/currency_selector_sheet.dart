import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_grouped_list.dart';
import 'preferences_controller.dart';

class CurrencySelectorSheet extends ConsumerWidget {
  const CurrencySelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CurrencySelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final currentCurrency = ref.watch(currencyPreferenceProvider);

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Preferred Currency', style: typography.headline.copyWith(fontSize: 20)),
              IconButton(
                icon: Icon(Icons.close, color: colors.textMuted, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CoveGroupedCard(
            children: supportedCurrencies.map((currency) {
              final isSelected = currency.code == currentCurrency.code;
              return CoveGroupedRow(
                leading: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surfaceRow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    currency.symbol,
                    style: typography.title.copyWith(fontSize: 16, color: colors.accentPrimary),
                  ),
                ),
                title: Text('${currency.name} (${currency.code})', style: typography.bodyMedium),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: colors.accentPrimary, size: 20)
                    : null,
                onTap: () async {
                  await ref.read(currencyPreferenceProvider.notifier).setCurrency(currency);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
