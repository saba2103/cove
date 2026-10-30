import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
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
  final DateTime? initialDate;
  final bool initialIsTransfer;

  const ExpenseFormSheet({
    super.key,
    this.initialExpense,
    this.initialDate,
    this.initialIsTransfer = false,
  });

  static Future<String?> show(
    BuildContext context, {
    LocalExpense? initialExpense,
    DateTime? initialDate,
    bool initialIsTransfer = false,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExpenseFormSheet(
        initialExpense: initialExpense,
        initialDate: initialDate,
        initialIsTransfer: initialIsTransfer,
      ),
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

  DateTime _expenseDate = clock.now();
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
      if (widget.initialDate != null) {
        _expenseDate = widget.initialDate!;
      }
      if (widget.initialIsTransfer) {
        _isTransfer = true;
        _selectedCategory = 'Transfer';
      }
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
    final cv = context.cv;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: (isDark
                    ? const ColorScheme.dark()
                    : const ColorScheme.light())
                .copyWith(
              primary: cv.accentFill,
              onPrimary: cv.textOnAccent,
              surface: cv.surfaceCard,
              onSurface: cv.textPrimary,
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
    final cv = context.cv;
    final mediaQuery = MediaQuery.of(context);
    final currency = ref.watch(currencyPreferenceProvider);
    final currentUser = ref.watch(authProvider).value;
    final userProfile = ref.watch(userProfileProvider);
    final partnerProfile = ref.watch(partnerProfileProvider);
    final myId = currentUser?.id ?? 'user_alex';
    final myName = userProfile.displayName;
    final partnerName = partnerProfile.displayName;
    final isScaled = MediaQuery.textScalerOf(context).scale(1.0) > 1.0;

    final segmentChildren = [
      _buildSegmentPill(
        icon: Icons.receipt_long_outlined,
        label: 'Expense',
        isSelected: !_isTransfer,
        onTap: () => setState(() => _isTransfer = false),
      ),
      _buildSegmentPill(
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
    ];

    final amountField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AMOUNT',
          style: CoveType.capsPage.copyWith(
            color: cv.textSecondary,
          ),
        ),
        const SizedBox(height: CoveSpace.sm),
        CovePillInput(
          controller: _amountController,
          hintText: '0.00',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: CoveSpace.xs),
            child: Text(
              currency.symbol,
              style: CoveType.rowTitle.copyWith(
                fontWeight: FontWeight.w600,
                color: cv.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );

    final dateField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DATE',
          style: CoveType.capsPage.copyWith(
            color: cv.textSecondary,
          ),
        ),
        const SizedBox(height: CoveSpace.sm),
        InkWell(
          onTap: _pickDate,
          customBorder: CoveShape.border(CoveRadius.pill),
          child: Container(
            height: isScaled ? null : CoveSize.hit,
            constraints: isScaled
                ? const BoxConstraints(minHeight: CoveSize.hit)
                : null,
            decoration: CoveShape.decoration(
              CoveRadius.pill,
              color: cv.surfaceRow,
              side: BorderSide(
                color: cv.lineHairline,
                width: 1,
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: isScaled ? CoveSpace.sm : 0,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: cv.textSecondary,
                ),
                const SizedBox(width: CoveSpace.sm),
                Expanded(
                  child: Text(
                    DateFormat('MMM d').format(_expenseDate),
                    style: CoveType.rowTitle.copyWith(
                      color: cv.textPrimary,
                    ),
                    overflow: isScaled ? null : TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: cv.accentText,
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final paidByChildren = [
      _buildSelectorPill(
        label: myName,
        isSelected: _paidBy == myId ||
            (_paidBy != (partnerProfile.userId ?? 'partner_user') &&
                _paidBy != 'partner_user'),
        onTap: () => setState(() => _paidBy = myId),
      ),
      _buildSelectorPill(
        label: partnerName,
        isSelected: _paidBy == (partnerProfile.userId ?? 'partner_user') ||
            _paidBy == 'partner_user',
        onTap: () =>
            setState(() => _paidBy = partnerProfile.userId ?? 'partner_user'),
      ),
    ];

    final paymentMethodChildren = [
      _buildPaymentMethodPill(
        icon: Icons.credit_card_outlined,
        label: 'Card',
        isSelected: _paymentMethod == 'card',
        onTap: () => setState(
          () => _paymentMethod = _paymentMethod == 'card' ? null : 'card',
        ),
      ),
      _buildPaymentMethodPill(
        icon: Icons.qr_code_2_rounded,
        label: 'UPI',
        isSelected: _paymentMethod == 'upi',
        onTap: () => setState(
          () => _paymentMethod = _paymentMethod == 'upi' ? null : 'upi',
        ),
      ),
      _buildPaymentMethodPill(
        icon: Icons.payments_outlined,
        label: 'Cash',
        isSelected: _paymentMethod == 'cash',
        onTap: () => setState(
          () => _paymentMethod = _paymentMethod == 'cash' ? null : 'cash',
        ),
      ),
    ];

    final visibilityChildren = [
      _buildVisibilityPill(
        icon: Icons.people_outline,
        label: 'Shared',
        isSelected: _visibility == ExpenseVisibility.shared,
        onTap: () => setState(() => _visibility = ExpenseVisibility.shared),
      ),
      _buildVisibilityPill(
        icon: Icons.visibility_outlined,
        label: '$partnerName sees',
        isSelected: _visibility == ExpenseVisibility.partnerCanSee,
        onTap: () =>
            setState(() => _visibility = ExpenseVisibility.partnerCanSee),
      ),
      _buildVisibilityPill(
        icon: Icons.visibility_off_outlined,
        label: 'Private',
        isSelected: _visibility == ExpenseVisibility.privateToMe,
        onTap: () =>
            setState(() => _visibility = ExpenseVisibility.privateToMe),
      ),
    ];

    return Container(
      decoration: CoveShape.topDecoration(
        CoveRadius.sheet,
        color: cv.surfaceSheet,
        side: BorderSide(color: cv.lineHairline, width: 1),
      ),
      padding: EdgeInsets.only(
        left: CoveSpace.gutter,
        right: CoveSpace.gutter,
        top: CoveSpace.gutter,
        bottom: mediaQuery.viewInsets.bottom + CoveSpace.lg,
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
                  Expanded(
                    child: Text(
                      widget.initialExpense != null
                          ? (_isTransfer ? 'Edit Transfer' : 'Edit Expense')
                          : (_isTransfer ? 'Record Transfer' : 'Log Expense'),
                      style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: cv.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Entry Type Segment Switcher (Expense vs Transfer)
              Container(
                height: isScaled ? null : 44,
                decoration: CoveShape.decoration(
                  isScaled ? CoveRadius.inline : CoveRadius.pill,
                  color: cv.surfaceRow,
                  side: BorderSide(color: cv.lineHairline, width: 1),
                ),
                padding: EdgeInsets.all(isScaled ? CoveSpace.xs : 3),
                child: isScaled
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          segmentChildren[0],
                          const SizedBox(height: CoveSpace.xs),
                          segmentChildren[1],
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: segmentChildren[0]),
                          Expanded(child: segmentChildren[1]),
                        ],
                      ),
              ),
              const SizedBox(height: 18),

              // Title / Merchant
              Text(
                _isTransfer ? 'TRANSFER REASON / TITLE' : 'MERCHANT / DESCRIPTION',
                style: CoveType.capsPage.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.sm),
              CovePillInput(
                controller: _titleController,
                hintText: _isTransfer
                    ? 'e.g. Rent share, Dinner reimbursement, Monthly settle'
                    : 'e.g. Farmers Market, Target, Utilities',
                prefixIcon: Icon(
                  _isTransfer ? Icons.swap_horiz : Icons.receipt_long_outlined,
                  size: 18,
                  color: cv.textSecondary,
                ),
              ),
              const SizedBox(height: 18),

              // Amount & Currency Row
              if (isScaled) ...[
                amountField,
                const SizedBox(height: 14),
                dateField,
              ] else
                Row(
                  children: [
                    Expanded(flex: 6, child: amountField),
                    const SizedBox(width: 14),
                    Expanded(flex: 5, child: dateField),
                  ],
                ),
              const SizedBox(height: 18),

              // Paid By Selector
              Text(
                _isTransfer ? 'TRANSFERRED BY (SENDER)' : 'PAID BY',
                style: CoveType.capsPage.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.sm),
              Container(
                height: isScaled ? null : CoveSize.hit,
                decoration: CoveShape.decoration(
                  isScaled ? CoveRadius.inline : CoveRadius.pill,
                  color: cv.surfaceRow,
                  side: BorderSide(color: cv.lineHairline, width: 1),
                ),
                padding: EdgeInsets.all(isScaled ? CoveSpace.xs : 3),
                child: isScaled
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          paidByChildren[0],
                          const SizedBox(height: CoveSpace.xs),
                          paidByChildren[1],
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: paidByChildren[0]),
                          Expanded(child: paidByChildren[1]),
                        ],
                      ),
              ),
              const SizedBox(height: 18),

              // Payment Method Selector
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: CoveSpace.section,
                  runSpacing: CoveSpace.xs,
                  children: [
                    Text(
                      _isTransfer ? 'HOW WAS THIS SENT?' : 'HOW WAS THIS PAID?',
                      style: CoveType.capsPage.copyWith(color: cv.textSecondary),
                    ),
                    if (_paymentMethod != null)
                      GestureDetector(
                        onTap: () => setState(() => _paymentMethod = null),
                        child: Text(
                          'Clear',
                          style: CoveType.barLabel.copyWith(
                            color: cv.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: CoveSpace.sm),
              Container(
                decoration: CoveShape.decoration(
                  CoveRadius.inline,
                  color: cv.surfaceRow,
                  side: BorderSide(color: cv.lineHairline, width: 1),
                ),
                padding: const EdgeInsets.all(CoveSpace.xs),
                child: isScaled
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          paymentMethodChildren[0],
                          const SizedBox(height: CoveSpace.xs),
                          paymentMethodChildren[1],
                          const SizedBox(height: CoveSpace.xs),
                          paymentMethodChildren[2],
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: paymentMethodChildren[0]),
                          const SizedBox(width: CoveSpace.xs),
                          Expanded(child: paymentMethodChildren[1]),
                          const SizedBox(width: CoveSpace.xs),
                          Expanded(child: paymentMethodChildren[2]),
                        ],
                      ),
              ),
              const SizedBox(height: 18),

              if (_isTransfer) ...[
                // Transfer Notice Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: CoveShape.decoration(
                    CoveRadius.inline,
                    color: cv.surfaceRow,
                    side: BorderSide(color: cv.lineHairline, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, size: 20, color: cv.accentText),
                      const SizedBox(width: CoveSpace.md),
                      Expanded(
                        child: Text(
                          'Transfers between you and $partnerName are tracked in the ledger and transfers total, but are separate from household expenditures.',
                          style: CoveType.rowSub.copyWith(
                            color: cv.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Optional Note for Transfer
                Text(
                  'OPTIONAL NOTE',
                  style: CoveType.capsPage.copyWith(color: cv.textSecondary),
                ),
                const SizedBox(height: CoveSpace.sm),
                CovePillInput(
                  controller: _notesController,
                  hintText: 'e.g. Split for dinner, monthly settlement',
                  prefixIcon: Icon(
                    Icons.notes_outlined,
                    size: 18,
                    color: cv.textSecondary,
                  ),
                ),
              ] else ...[
                // Category Selector
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: CoveSpace.section,
                    runSpacing: CoveSpace.xs,
                    children: [
                      Text(
                        'CATEGORY',
                        style: CoveType.capsPage.copyWith(
                          color: cv.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isCustomCategory = !_isCustomCategory;
                          });
                        },
                        child: Text(
                          _isCustomCategory
                              ? 'Use standard list'
                              : '+ Custom category',
                          style: CoveType.rowSub.copyWith(
                            color: cv.accentText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CoveSpace.sm),
                if (_isCustomCategory)
                  CovePillInput(
                    controller: _customCategoryController,
                    hintText: 'e.g. Pet Care, Gardening, Home Renovation',
                    prefixIcon: Icon(
                      Icons.label_outline,
                      size: 18,
                      color: cv.textSecondary,
                    ),
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
                              padding: const EdgeInsets.only(right: CoveSpace.sm),
                              child: InkWell(
                                onTap: () => setState(() {
                                  _selectedCategory = cat;
                                  _isCustomCategory = false;
                                }),
                                customBorder: CoveShape.border(CoveRadius.pill),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: CoveSpace.sm,
                                  ),
                                  decoration: CoveShape.decoration(
                                    CoveRadius.pill,
                                    color: isSelected
                                        ? cv.accentWash
                                        : cv.surfaceRow,
                                    side: BorderSide(
                                      color: isSelected
                                          ? cv.accentFill
                                          : cv.lineHairline,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    cat,
                                    style: CoveType.readout.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? cv.accentText
                                          : cv.textSecondary,
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
                Text(
                  'OPTIONAL NOTE',
                  style: CoveType.capsPage.copyWith(color: cv.textSecondary),
                ),
                const SizedBox(height: CoveSpace.sm),
                CovePillInput(
                  controller: _notesController,
                  hintText: 'e.g. Split for dinner, bought on road trip',
                  prefixIcon: Icon(
                    Icons.notes_outlined,
                    size: 18,
                    color: cv.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),

                // Three-Tier Visibility & Privacy
                Text(
                  'VISIBILITY & PRIVACY',
                  style: CoveType.capsPage.copyWith(color: cv.textSecondary),
                ),
                const SizedBox(height: CoveSpace.sm),
                Container(
                  decoration: CoveShape.decoration(
                    CoveRadius.inline,
                    color: cv.surfaceRow,
                    side: BorderSide(color: cv.lineHairline, width: 1),
                  ),
                  padding: const EdgeInsets.all(CoveSpace.xs),
                  child: Column(
                    children: [
                      if (isScaled)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            visibilityChildren[0],
                            const SizedBox(height: CoveSpace.xs),
                            visibilityChildren[1],
                            const SizedBox(height: CoveSpace.xs),
                            visibilityChildren[2],
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(child: visibilityChildren[0]),
                            const SizedBox(width: CoveSpace.xs),
                            Expanded(child: visibilityChildren[1]),
                            const SizedBox(width: CoveSpace.xs),
                            Expanded(child: visibilityChildren[2]),
                          ],
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          10,
                          10,
                          10,
                          CoveSpace.sm,
                        ),
                        child: Text(
                          _getVisibilityExplainer(partnerName),
                          style: CoveType.barLabel.copyWith(
                            color: cv.textSecondary,
                            fontWeight: FontWeight.w400,
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
                  style: CoveType.readout.copyWith(
                    color: cv.statusAlertText,
                  ),
                ),
              ],

              const SizedBox(height: CoveSpace.lg),

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
    final cv = context.cv;
    final isScaled = MediaQuery.textScalerOf(context).scale(1.0) > 1.0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: CoveMotion.q(context),
        padding: isScaled
            ? const EdgeInsets.symmetric(
                vertical: CoveSpace.sm,
                horizontal: CoveSpace.md,
              )
            : null,
        alignment: Alignment.center,
        decoration: CoveShape.decoration(
          CoveRadius.pill,
          color: isSelected ? cv.accentFill : Colors.transparent,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: CoveType.readout.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? cv.textOnAccent
                : cv.textSecondary,
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
    final cv = context.cv;
    final isScaled = MediaQuery.textScalerOf(context).scale(1.0) > 1.0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: CoveMotion.q(context),
        padding: EdgeInsets.symmetric(
          vertical: CoveSpace.sm,
          horizontal: isScaled ? CoveSpace.sm : 0,
        ),
        alignment: Alignment.center,
        decoration: CoveShape.decoration(
          CoveRadius.inline,
          color: isSelected ? cv.surfaceCard : Colors.transparent,
          side: isSelected
              ? BorderSide(
                  color: cv.accentFill.withValues(alpha: 0.5),
                  width: 1,
                )
              : BorderSide.none,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? cv.accentText : cv.textSecondary,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: CoveType.rowSub.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? cv.accentText : cv.textSecondary,
                ),
                overflow: isScaled ? null : TextOverflow.ellipsis,
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
    final cv = context.cv;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: CoveMotion.q(context),
        padding: const EdgeInsets.symmetric(vertical: CoveSpace.sm),
        alignment: Alignment.center,
        decoration: CoveShape.decoration(
          CoveRadius.inline,
          color: isSelected ? cv.surfaceCard : Colors.transparent,
          side: isSelected
              ? BorderSide(
                  color: cv.accentFill.withValues(alpha: 0.5),
                  width: 1,
                )
              : BorderSide.none,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? cv.accentText : cv.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: CoveType.readout.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? cv.accentText : cv.textSecondary,
                ),
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
    final cv = context.cv;
    final isScaled = MediaQuery.textScalerOf(context).scale(1.0) > 1.0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: CoveMotion.q(context),
        padding: isScaled
            ? const EdgeInsets.symmetric(
                vertical: CoveSpace.sm,
                horizontal: CoveSpace.md,
              )
            : null,
        alignment: Alignment.center,
        decoration: CoveShape.decoration(
          CoveRadius.pill,
          color: isSelected ? cv.accentFill : Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? cv.textOnAccent
                  : cv.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: CoveType.readout.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? cv.textOnAccent
                      : cv.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
