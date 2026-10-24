import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/cove_tokens.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_avatar.dart';
import '../../core/widgets/cove_detail_sheet.dart';
import '../../core/widgets/slips/cove_dial.dart';
import '../../core/widgets/slips/cove_receipt.dart';
import '../../core/widgets/slips/cove_slip.dart';
import '../../sync/db/app_database.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import 'expense_controller.dart';
import 'expense_detail_sheet.dart';

class CategoryDetailSheet extends ConsumerStatefulWidget {
  final String initialCategoryName;
  final List<LocalExpense> allExpenses;
  final double totalMonthSpend;

  static const double _kDialogBorderWidth =
      1.0; // (literal) 1dp dialog hairline border

  const CategoryDetailSheet({
    super.key,
    required this.initialCategoryName,
    required this.allExpenses,
    required this.totalMonthSpend,
  });

  static Future<void> show(
    BuildContext context, {
    required String categoryName,
    required List<LocalExpense> allExpenses,
    required double totalMonthSpend,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryDetailSheet(
        initialCategoryName: categoryName,
        allExpenses: allExpenses,
        totalMonthSpend: totalMonthSpend,
      ),
    );
  }

  @override
  ConsumerState<CategoryDetailSheet> createState() =>
      _CategoryDetailSheetState();
}

class _CategoryDetailSheetState extends ConsumerState<CategoryDetailSheet> {
  late String _currentCategory;

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.initialCategoryName;
  }

  IconData _getCategoryIcon(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('grocer') || lower.contains('food')) {
      return Icons.local_grocery_store_outlined;
    }
    if (lower.contains('utilit') || lower.contains('home')) {
      return Icons.home_work_outlined;
    }
    if (lower.contains('din') ||
        lower.contains('restaur') ||
        lower.contains('cafe') ||
        lower.contains('eat')) {
      return Icons.restaurant_outlined;
    }
    if (lower.contains('travel') ||
        lower.contains('transport') ||
        lower.contains('flight')) {
      return Icons.flight_takeoff_outlined;
    }
    if (lower.contains('health') ||
        lower.contains('med') ||
        lower.contains('doctor')) {
      return Icons.favorite_border_rounded;
    }
    if (lower.contains('entertain') || lower.contains('movie')) {
      return Icons.movie_creation_outlined;
    }
    if (lower.contains('shop')) {
      return Icons.shopping_bag_outlined;
    }
    return Icons.label_outline_rounded;
  }

  Future<void> _promptRename(BuildContext context) async {
    final cv = context.cv;
    final controller = TextEditingController(text: _currentCategory);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cv.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(CoveRadius.inline),
          ),
          side: BorderSide(
            color: cv.lineHairline,
            width: CategoryDetailSheet._kDialogBorderWidth,
          ),
        ),
        title: Text(
          'Rename Category',
          style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This updates all expenses filed under this category.',
              style: CoveType.readout.copyWith(color: cv.textSecondary),
            ),
            const SizedBox(height: CoveSpace.md),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: CoveType.body.copyWith(color: cv.textPrimary),
              decoration: InputDecoration(
                hintText: 'Category name',
                hintStyle: CoveType.rowSub.copyWith(color: cv.textTertiary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: cv.lineHairline),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: cv.accentFill),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: CoveType.rowTitle.copyWith(color: cv.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                Navigator.of(ctx).pop(trimmed);
              }
            },
            child: Text(
              'Rename',
              style: CoveType.rowTitle.copyWith(color: cv.accentText),
            ),
          ),
        ],
      ),
    );

    if (newName != null && newName != _currentCategory && mounted) {
      final old = _currentCategory;
      final count = await ref
          .read(expenseControllerProvider)
          .renameCategory(old, newName);

      setState(() {
        _currentCategory = newName;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Renamed "$old" to "$newName" ($count expense${count == 1 ? "" : "s"} updated)',
              style: CoveType.readout.copyWith(color: cv.textPrimary),
            ),
            backgroundColor: cv.surfaceCard,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyPreferenceProvider);
    final currentUser = ref.watch(authProvider).value;
    final partner = ref.watch(partnerProfileProvider);
    final partnerName =
        partner.displayName.isNotEmpty ? partner.displayName : 'Partner';

    final matchingExpenses = widget.allExpenses.where((e) {
      final cleanCat = cleanExpenseCategoryName(e.category);
      return cleanCat.toLowerCase() == _currentCategory.toLowerCase();
    }).toList();

    final categorySpend =
        matchingExpenses.fold<double>(0.0, (acc, e) => acc + e.amount);
    final shareRatio = widget.totalMonthSpend > 0
        ? (categorySpend / widget.totalMonthSpend).clamp(0.0, 1.0)
        : 0.0;
    final percent = (shareRatio * 100).round();

    final formattedSpend = formatCoveCurrency(categorySpend, currency.symbol);
    final categoryIcon = _getCategoryIcon(_currentCategory);
    final purchaseCount = matchingExpenses.length;
    final purchaseWord =
        purchaseCount == 1 ? '1 purchase' : '$purchaseCount purchases';

    final dialItems = matchingExpenses.map((expense) {
      final share = computeExpenseShare(
        expense,
        currentUserId: currentUser?.id,
      );
      final paidText =
          share.isPaidByViewer ? 'Paid by You' : 'Paid by $partnerName';
      final dateFormatted = DateFormat('MMM d').format(expense.expenseDate);
      return CoveReceiptItem(
        title: expense.title,
        subtitle: '$paidText · $dateFormatted',
        amount: formatCoveCurrency(expense.amount, currency.symbol),
        payer: share.isPaidByViewer ? CovePerson.a : CovePerson.b,
        onTap: () => ExpenseDetailSheet.show(context, expense),
      );
    }).toList();

    return CoveDetailSheet(
      kindGlyph: Icon(categoryIcon),
      kindLabel: 'CATEGORY',
      contextLabel: _currentCategory,
      onClose: () => Navigator.of(context).pop(),
      slip: CoveDial(
        variant: CoveSlipVariant.paper,
        title: _currentCategory,
        category: CoveDial.inferCategory(_currentCategory),
        amount: formattedSpend,
        share: shareRatio,
        items: dialItems,
        purchaseCount: purchaseCount,
      ),
      meaningPanel: CoveDetailMeaningPanel.icon(
        icon: categoryIcon,
        title: '$formattedSpend this month',
        subtitle: '$purchaseWord · $percent% of spending',
      ),
      editVerb: CoveDetailVerb(
        label: 'Edit',
        icon: Icons.edit_outlined,
        onPressed: () => _promptRename(context),
      ),
    );
  }
}
