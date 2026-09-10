import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../auth/auth_controller.dart';
import 'expense_controller.dart';

class ExpenseFormSheet extends ConsumerStatefulWidget {
  const ExpenseFormSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExpenseFormSheet(),
    );
  }

  @override
  ConsumerState<ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<ExpenseFormSheet> {
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _customCategoryController = TextEditingController();

  DateTime _expenseDate = DateTime.now();
  final String _currency = 'USD';
  String _selectedCategory = 'Groceries';
  bool _isCustomCategory = false;
  String _paidBy = 'user_alex'; // user id
  ExpenseVisibility _visibility = ExpenseVisibility.shared;

  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _fixedCategories = [
    'Groceries',
    'Home & Utilities',
    'Dining Out',
    'Travel & Transport',
    'Health & Personal',
    'Entertainment',
    'Shopping',
  ];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).value;
    if (user != null) {
      _paidBy = user.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: context.colors.accentPrimary,
              onPrimary: const Color(0xFF0B1F1E),
              surface: context.colors.surfaceCard,
              onSurface: context.colors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _expenseDate = picked);
    }
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please enter an item or merchant title.');
      return;
    }

    final amountText = _amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid amount.');
      return;
    }

    final category = _isCustomCategory
        ? _customCategoryController.text.trim()
        : _selectedCategory;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final controller = ref.read(expenseControllerProvider);
      final id = await controller.logExpense(
        title: title,
        amount: amount,
        currency: _currency,
        expenseDate: _expenseDate,
        paidBy: _paidBy,
        category: category.isNotEmpty ? category : 'General',
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        visibility: _visibility,
      );

      if (mounted) {
        Navigator.of(context).pop(id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final mediaQuery = MediaQuery.of(context);
    final currentUser = ref.watch(authProvider).value;
    final myId = currentUser?.id ?? 'user_alex';
    final myName = currentUser?.displayName ?? 'You';

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: colors.borderHairline, width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: mediaQuery.viewInsets.bottom + 24,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Log Expense',
                    style: typography.title.copyWith(fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title / Merchant
              Text('MERCHANT / DESCRIPTION', style: typography.caption),
              const SizedBox(height: 8),
              CovePillInput(
                controller: _titleController,
                hintText: 'e.g. Farmers Market, Target, Utilities',
                prefixIcon: Icon(Icons.receipt_long_outlined,
                    size: 18, color: colors.textMuted),
              ),
              const SizedBox(height: 18),

              // Amount & Currency Row
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AMOUNT', style: typography.caption),
                        const SizedBox(height: 8),
                        CovePillInput(
                          controller: _amountController,
                          hintText: '0.00',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              '\$',
                              style: TextStyle(
                                fontFamily: 'GeneralSans',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DATE', style: typography.caption),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: colors.surfaceRow,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: colors.borderHairline, width: 1),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 16, color: colors.textMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    DateFormat('MMM d').format(_expenseDate),
                                    style: typography.bodyRegular.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down,
                                    size: 18, color: colors.accentPrimary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Paid By Selector
              Text('PAID BY', style: typography.caption),
              const SizedBox(height: 8),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: colors.surfaceRow,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.borderHairline, width: 1),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSelectorPill(
                        label: myName,
                        isSelected: _paidBy == myId,
                        onTap: () => setState(() => _paidBy = myId),
                      ),
                    ),
                    Expanded(
                      child: _buildSelectorPill(
                        label: 'Partner',
                        isSelected: _paidBy != myId,
                        onTap: () => setState(() => _paidBy = 'partner_user'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Category Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('CATEGORY', style: typography.caption),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isCustomCategory = !_isCustomCategory;
                      });
                    },
                    child: Text(
                      _isCustomCategory ? 'Use standard list' : '+ Custom category',
                      style: typography.caption.copyWith(
                        color: colors.accentPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isCustomCategory)
                CovePillInput(
                  controller: _customCategoryController,
                  hintText: 'e.g. Pet Care, Gardening, Home Renovation',
                  prefixIcon: Icon(Icons.label_outline,
                      size: 18, color: colors.textMuted),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _fixedCategories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() => _selectedCategory = cat),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.accentPrimary.withValues(alpha: 0.18)
                                  : colors.surfaceRow,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isSelected
                                    ? colors.accentPrimary
                                    : colors.borderHairline,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontFamily: 'GeneralSans',
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? colors.accentPrimary
                                    : colors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 18),

              // Optional Note
              Text('OPTIONAL NOTE', style: typography.caption),
              const SizedBox(height: 8),
              CovePillInput(
                controller: _notesController,
                hintText: 'e.g. Split for dinner, bought on road trip',
                prefixIcon: Icon(Icons.notes_outlined,
                    size: 18, color: colors.textMuted),
              ),
              const SizedBox(height: 22),

              // Three-Tier Visibility & Privacy
              Text('VISIBILITY & PRIVACY', style: typography.caption),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: colors.surfaceRow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.borderHairline, width: 1),
                ),
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildVisibilityPill(
                            icon: Icons.people_outline,
                            label: 'Shared',
                            isSelected:
                                _visibility == ExpenseVisibility.shared,
                            onTap: () => setState(() =>
                                _visibility = ExpenseVisibility.shared),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildVisibilityPill(
                            icon: Icons.visibility_outlined,
                            label: 'Partner sees',
                            isSelected: _visibility ==
                                ExpenseVisibility.partnerCanSee,
                            onTap: () => setState(() => _visibility =
                                ExpenseVisibility.partnerCanSee),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildVisibilityPill(
                            icon: Icons.visibility_off_outlined,
                            label: 'Private',
                            isSelected:
                                _visibility == ExpenseVisibility.privateToMe,
                            onTap: () => setState(() =>
                                _visibility = ExpenseVisibility.privateToMe),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      child: Text(
                        _getVisibilityExplainer(),
                        style: typography.caption.copyWith(
                          fontSize: 11,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 13,
                    color: colors.accentSecondary,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Submit Button
              CovePillButton(
                label: 'Log Expense',
                isLoading: _isSaving,
                onPressed: _handleSave,
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getVisibilityExplainer() {
    switch (_visibility) {
      case ExpenseVisibility.shared:
        return 'Included in joint household monthly totals and 50/50 balance. End-to-end encrypted and synced.';
      case ExpenseVisibility.partnerCanSee:
        return 'Visible to your partner in the ledger for transparency, but kept outside the joint split pool.';
      case ExpenseVisibility.privateToMe:
        return 'Private expenses stay strictly on this device only. 0 bytes are sent to cloud or partner.';
    }
  }

  Widget _buildSelectorPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.accentPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? (context.isDark ? const Color(0xFF0B1F1E) : Colors.white)
                : colors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityPill({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.surfaceCard : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: colors.accentPrimary.withValues(alpha: 0.5), width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? colors.accentPrimary : colors.textMuted,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'GeneralSans',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? colors.accentPrimary : colors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
