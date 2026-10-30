import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'commitment_models.dart';
import 'subscription_controller.dart';

class SubscriptionFormSheet extends ConsumerStatefulWidget {
  final LocalSubscription? existing;
  final bool initialIsEmi;
  final DateTime? initialDate;

  const SubscriptionFormSheet({
    super.key,
    this.existing,
    this.initialIsEmi = false,
    this.initialDate,
  });

  static Future<void> show(
    BuildContext context, {
    LocalSubscription? existing,
    bool initialIsEmi = false,
    DateTime? initialDate,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubscriptionFormSheet(
        existing: existing,
        initialIsEmi: initialIsEmi,
        initialDate: initialDate,
      ),
    );
  }

  @override
  ConsumerState<SubscriptionFormSheet> createState() => _SubscriptionFormSheetState();
}

class _SubscriptionFormSheetState extends ConsumerState<SubscriptionFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _financedThroughController;
  late final TextEditingController _paidInstallmentsController;
  late String _currency;
  late String _billingCycle; // 'monthly' | 'annual' | 'custom'
  late int _customMonths;
  late DateTime _nextBillingDate;
  DateTime? _endDate;
  int? _totalInstallments;
  int? _paidInstallments;
  String? _category;
  late bool _isPrivate;
  late String _paidBy;
  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _categories = [
    'Streaming',
    'Utilities',
    'Software',
    'Home',
    'Health',
    'News',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    _nameController = TextEditingController(text: item?.name ?? '');
    _amountController = TextEditingController(
      text: item != null
          ? ((item.amount * 100).round() % 100 == 0
              ? item.amount.toInt().toString()
              : item.amount.toString())
          : '',
    );
    _currency = item?.currency ?? ref.read(currencyPreferenceProvider).code;

    if (item != null) {
      final cycle = item.billingCycle.toLowerCase();
      if (cycle == 'monthly' || cycle == 'month') {
        _billingCycle = 'monthly';
        _customMonths = 7;
      } else if (cycle == 'annual' || cycle == 'yearly' || cycle == 'year') {
        _billingCycle = 'annual';
        _customMonths = 7;
      } else {
        _billingCycle = 'custom';
        _customMonths = getBillingCycleMonths(item.billingCycle);
      }
    } else {
      _billingCycle = 'monthly';
      _customMonths = 7;
    }

    _nextBillingDate = item?.nextBillingDate ?? widget.initialDate ?? clock.now().add(const Duration(days: 30));
    _endDate = item?.endDate;
    _totalInstallments = item?.totalInstallments ?? (_endDate != null ? item?.emiProgress?.totalInstallments : null);
    _paidInstallments = item?.paidInstallments ?? (_endDate != null ? item?.emiProgress?.paidInstallments : null);

    if (item == null && widget.initialIsEmi) {
      _totalInstallments = 12;
      _paidInstallments = 0;
    } else if (_paidInstallments == null && _endDate != null) {
      _paidInstallments = _calculatePaidFromEndDate(endDate: _endDate, total: _totalInstallments);
    }

    _paidInstallmentsController = TextEditingController(
      text: _paidInstallments != null ? '$_paidInstallments' : '',
    );

    if (item == null && widget.initialIsEmi) {
      _recalculateEndDate();
    }

    _category = item?.category ?? 'Streaming';
    _isPrivate = item?.isPrivate ?? false;

    _financedThroughController = TextEditingController(text: item?.financedThrough ?? '');
    _financedThroughController.addListener(() {
      if (mounted) setState(() {});
    });

    final user = ref.read(authProvider).value;
    _paidBy = item?.paidBy ?? item?.createdBy ?? user?.id ?? 'me';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _financedThroughController.dispose();
    _paidInstallmentsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final cv = context.cv;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextBillingDate,
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
      setState(() => _nextBillingDate = picked);
    }
  }

  int _calculatePaidFromEndDate({DateTime? endDate, int? total, DateTime? now}) {
    final t = total ?? _totalInstallments ?? 12;
    if (endDate == null) return 0;
    final currentDate = now ?? clock.now();
    final cycleMonths = getBillingCycleMonths(_billingCycle);
    int remainingMonths = (endDate.year - currentDate.year) * 12 + (endDate.month - currentDate.month);
    if (endDate.day >= currentDate.day) {
      remainingMonths += 1;
    }
    if (remainingMonths < 0) remainingMonths = 0;
    final remainingCycles = (remainingMonths / cycleMonths).ceil();
    return (t - remainingCycles).clamp(0, t);
  }

  int get _effectivePaidInstallments {
    final text = _paidInstallmentsController.text.trim();
    if (text.isNotEmpty) {
      final parsed = int.tryParse(text);
      if (parsed != null) {
        return parsed.clamp(0, _totalInstallments ?? 12);
      }
    }
    if (_paidInstallments != null) return _paidInstallments!;
    return _calculatePaidFromEndDate(endDate: _endDate, total: _totalInstallments);
  }

  Future<void> _pickEndDate() async {
    final cv = context.cv;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = _endDate ?? _nextBillingDate.add(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(clock.now()) ? clock.now() : initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2045),
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
      setState(() {
        _endDate = picked;
        final total = _totalInstallments ?? 12;
        final autoPaid = _calculatePaidFromEndDate(endDate: picked, total: total);
        _paidInstallments = autoPaid;
        _paidInstallmentsController.text = '$autoPaid';
      });
    }
  }

  void _updateTenure(int total) {
    setState(() {
      _totalInstallments = total;
      final text = _paidInstallmentsController.text.trim();
      if (text.isNotEmpty) {
        final parsed = int.tryParse(text);
        if (parsed != null) {
          _paidInstallments = parsed.clamp(0, total);
          _paidInstallmentsController.text = '$_paidInstallments';
        }
      } else {
        if (_endDate != null) {
          _paidInstallments = _calculatePaidFromEndDate(endDate: _endDate, total: total);
        } else {
          _paidInstallments = 0;
        }
      }
      _recalculateEndDate();
    });
  }

  void _recalculateEndDate() {
    final total = _totalInstallments ?? 12;
    final paid = _effectivePaidInstallments.clamp(0, total);
    final remaining = (total - paid).clamp(0, total);
    final cycleMonths = getBillingCycleMonths(_billingCycle);
    final now = clock.now();
    _endDate = DateTime(
      now.year,
      now.month + (remaining * cycleMonths),
      _nextBillingDate.day,
    );
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter a commitment name.');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount < 0) {
      setState(() => _errorMessage = 'Please enter a valid amount.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final effectiveCycle = _billingCycle == 'custom'
        ? 'every_${_customMonths}_months'
        : _billingCycle;

    final isEmiSelected = _endDate != null || (_totalInstallments != null && _totalInstallments! > 0);
    final financedThroughText = _financedThroughController.text.trim();
    final effectiveFinancedThrough = financedThroughText.isNotEmpty
        ? financedThroughText
        : null;
    final effectivePaid = isEmiSelected ? _effectivePaidInstallments : null;

    try {
      final controller = ref.read(subscriptionControllerProvider);
      if (widget.existing != null) {
        await controller.updateSubscription(
          id: widget.existing!.id,
          name: name,
          amount: amount,
          currency: _currency,
          billingCycle: effectiveCycle,
          nextBillingDate: _nextBillingDate,
          category: _category,
          isPrivate: _isPrivate,
          endDate: _endDate,
          paidBy: _paidBy,
          financedThrough: effectiveFinancedThrough,
          totalInstallments: isEmiSelected ? _totalInstallments : null,
          paidInstallments: effectivePaid,
        );
      } else {
        await controller.createSubscription(
          name: name,
          amount: amount,
          currency: _currency,
          billingCycle: effectiveCycle,
          nextBillingDate: _nextBillingDate,
          category: _category,
          isPrivate: _isPrivate,
          endDate: _endDate,
          paidBy: _paidBy,
          financedThrough: effectiveFinancedThrough,
          totalInstallments: isEmiSelected ? _totalInstallments : null,
          paidInstallments: effectivePaid,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
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
    final currency = ref.watch(currencyPreferenceProvider);
    final partnerProfile = ref.watch(partnerProfileProvider);
    final partnerName = partnerProfile.displayName.trim().isNotEmpty
        ? partnerProfile.displayName.trim()
        : 'Partner';
    final userProfile = ref.watch(userProfileProvider);
    final user = ref.watch(authProvider).value;
    final myId = user?.id ?? 'me';
    final myName = userProfile.displayName.trim().isNotEmpty
        ? userProfile.displayName.trim()
        : 'You';
    final isEditing = widget.existing != null;
    final mediaQuery = MediaQuery.of(context);

    final defaultSources = const [
      'Credit Card',
      'Debit Card',
      'HDFC Bank',
      'ICICI Bank',
      'SBI Card',
      'Amex',
      'Axis Bank',
      'Apple Card',
      'Personal Loan',
      'Friend / Family',
    ];
    final dbSources = ref.watch(previousFinancingSourcesProvider).value ?? const [];
    final allSources = <String>{...dbSources, ...defaultSources}.toList();
    final currentFinancingInput = _financedThroughController.text.trim().toLowerCase();
    final financingSuggestions = allSources.where((s) {
      if (currentFinancingInput.isEmpty) return true;
      return s.toLowerCase().contains(currentFinancingInput) && s.toLowerCase() != currentFinancingInput;
    }).toList();

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
          child: Builder(
            builder: (context) {
              final isScaled =
                  MediaQuery.textScalerOf(context).scale(1.0) > 1.0;

              final commitmentTypeChildren = [
                _buildSelectorPill(
                  label: 'Subscription',
                  isSelected: _endDate == null &&
                      (_totalInstallments == null || _totalInstallments == 0),
                  onTap: () => setState(() {
                    _endDate = null;
                    _totalInstallments = null;
                    _paidInstallments = null;
                    _paidInstallmentsController.clear();
                  }),
                ),
                _buildSelectorPill(
                  label: 'EMI / Loan',
                  isSelected: _endDate != null ||
                      (_totalInstallments != null && _totalInstallments! > 0),
                  onTap: () => setState(() {
                    _totalInstallments ??= 12;
                    _paidInstallments ??= 0;
                    _paidInstallmentsController.text = '$_paidInstallments';
                    _recalculateEndDate();
                  }),
                ),
              ];

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isEditing ? 'Edit Commitment' : 'New Commitment',
                          style: CoveType.slipTitle.copyWith(
                            color: cv.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: cv.textSecondary,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Service Name
                  Text(
                    'COMMITMENT NAME',
                    style: CoveType.capsPage.copyWith(color: cv.textSecondary),
                  ),
                  const SizedBox(height: CoveSpace.sm),
                  CovePillInput(
                    controller: _nameController,
                    hintText: 'e.g. Netflix, Spotify, Car Loan, Device EMI',
                    prefixIcon: Icon(
                      Icons.autorenew_outlined,
                      size: 18,
                      color: cv.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Amount
                  Text(
                    'AMOUNT',
                    style: CoveType.capsPage.copyWith(color: cv.textSecondary),
                  ),
                  const SizedBox(height: CoveSpace.sm),
                  CovePillInput(
                    controller: _amountController,
                    hintText: '0.00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                  const SizedBox(height: 18),

                  // Commitment Type Selector (Ongoing Subscription vs Finite EMI / Loan)
                  Text(
                    'COMMITMENT TYPE',
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
                              commitmentTypeChildren[0],
                              const SizedBox(height: CoveSpace.xs),
                              commitmentTypeChildren[1],
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: commitmentTypeChildren[0]),
                              Expanded(child: commitmentTypeChildren[1]),
                            ],
                          ),
                  ),
              const SizedBox(height: 18),

              // Financed Through (Card, Person, Bank, etc.)
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: CoveSpace.section,
                  runSpacing: CoveSpace.xs,
                  children: [
                    Text(
                      'FINANCED THROUGH',
                      style: CoveType.capsPage.copyWith(color: cv.textSecondary),
                    ),
                    Text(
                      'Card, Person, or Bank',
                      style: CoveType.barLabel.copyWith(
                        color: cv.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: CoveSpace.sm),
              CovePillInput(
                controller: _financedThroughController,
                hintText: 'e.g. HDFC Regalia, Dad, Amex, Apple Card',
                onChanged: (val) => setState(() {}),
                prefixIcon: Icon(
                  Icons.credit_card_outlined,
                  size: 18,
                  color: cv.textSecondary,
                ),
                suffix: _financedThroughController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 16,
                          color: cv.textSecondary,
                        ),
                        onPressed: () {
                          _financedThroughController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              // Real-time suggestions of previously input text
              if (financingSuggestions.isNotEmpty) ...[
                const SizedBox(height: CoveSpace.sm),
                Wrap(
                  spacing: CoveSpace.sm,
                  runSpacing: 6,
                  children: financingSuggestions.take(6).map((source) {
                    final isExact = _financedThroughController.text.trim().toLowerCase() == source.toLowerCase();
                    return InkWell(
                      onTap: () {
                        _financedThroughController.text = source;
                        _financedThroughController.selection = TextSelection.fromPosition(
                          TextPosition(offset: source.length),
                        );
                        setState(() {});
                      },
                      customBorder: CoveShape.border(CoveRadius.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: CoveShape.decoration(
                          CoveRadius.pill,
                          color: isExact
                              ? cv.accentWash
                              : cv.surfaceRow,
                          side: BorderSide(
                            color: isExact
                                ? cv.accentFill
                                : cv.lineHairline,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history,
                              size: 12,
                              color: isExact ? cv.accentText : cv.textSecondary,
                            ),
                            const SizedBox(width: CoveSpace.xs),
                            Text(
                              source,
                              style: CoveType.rowSub.copyWith(
                                fontWeight: isExact ? FontWeight.w600 : FontWeight.w500,
                                color: isExact ? cv.accentText : cv.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 18),

              // EMI Configuration Section
              if (_endDate != null || (_totalInstallments != null && _totalInstallments! > 0)) ...[
                // Actual Number of Months (Tenure) & Installments Paid
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: CoveSpace.section,
                    runSpacing: CoveSpace.xs,
                    children: [
                      Text(
                        'TOTAL TENURE & INSTALLMENTS',
                        style: CoveType.capsPage.copyWith(
                          color: cv.textSecondary,
                        ),
                      ),
                      if (_totalInstallments != null && _totalInstallments! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: CoveSpace.sm,
                            vertical: 2,
                          ),
                          decoration: CoveShape.decoration(
                            CoveRadius.pill,
                            color: cv.accentWash,
                            side: BorderSide(
                              color: cv.accentFill.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '$_effectivePaidInstallments/$_totalInstallments paid',
                            style: CoveType.barLabel.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cv.accentText,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: CoveSpace.sm),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: CoveShape.decoration(
                    CoveRadius.inline,
                    color: cv.surfaceRow,
                    side: BorderSide(color: cv.lineHairline, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total tenure row with stepper
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_totalInstallments ?? 12} Months Total',
                                  style: CoveType.rowTitle.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cv.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tenure duration for this EMI',
                                  style: CoveType.barLabel.copyWith(
                                    color: cv.textSecondary,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: CoveShape.decoration(
                              CoveRadius.pill,
                              color: cv.surfaceCard,
                              side: BorderSide(color: cv.lineHairline, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.remove, size: 16),
                                  onPressed: (_totalInstallments ?? 12) > 1
                                      ? () => _updateTenure((_totalInstallments ?? 12) - 1)
                                      : null,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: CoveSpace.xs,
                                  ),
                                  child: Text(
                                    '${_totalInstallments ?? 12}',
                                    style: CoveType.readout.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: cv.textPrimary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.add, size: 16),
                                  onPressed: (_totalInstallments ?? 12) < 120
                                      ? () => _updateTenure((_totalInstallments ?? 12) + 1)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Quick selection chips for total tenure
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [3, 6, 9, 12, 18, 24, 36, 48].map((months) {
                          final isSelected = _totalInstallments == months;
                          return GestureDetector(
                            onTap: () => _updateTenure(months),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: CoveShape.decoration(
                                CoveRadius.pill,
                                color: isSelected
                                    ? cv.accentWash
                                    : cv.surfaceCard,
                                side: BorderSide(
                                  color: isSelected ? cv.accentFill : cv.lineHairline,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '$months mos',
                                style: CoveType.barLabel.copyWith(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: isSelected ? cv.accentText : cv.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Divider(color: cv.lineHairline, height: 1),
                      const SizedBox(height: 14),
                      // Installments Paid row with editable text input and stepper
                      LayoutBuilder(
                        builder: (context, paidConstraints) {
                          final paidLabelColumn = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: CoveSpace.xs,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Paid So Far',
                                    style: CoveType.rowTitle.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: cv.textPrimary,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: CoveShape.decoration(
                                      CoveRadius.pill,
                                      color: cv.accentWash,
                                    ),
                                    child: Text(
                                      'Syncs with Last Due',
                                      style: CoveType.barLabel.copyWith(
                                        color: cv.accentText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${((_totalInstallments ?? 12) - _effectivePaidInstallments).clamp(0, _totalInstallments ?? 12)} remaining of ${_totalInstallments ?? 12}',
                                style: CoveType.barLabel.copyWith(
                                  color: cv.textSecondary,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          );
                          final paidStepper = Container(
                            decoration: CoveShape.decoration(
                              CoveRadius.pill,
                              color: cv.surfaceCard,
                              side: BorderSide(color: cv.lineHairline, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.remove, size: 16),
                                  onPressed: _effectivePaidInstallments > 0
                                      ? () {
                                          final next = _effectivePaidInstallments - 1;
                                          setState(() {
                                            _paidInstallments = next;
                                            _paidInstallmentsController.text = '$next';
                                            _recalculateEndDate();
                                          });
                                        }
                                      : null,
                                ),
                                SizedBox(
                                  width: 44,
                                  child: TextField(
                                    controller: _paidInstallmentsController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: CoveType.readout.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: cv.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                      border: InputBorder.none,
                                      hintText: '$_effectivePaidInstallments',
                                      hintStyle: CoveType.readout.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: cv.textSecondary.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    onChanged: (val) {
                                      final trimmed = val.trim();
                                      final total = _totalInstallments ?? 12;
                                      if (trimmed.isEmpty) {
                                        setState(() {
                                          _paidInstallments = _calculatePaidFromEndDate(
                                            endDate: _endDate,
                                            total: total,
                                          );
                                        });
                                      } else {
                                        final parsed = int.tryParse(trimmed);
                                        if (parsed != null) {
                                          final clamped = parsed.clamp(0, total);
                                          setState(() {
                                            _paidInstallments = clamped;
                                            _recalculateEndDate();
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.add, size: 16),
                                  onPressed: _effectivePaidInstallments < (_totalInstallments ?? 12)
                                      ? () {
                                          final next = _effectivePaidInstallments + 1;
                                          setState(() {
                                            _paidInstallments = next;
                                            _paidInstallmentsController.text = '$next';
                                            _recalculateEndDate();
                                          });
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          );

                          if (paidConstraints.maxWidth < 320) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                paidLabelColumn,
                                const SizedBox(height: CoveSpace.sm),
                                paidStepper,
                              ],
                            );
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: paidLabelColumn),
                              const SizedBox(width: CoveSpace.md),
                              paidStepper,
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Last Installment / Ends On date picker
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: CoveSpace.section,
                    runSpacing: CoveSpace.xs,
                    children: [
                      Text(
                        'LAST PAYMENT / ENDS ON',
                        style: CoveType.capsPage.copyWith(
                          color: cv.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _endDate = null;
                          _totalInstallments = null;
                          _paidInstallments = null;
                          _paidInstallmentsController.clear();
                        }),
                        child: Text(
                          'Convert to Sub',
                          style: CoveType.rowSub.copyWith(
                            color: cv.statusAlertText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CoveSpace.sm),
                InkWell(
                  onTap: _pickEndDate,
                  customBorder: CoveShape.border(CoveRadius.inline),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: CoveSpace.md,
                    ),
                    decoration: CoveShape.decoration(
                      CoveRadius.inline,
                      color: cv.surfaceRow,
                      side: BorderSide(
                        color: cv.accentFill.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_available_outlined,
                          size: 18,
                          color: cv.accentText,
                        ),
                        const SizedBox(width: CoveSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _endDate != null
                                    ? DateFormat('EEEE, MMMM d, y').format(_endDate!)
                                    : 'Calculate end date',
                                style: CoveType.rowTitle.copyWith(
                                  color: cv.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _endDate != null
                                    ? 'Ends on ${DateFormat('MMM y').format(_endDate!)} · in sync with paid installments'
                                    : 'Tap to pick custom date',
                                style: CoveType.barLabel.copyWith(
                                  color: cv.textSecondary,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.edit_calendar_outlined,
                          size: 18,
                          color: cv.accentText,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Billing Cycle
              Text(
                'BILLING CYCLE',
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
                          _buildCyclePill(
                            label: 'Monthly',
                            isSelected: _billingCycle == 'monthly',
                            onTap: () =>
                                setState(() => _billingCycle = 'monthly'),
                          ),
                          const SizedBox(height: CoveSpace.xs),
                          _buildCyclePill(
                            label: 'Annual',
                            isSelected: _billingCycle == 'annual',
                            onTap: () =>
                                setState(() => _billingCycle = 'annual'),
                          ),
                          const SizedBox(height: CoveSpace.xs),
                          _buildCyclePill(
                            label: _billingCycle == 'custom'
                                ? 'Custom (${_customMonths}m)'
                                : 'Custom',
                            isSelected: _billingCycle == 'custom',
                            onTap: () =>
                                setState(() => _billingCycle = 'custom'),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _buildCyclePill(
                              label: 'Monthly',
                              isSelected: _billingCycle == 'monthly',
                              onTap: () =>
                                  setState(() => _billingCycle = 'monthly'),
                            ),
                          ),
                          Expanded(
                            child: _buildCyclePill(
                              label: 'Annual',
                              isSelected: _billingCycle == 'annual',
                              onTap: () =>
                                  setState(() => _billingCycle = 'annual'),
                            ),
                          ),
                          Expanded(
                            child: _buildCyclePill(
                              label: _billingCycle == 'custom'
                                  ? 'Custom (${_customMonths}m)'
                                  : 'Custom',
                              isSelected: _billingCycle == 'custom',
                              onTap: () =>
                                  setState(() => _billingCycle = 'custom'),
                            ),
                          ),
                        ],
                      ),
              ),

              // Custom Duration Card
              if (_billingCycle == 'custom') ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: CoveShape.decoration(
                    CoveRadius.inline,
                    color: cv.surfaceRow,
                    side: BorderSide(
                      color: cv.accentFill.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Every $_customMonths months',
                                  style: CoveType.rowTitle.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cv.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _customMonths == 7
                                      ? 'e.g. 6+1 months WiFi plan'
                                      : 'Recurring billing interval',
                                  style: CoveType.barLabel.copyWith(
                                    color: cv.textSecondary,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: CoveSpace.sm),
                          // Stepper controls
                          Container(
                            decoration: CoveShape.decoration(
                              CoveRadius.pill,
                              color: cv.surfaceCard,
                              side: BorderSide(color: cv.lineHairline, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.remove, size: 16),
                                  onPressed: _customMonths > 2
                                      ? () => setState(() => _customMonths--)
                                      : null,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: CoveSpace.xs,
                                  ),
                                  child: Text(
                                    '$_customMonths',
                                    style: CoveType.readout.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: cv.textPrimary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.add, size: 16),
                                  onPressed: _customMonths < 60
                                      ? () => setState(() => _customMonths++)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: CoveSpace.sm,
                        runSpacing: 6,
                        children: [
                          _buildCustomMonthChip(label: '3 mos', months: 3),
                          _buildCustomMonthChip(label: '6 mos', months: 6),
                          _buildCustomMonthChip(label: '7 mos (6+1)', months: 7),
                          _buildCustomMonthChip(label: '9 mos', months: 9),
                          _buildCustomMonthChip(label: '14 mos', months: 14),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Next Renewal Date
              Text(
                'NEXT PAYMENT DATE',
                style: CoveType.capsPage.copyWith(color: cv.textSecondary),
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
                    side: BorderSide(color: cv.lineHairline, width: 1),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isScaled ? CoveSpace.sm : 0,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: cv.textSecondary,
                      ),
                      const SizedBox(width: CoveSpace.md),
                      Expanded(
                        child: Text(
                          DateFormat('EEEE, MMMM d, y').format(_nextBillingDate),
                          style: CoveType.body.copyWith(color: cv.textPrimary),
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 20,
                        color: cv.accentText,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Category Selector
              Text(
                'CATEGORY',
                style: CoveType.capsPage.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _category == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: CoveSpace.sm),
                      child: InkWell(
                        onTap: () => setState(() => _category = cat),
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
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? cv.accentText : cv.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // Paid By
              Text(
                'PAID BY',
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
                          _buildSelectorPill(
                            label: myName,
                            isSelected: _paidBy == myId ||
                                (_paidBy != 'split' &&
                                    _paidBy != '50/50' &&
                                    _paidBy !=
                                        (partnerProfile.userId ??
                                            'partner_user') &&
                                    _paidBy != 'partner_user'),
                            onTap: () => setState(() => _paidBy = myId),
                          ),
                          const SizedBox(height: CoveSpace.xs),
                          _buildSelectorPill(
                            label: 'Split (50/50)',
                            isSelected:
                                _paidBy == 'split' || _paidBy == '50/50',
                            onTap: () => setState(() => _paidBy = 'split'),
                          ),
                          const SizedBox(height: CoveSpace.xs),
                          _buildSelectorPill(
                            label: partnerName,
                            isSelected: _paidBy ==
                                    (partnerProfile.userId ?? 'partner_user') ||
                                _paidBy == 'partner_user',
                            onTap: () => setState(() => _paidBy =
                                partnerProfile.userId ?? 'partner_user'),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _buildSelectorPill(
                              label: myName,
                              isSelected: _paidBy == myId ||
                                  (_paidBy != 'split' &&
                                      _paidBy != '50/50' &&
                                      _paidBy !=
                                          (partnerProfile.userId ??
                                              'partner_user') &&
                                      _paidBy != 'partner_user'),
                              onTap: () => setState(() => _paidBy = myId),
                            ),
                          ),
                          Expanded(
                            child: _buildSelectorPill(
                              label: 'Split (50/50)',
                              isSelected:
                                  _paidBy == 'split' || _paidBy == '50/50',
                              onTap: () => setState(() => _paidBy = 'split'),
                            ),
                          ),
                          Expanded(
                            child: _buildSelectorPill(
                              label: partnerName,
                              isSelected: _paidBy ==
                                      (partnerProfile.userId ??
                                          'partner_user') ||
                                  _paidBy == 'partner_user',
                              onTap: () => setState(() => _paidBy =
                                  partnerProfile.userId ?? 'partner_user'),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 22),

              // Visibility Segmented Selector: Shared vs Private
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
                          _buildVisibilityPill(
                            icon: Icons.people_outline,
                            label: 'Shared with $partnerName',
                            isSelected: !_isPrivate,
                            onTap: () => setState(() => _isPrivate = false),
                          ),
                          const SizedBox(height: CoveSpace.xs),
                          _buildVisibilityPill(
                            icon: Icons.visibility_off_outlined,
                            label: 'Private to Me',
                            isSelected: _isPrivate,
                            onTap: () => setState(() => _isPrivate = true),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _buildVisibilityPill(
                              icon: Icons.people_outline,
                              label: 'Shared with $partnerName',
                              isSelected: !_isPrivate,
                              onTap: () => setState(() => _isPrivate = false),
                            ),
                          ),
                          const SizedBox(width: CoveSpace.xs),
                          Expanded(
                            child: _buildVisibilityPill(
                              icon: Icons.visibility_off_outlined,
                              label: 'Private to Me',
                              isSelected: _isPrivate,
                              onTap: () => setState(() => _isPrivate = true),
                            ),
                          ),
                        ],
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        10,
                        CoveSpace.sm,
                        10,
                        6,
                      ),
                      child: Text(
                        _isPrivate
                            ? 'Private commitments stay strictly on this device and are excluded from shared partner totals. 0 bytes are sent to cloud or $partnerName.'
                            : 'Shared commitments are end-to-end encrypted with your Home key and synced to $partnerName.',
                        style: CoveType.barLabel.copyWith(
                          color: cv.textSecondary,
                          fontWeight: FontWeight.w400,
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
                  style: CoveType.readout.copyWith(
                    color: cv.statusAlertText,
                  ),
                ),
              ],

              const SizedBox(height: CoveSpace.lg),

              // Save Button
              CovePillButton(
                label: isEditing ? 'Save Changes' : 'Add Commitment',
                isLoading: _isSaving,
                onPressed: _handleSave,
                isFullWidth: true,
              ),

              if (isEditing) ...[
                const SizedBox(height: CoveSpace.md),
                CovePillButton(
                  label: widget.existing!.isActive
                      ? 'Cancel / Pause Commitment'
                      : 'Reactivate Commitment',
                  variant: CoveButtonVariant.secondary,
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final controller = ref.read(subscriptionControllerProvider);
                    if (widget.existing!.isActive) {
                      await controller.cancelSubscription(
                        widget.existing!.id,
                        isPrivate: widget.existing!.isPrivate,
                      );
                    } else {
                      await controller.reactivateSubscription(
                        widget.existing!.id,
                        isPrivate: widget.existing!.isPrivate,
                      );
                    }
                    if (mounted) navigator.pop();
                  },
                  isFullWidth: true,
                ),
              ],
            ],
          );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCyclePill({
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
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: CoveSpace.sm,
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
              size: 16,
              color: isSelected ? cv.textPrimary : cv.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: CoveType.rowSub.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? cv.textPrimary : cv.textSecondary,
                ),
                overflow: isScaled ? null : TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomMonthChip({required String label, required int months}) {
    final cv = context.cv;
    final isSelected = _customMonths == months;
    return InkWell(
      onTap: () => setState(() => _customMonths = months),
      customBorder: CoveShape.border(CoveRadius.pill),
      child: AnimatedContainer(
        duration: CoveMotion.q(context),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: CoveShape.decoration(
          CoveRadius.pill,
          color: isSelected ? cv.accentWash : cv.surfaceCard,
          side: BorderSide(
            color: isSelected ? cv.accentFill : cv.lineHairline,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: CoveType.barLabel.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? cv.accentText : cv.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final cv = context.cv;
    final isScaled = MediaQuery.textScalerOf(context).scale(1.0) > 1.0;

    return InkWell(
      onTap: onTap,
      customBorder: CoveShape.border(CoveRadius.pill),
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
          color: isSelected ? cv.surfaceCard : Colors.transparent,
          side: isSelected
              ? BorderSide(color: cv.lineHairline, width: 1)
              : BorderSide.none,
          shadows: isSelected
              ? [
                  BoxShadow(
                    color: cv.surfaceScrim.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: CoveType.readout.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? cv.textPrimary : cv.textSecondary,
          ),
          overflow: isScaled ? null : TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
