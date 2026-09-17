import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import 'expense_controller.dart';
import 'expense_detail_sheet.dart';
import '../../core/utils/cove_currency_formatter.dart';

class CategoryDetailSheet extends ConsumerStatefulWidget {
  final String initialCategoryName;
  final List<LocalExpense> allExpenses;
  final double totalMonthSpend;

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
    return showModalBottomSheet(
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
    if (lower.contains('din') || lower.contains('restaur') || lower.contains('cafe')) {
      return Icons.restaurant_outlined;
    }
    if (lower.contains('travel') || lower.contains('transport') || lower.contains('flight')) {
      return Icons.flight_takeoff_outlined;
    }
    if (lower.contains('health') || lower.contains('med') || lower.contains('doctor')) {
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
    final colors = context.colors;
    final typography = context.typography;
    final controller = TextEditingController(text: _currentCategory);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename Category', style: typography.headline.copyWith(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This updates all expenses filed under this category.',
              style: typography.caption.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: 14),
            CovePillInput(
              controller: controller,
              hintText: 'Category name',
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                Navigator.of(ctx).pop(trimmed);
              }
            },
            child: Text('Rename', style: TextStyle(color: colors.accentPrimary, fontWeight: FontWeight.w600)),
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
            content: Text('Renamed "$old" to "$newName" ($count expense${count == 1 ? "" : "s"} updated)'),
            backgroundColor: colors.surfaceCard,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final currency = ref.watch(currencyPreferenceProvider);
    final currentUser = ref.watch(authProvider).value;
    final partner = ref.watch(partnerProfileProvider);
    final outbox = ref.watch(activeHomeOutboxProvider).value ?? [];
    final hasPartner = ref.watch(activeHomeHasPartnerProvider);

    // Filter expenses matching current category
    final matchingExpenses = widget.allExpenses.where((e) {
      final rawCat = e.category ?? 'Uncategorized';
      final cleanCat = rawCat.contains(' • ') ? rawCat.split(' • ').first : rawCat;
      return cleanCat.toLowerCase() == _currentCategory.toLowerCase();
    }).toList();

    // Sum spend
    final categorySpend = matchingExpenses.fold<double>(0.0, (acc, e) => acc + e.amount);
    final percent = widget.totalMonthSpend > 0
        ? ((categorySpend / widget.totalMonthSpend) * 100).toStringAsFixed(0)
        : '0';

    final categoryIcon = _getCategoryIcon(_currentCategory);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: colors.borderHairline)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row: Category title & Rename button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accentPrimary.withValues(alpha: 0.12),
                    ),
                    child: Icon(categoryIcon, size: 22, color: colors.accentPrimary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentCategory,
                          style: typography.headline.copyWith(fontSize: 22),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Category Details & Ledger',
                          style: typography.caption.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.borderHairline),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: Icon(Icons.edit_outlined, size: 14, color: colors.textPrimary),
                    label: Text(
                      'Rename',
                      style: typography.caption.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => _promptRename(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Summary Stats Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CoveCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('TOTAL SPENT', style: typography.caption),
                        const SizedBox(height: 6),
                        Text(
                          '${currency.symbol}${formatCoveAmount(categorySpend)}',
                          style: typography.largeNumber.copyWith(
                            fontSize: 26,
                            color: colors.accentTint,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: colors.borderHairline,
                    ),
                    Column(
                      children: [
                        Text('MONTHLY SHARE', style: typography.caption),
                        const SizedBox(height: 6),
                        Text(
                          '$percent%',
                          style: typography.largeNumber.copyWith(
                            fontSize: 26,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: colors.borderHairline,
                    ),
                    Column(
                      children: [
                        Text('ENTRIES', style: typography.caption),
                        const SizedBox(height: 6),
                        Text(
                          '${matchingExpenses.length}',
                          style: typography.largeNumber.copyWith(
                            fontSize: 26,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Purchases List Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('TRANSACTIONS IN THIS CATEGORY', style: typography.caption),
            ),
            const SizedBox(height: 8),

            // Purchases Ledger
            Expanded(
              child: matchingExpenses.isEmpty
                  ? Center(
                      child: Text(
                        'No transactions recorded under this category.',
                        style: typography.bodyMedium.copyWith(color: colors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      itemCount: matchingExpenses.length,
                      itemBuilder: (ctx, idx) {
                        final expense = matchingExpenses[idx];
                        final isMe = (expense.paidBy == currentUser?.id) ||
                            (currentUser?.id == null && expense.paidBy == 'user_alex') ||
                            (expense.paidBy == 'me');
                        final paidText = isMe
                            ? 'Paid by You'
                            : 'Paid by ${partner.displayName.isNotEmpty ? partner.displayName : "Partner"}';
                        final dateFormatted =
                            DateFormat('MMM d').format(expense.expenseDate);

                        final syncStatus = resolveCoveSyncStatus(
                          entityId: expense.id,
                          outbox: outbox,
                          hasPartner: hasPartner,
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              ExpenseDetailSheet.show(context, expense);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: colors.surfaceRow,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: colors.borderHairline),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          expense.title,
                                          style: typography.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '$paidText · $dateFormatted',
                                          style: typography.caption.copyWith(
                                            color: colors.textSubtle,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${currency.symbol}${formatCoveAmount(expense.amount)}',
                                    style: TextStyle(
                                      fontFamily: 'GeneralSans',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CoveSyncTick(status: syncStatus, size: 13),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
