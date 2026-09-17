import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../../sync/db/app_database.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../profile/user_profile_controller.dart';
import 'expense_controller.dart';

class ExpenseFormSheet extends ConsumerStatefulWidget {
  final LocalExpense? initialExpense;

  const ExpenseFormSheet({super.key, this.initialExpense});

  static Future<String?> show(BuildContext context, {LocalExpense? initialExpense}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExpenseFormSheet(initialExpense: initialExpense),
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
  late String _currency;
  String _selectedCategory = 'Groceries';
  bool _isCustomCategory = false;
  String _paidBy = 'user_alex'; // user id
  ExpenseVisibility _visibility = ExpenseVisibility.shared;
  String? _paymentMethod; // 'card' | 'upi' | 'cash'
  bool _isTransfer = false;

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
    if (widget.initialExpense != null) {
      final exp = widget.initialExpense!;
      _titleController.text = exp.title;
      _amountController.text =
          exp.amount % 1 == 0 ? exp.amount.toInt().toString() : exp.amount.toStringAsFixed(2);
      _expenseDate = exp.expenseDate;
      _currency = exp.currency;
      _paidBy = exp.paidBy;
      _visibility = ExpenseVisibilityExtension.fromSplitRatio(exp.splitRatio);
      _paymentMethod = exp.paymentMethod;
      _isTransfer = exp.isTransfer;

      String cat = exp.category ?? (_isTransfer ? 'Transfer' : 'Groceries');
      if (cat.contains(' • ')) {
        final parts = cat.split(' • ');
        cat = parts.first;
        _notesController.text = parts.sublist(1).join(' • ');
      }
      _selectedCategory = cat;
      _isCustomCategory = false;
    } else {
      _currency = ref.read(currencyPreferenceProvider).code;
      final user = ref.read(authProvider).value;
      if (user != null) {
        _paidBy = user.id;
      }
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

    final category = _isTransfer
        ? 'Transfer'
        : (_isCustomCategory
            ? _customCategoryController.text.trim()
            : _selectedCategory);

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final controller = ref.read(expenseControllerProvider);
      final finalCategory = category.isNotEmpty ? category : 'General';

      if (!_isTransfer && category.isNotEmpty && !_fixedCategories.contains(category)) {
        await ref.read(customCategoriesProvider.notifier).addCategory(category);
      }

      final String id;
      if (widget.initialExpense != null) {
        final oldVis =
            ExpenseVisibilityExtension.fromSplitRatio(widget.initialExpense!.splitRatio);
        id = await controller.updateExpense(
          id: widget.initialExpense!.id,
          title: title,
          amount: amount,
          currency: _currency,
          expenseDate: _expenseDate,
          paidBy: _paidBy,
          category: finalCategory,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          paymentMethod: _paymentMethod,
          isTransfer: _isTransfer,
          oldVisibility: oldVis,
          visibility: _isTransfer ? ExpenseVisibility.shared : _visibility,
        );
      } else {
        id = await controller.logExpense(
          title: title,
          amount: amount,
          currency: _currency,
          expenseDate: _expenseDate,
          paidBy: _paidBy,
          category: finalCategory,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          paymentMethod: _paymentMethod,
          isTransfer: _isTransfer,
          visibility: _isTransfer ? ExpenseVisibility.shared : _visibility,
        );
      }

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
    final currency = ref.watch(currencyPreferenceProvider);
    final currentUser = ref.watch(authProvider).value;
    final userProfile = ref.watch(userProfileProvider);
    final partnerProfile = ref.watch(partnerProfileProvider);
    final myId = currentUser?.id ?? 'user_alex';
    final myName = userProfile.displayName;
    final partnerName = partnerProfile.displayName;

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
                    widget.initialExpense != null
                        ? (_isTransfer ? 'Edit Transfer' : 'Edit Expense')
                        : (_isTransfer ? 'Record Transfer' : 'Log Expense'),
                    style: typography.title.copyWith(fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Entry Type Segment Switcher (Expense vs Transfer)
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: colors.surfaceRow,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.borderHairline, width: 1),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSegmentPill(
                        icon: Icons.receipt_long_outlined,
                        label: 'Expense',
                        isSelected: !_isTransfer,
                        onTap: () => setState(() => _isTransfer = false),
                      ),
                    ),
                    Expanded(
                      child: _buildSegmentPill(
                        icon: Icons.swap_horiz,
                        label: 'Transfer',
                        isSelected: _isTransfer,
                        onTap: () {
                          setState(() {
                            _isTransfer = true;
                            if (_titleController.text.trim().isEmpty) {
                              _titleController.text = 'Transfer';
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Title / Merchant
              Text(
                _isTransfer ? 'TRANSFER REASON / TITLE' : 'MERCHANT / DESCRIPTION',
                style: typography.caption,
              ),
              const SizedBox(height: 8),
              CovePillInput(
                controller: _titleController,
                hintText: _isTransfer
                    ? 'e.g. Rent share, Dinner reimbursement, Monthly settle'
                    : 'e.g. Farmers Market, Target, Utilities',
                prefixIcon: Icon(
                  _isTransfer ? Icons.swap_horiz : Icons.receipt_long_outlined,
                  size: 18,
                  color: colors.textMuted,
                ),
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
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              currency.symbol,
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
              Text(
                _isTransfer ? 'TRANSFERRED BY (SENDER)' : 'PAID BY',
                style: typography.caption,
              ),
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
                        isSelected: _paidBy == myId ||
                            (_paidBy != (partnerProfile.userId ?? 'partner_user') &&
                                _paidBy != 'partner_user'),
                        onTap: () => setState(() => _paidBy = myId),
                      ),
                    ),
                    Expanded(
                      child: _buildSelectorPill(
                        label: partnerName,
                        isSelected: _paidBy == (partnerProfile.userId ?? 'partner_user') ||
                            _paidBy == 'partner_user',
                        onTap: () => setState(() =>
                            _paidBy = partnerProfile.userId ?? 'partner_user'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Payment Method Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isTransfer ? 'HOW WAS THIS SENT?' : 'HOW WAS THIS PAID?',
                    style: typography.caption,
                  ),
                  if (_paymentMethod != null)
                    GestureDetector(
                      onTap: () => setState(() => _paymentMethod = null),
                      child: Text(
                        'Clear',
                        style: typography.caption.copyWith(
                          color: colors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: colors.surfaceRow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.borderHairline, width: 1),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildPaymentMethodPill(
                        icon: Icons.credit_card_outlined,
                        label: 'Card',
                        isSelected: _paymentMethod == 'card',
                        onTap: () => setState(() =>
                            _paymentMethod = _paymentMethod == 'card' ? null : 'card'),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildPaymentMethodPill(
                        icon: Icons.qr_code_2_rounded,
                        label: 'UPI',
                        isSelected: _paymentMethod == 'upi',
                        onTap: () => setState(() =>
                            _paymentMethod = _paymentMethod == 'upi' ? null : 'upi'),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildPaymentMethodPill(
                        icon: Icons.payments_outlined,
                        label: 'Cash',
                        isSelected: _paymentMethod == 'cash',
                        onTap: () => setState(() =>
                            _paymentMethod = _paymentMethod == 'cash' ? null : 'cash'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (_isTransfer) ...[
                // Transfer Notice Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceRow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.borderHairline, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, size: 20, color: colors.accentPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Transfers between you and $partnerName are tracked in the ledger and transfers total, but are separate from household expenditures.',
                          style: typography.caption.copyWith(
                            fontSize: 12,
                            height: 1.4,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Optional Note for Transfer
                Text('OPTIONAL NOTE', style: typography.caption),
                const SizedBox(height: 8),
                CovePillInput(
                  controller: _notesController,
                  hintText: 'e.g. Split for dinner, monthly settlement',
                  prefixIcon: Icon(Icons.notes_outlined,
                      size: 18, color: colors.textMuted),
                ),
              ] else ...[
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
                  Builder(
                    builder: (context) {
                      final savedCustomCats = ref.watch(customCategoriesProvider);
                      final allCategoryPills = [
                        ..._fixedCategories,
                        ...savedCustomCats.where((c) => !_fixedCategories.contains(c)),
                      ];
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: allCategoryPills.map((cat) {
                            final isSelected = !_isCustomCategory && _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () => setState(() {
                                  _selectedCategory = cat;
                                  _isCustomCategory = false;
                                }),
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
                      );
                    },
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
                              label: '$partnerName sees',
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
                          _getVisibilityExplainer(partnerName),
                          style: typography.caption.copyWith(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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
                label: widget.initialExpense != null
                    ? (_isTransfer ? 'Update Transfer' : 'Update Expense')
                    : (_isTransfer ? 'Record Transfer' : 'Log Expense'),
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

  String _getVisibilityExplainer(String partnerName) {
    switch (_visibility) {
      case ExpenseVisibility.shared:
        return 'Included in joint household monthly totals and 50/50 balance. End-to-end encrypted and synced.';
      case ExpenseVisibility.partnerCanSee:
        return 'Visible to $partnerName in the ledger for transparency, but kept outside the joint split pool.';
      case ExpenseVisibility.privateToMe:
        return 'Private expenses stay strictly on this device only. 0 bytes are sent to cloud or $partnerName.';
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

  Widget _buildPaymentMethodPill({
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
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'GeneralSans',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? colors.accentPrimary : colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentPill({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.accentPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? (context.isDark ? const Color(0xFF0B1F1E) : Colors.white)
                  : colors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'GeneralSans',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? (context.isDark ? const Color(0xFF0B1F1E) : Colors.white)
                    : colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
