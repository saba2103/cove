import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../profile/preferences_controller.dart';
import 'monthly_budget_controller.dart';
import '../../core/utils/cove_currency_formatter.dart';

class MonthlyBudgetSheet extends ConsumerStatefulWidget {
  const MonthlyBudgetSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MonthlyBudgetSheet(),
    );
  }

  @override
  ConsumerState<MonthlyBudgetSheet> createState() => _MonthlyBudgetSheetState();
}

class _MonthlyBudgetSheetState extends ConsumerState<MonthlyBudgetSheet> {
  late final TextEditingController _amountController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(monthlyBudgetProvider);
    final initialText = current != null && current > 0
        ? (current % 1 == 0 ? current.toInt().toString() : current.toStringAsFixed(2))
        : '';
    _amountController = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  List<double> _getPresetValues(String currencyCode) {
    if (currencyCode.toUpperCase() == 'INR') {
      return [20000, 35000, 50000, 75000, 100000];
    } else if (currencyCode.toUpperCase() == 'EUR' || currencyCode.toUpperCase() == 'GBP') {
      return [500, 1000, 1500, 2500, 4000];
    } else if (currencyCode.toUpperCase() == 'JPY') {
      return [50000, 100000, 150000, 250000, 400000];
    }
    return [500, 1000, 2000, 3500, 5000];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final currency = ref.watch(currencyPreferenceProvider);
    final currentBudget = ref.watch(monthlyBudgetProvider);
    final presets = _getPresetValues(currency.code);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 20,
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
            // Top drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.borderHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, color: colors.accentPrimary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      currentBudget != null ? 'Edit Monthly Budget' : 'Set Monthly Budget',
                      style: typography.headline.copyWith(fontSize: 18),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textMuted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Set a target expenditure for your home. You and your partner will see remaining budget and alerts if spending shoots up.',
              style: typography.bodyRegular.copyWith(
                fontSize: 13,
                color: colors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Amount Input Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surfaceRow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.borderHairline),
              ),
              child: Row(
                children: [
                  Text(
                    currency.symbol,
                    style: TextStyle(
                      fontFamily: 'BodoniModa',
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: colors.accentTint,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontFamily: 'BodoniModa',
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(
                          fontFamily: 'BodoniModa',
                          fontSize: 28,
                          color: colors.textSubtle,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Quick Preset Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((val) {
                final formatted = formatCoveIntegerAmount(val);
                return InkWell(
                  onTap: () {
                    setState(() {
                      _amountController.text = val.toInt().toString();
                    });
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.surfaceRow,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: colors.borderHairline),
                    ),
                    child: Text(
                      '${currency.symbol}$formatted',
                      style: typography.caption.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Save and optional clear button
            if (currentBudget != null) ...[
              Center(
                child: TextButton.icon(
                  icon: Icon(Icons.delete_outline, size: 16, color: colors.accentSecondary),
                  label: Text(
                    'Remove Budget Target',
                    style: typography.caption.copyWith(color: colors.accentSecondary),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          await ref.read(monthlyBudgetProvider.notifier).clearBudget();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                ),
              ),
              const SizedBox(height: 8),
            ],

            CovePillButton(
              label: _isSaving ? 'Saving...' : (currentBudget != null ? 'Update Budget' : 'Save Budget'),
              onPressed: _isSaving
                  ? null
                  : () async {
                      final parsed = double.tryParse(_amountController.text.trim().replaceAll(',', ''));
                      if (parsed == null || parsed <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid budget amount')),
                        );
                        return;
                      }
                      setState(() => _isSaving = true);
                      await ref.read(monthlyBudgetProvider.notifier).setBudget(parsed);
                      if (context.mounted) Navigator.of(context).pop();
                    },
            ),
          ],
        ),
      ),
    );
  }
}
