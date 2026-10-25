import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_page_header.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../profile/preferences_controller.dart';
import 'monthly_budget_controller.dart';

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
  static const double _kHandleWidth =
      36.0; // (literal) 36dp sheet drag handle width
  static const double _kHandleRadius =
      2.0; // (literal) 2dp sheet drag handle pill corner radius
  static const double _kHandleBottomGap =
      16.0; // (literal) 16dp gap below sheet drag handle
  static const double _kInputHorizontalPadding =
      16.0; // (literal) 16dp budget input card horizontal inset
  static const double _kRemoveIconSize =
      16.0; // (literal) 16dp remove budget button trash icon

  late final TextEditingController _amountController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(monthlyBudgetProvider);
    final initialText = current != null && current > 0
        ? (current % 1 == 0
              ? current.toInt().toString()
              : current.toStringAsFixed(2))
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
    } else if (currencyCode.toUpperCase() == 'EUR' ||
        currencyCode.toUpperCase() == 'GBP') {
      return [500, 1000, 1500, 2500, 4000];
    } else if (currencyCode.toUpperCase() == 'JPY') {
      return [50000, 100000, 150000, 250000, 400000];
    }
    return [500, 1000, 2000, 3500, 5000];
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final currency = ref.watch(currencyPreferenceProvider);
    final currentBudget = ref.watch(monthlyBudgetProvider);
    final presets = _getPresetValues(currency.code);

    return Container(
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            CovePageInsets.bottomOf(context) +
            CoveSpace.lg,
        left: CoveSpace.gutter,
        right: CoveSpace.gutter,
        top: CoveSpace.gutter,
      ),
      decoration: BoxDecoration(
        color: cv.surfaceSheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(CoveRadius.sheet),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top drag handle
            Center(
              child: Container(
                width: _kHandleWidth,
                height: CoveSpace.xs,
                margin: const EdgeInsets.only(bottom: _kHandleBottomGap),
                decoration: BoxDecoration(
                  color: cv.lineHairline,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(_kHandleRadius),
                  ),
                ),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.pie_chart_outline_rounded,
                      color: cv.accentFill,
                      size: CoveSize.avatarInline,
                    ),
                    const SizedBox(width: CoveSpace.sm),
                    Text(
                      currentBudget != null
                          ? 'Edit Monthly Budget'
                          : 'Set Monthly Budget',
                      style: CoveType.letter.copyWith(color: cv.textPrimary),
                    ),
                  ],
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
            const SizedBox(height: CoveSpace.sm),
            Text(
              'Set a target expenditure for your home. You and your partner will see remaining budget and alerts if spending shoots up.',
              style: CoveType.readout.copyWith(
                color: cv.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: CoveSpace.gutter),

            // Amount Input Card
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: _kInputHorizontalPadding,
                vertical: CoveSpace.md,
              ),
              decoration: BoxDecoration(
                color: cv.surfaceRow,
                borderRadius: const BorderRadius.all(
                  Radius.circular(CoveRadius.inline),
                ),
                border: Border.all(color: cv.lineHairline),
              ),
              child: Row(
                children: [
                  Text(
                    currency.symbol,
                    style: CoveType.cardFigure.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cv.accentTint,
                    ),
                  ),
                  const SizedBox(width: CoveSpace.sm),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: CoveType.cardFigure.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cv.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: CoveType.cardFigure.copyWith(
                          color: cv.textTertiary,
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
            const SizedBox(height: CoveSpace.md),

            // Quick Preset Chips
            Wrap(
              spacing: CoveSpace.sm,
              runSpacing: CoveSpace.sm,
              children: presets.map((val) {
                final formatted = formatCoveIntegerAmount(val);
                return InkWell(
                  onTap: () {
                    setState(() {
                      _amountController.text = val.toInt().toString();
                    });
                  },
                  borderRadius: const BorderRadius.all(
                    Radius.circular(CoveRadius.pill),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CoveSpace.md,
                      vertical: CoveSpace.sm,
                    ),
                    decoration: BoxDecoration(
                      color: cv.surfaceRow,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(CoveRadius.pill),
                      ),
                      border: Border.all(color: cv.lineHairline),
                    ),
                    child: Text(
                      '${currency.symbol}$formatted',
                      style: CoveType.rowSub.copyWith(
                        color: cv.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: CoveSpace.lg),

            // Save and optional clear button
            if (currentBudget != null) ...[
              Center(
                child: TextButton.icon(
                  icon: Icon(
                    Icons.delete_outline,
                    size: _kRemoveIconSize,
                    color: cv.statusAlert,
                  ),
                  label: Text(
                    'Remove Budget Target',
                    style: CoveType.rowSub.copyWith(color: cv.statusAlertText),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          await ref
                              .read(monthlyBudgetProvider.notifier)
                              .clearBudget();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                ),
              ),
              const SizedBox(height: CoveSpace.sm),
            ],

            CovePillButton(
              label: _isSaving
                  ? 'Saving...'
                  : (currentBudget != null ? 'Update Budget' : 'Save Budget'),
              onPressed: _isSaving
                  ? null
                  : () async {
                      final parsed = double.tryParse(
                        _amountController.text.trim().replaceAll(',', ''),
                      );
                      if (parsed == null || parsed <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid budget amount'),
                          ),
                        );
                        return;
                      }
                      setState(() => _isSaving = true);
                      await ref
                          .read(monthlyBudgetProvider.notifier)
                          .setBudget(parsed);
                      if (context.mounted) Navigator.of(context).pop();
                    },
            ),
          ],
        ),
      ),
    );
  }
}
