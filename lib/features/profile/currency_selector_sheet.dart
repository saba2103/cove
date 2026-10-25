import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_page_header.dart';
import 'preferences_controller.dart';

class CurrencySelectorSheet extends ConsumerWidget {
  const CurrencySelectorSheet({super.key});

  static const double _kHeaderBottomGap =
      16.0; // (literal) 16dp gap below currency sheet header
  static const double _kBadgeSize =
      36.0; // (literal) 36dp currency symbol badge square

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
    final cv = context.cv;
    final currentCurrency = ref.watch(currencyPreferenceProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            CovePageInsets.bottomOf(context) +
            CoveSpace.lg,
        left: CoveSpace.gutter,
        right: CoveSpace.gutter,
        top: CoveSpace.lg,
      ),
      decoration: BoxDecoration(
        color: cv.surfaceSheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(CoveRadius.sheet),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Preferred Currency',
                style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
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
          const SizedBox(height: _kHeaderBottomGap),
          CoveGroupedCard(
            children: supportedCurrencies.map((currency) {
              final isSelected = currency.code == currentCurrency.code;
              return CoveGroupedRow(
                leading: Container(
                  width: _kBadgeSize,
                  height: _kBadgeSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cv.surfaceRow,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(CoveSpace.sm),
                    ),
                  ),
                  child: Text(
                    currency.symbol,
                    style: CoveType.rowTitle.copyWith(color: cv.accentText),
                  ),
                ),
                title: Text(
                  '${currency.name} (${currency.code})',
                  style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle,
                        color: cv.accentFill,
                        size: CoveSpace.gutter,
                      )
                    : null,
                onTap: () async {
                  await ref
                      .read(currencyPreferenceProvider.notifier)
                      .setCurrency(currency);
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
