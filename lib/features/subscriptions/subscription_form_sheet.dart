import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'commitment_models.dart';
import 'subscription_controller.dart';

class SubscriptionFormSheet extends ConsumerStatefulWidget {
  final LocalSubscription? existing;
  final bool initialIsEmi;

  const SubscriptionFormSheet({
    super.key,
    this.existing,
    this.initialIsEmi = false,
  });

  static Future<void> show(
    BuildContext context, {
    LocalSubscription? existing,
    bool initialIsEmi = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubscriptionFormSheet(
        existing: existing,
        initialIsEmi: initialIsEmi,
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

    _nextBillingDate = item?.nextBillingDate ?? DateTime.now().add(const Duration(days: 30));
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextBillingDate,
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
      setState(() => _nextBillingDate = picked);
    }
  }

  int _calculatePaidFromEndDate({DateTime? endDate, int? total, DateTime? now}) {
    final t = total ?? _totalInstallments ?? 12;
    if (endDate == null) return 0;
    final currentDate = now ?? DateTime.now();
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
    final initial = _endDate ?? _nextBillingDate.add(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime.now()) ? DateTime.now() : initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2045),
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
    final now = DateTime.now();
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
    final effectiveFinancedThrough = (isEmiSelected && financedThroughText.isNotEmpty)
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
    final colors = context.colors;
    final typography = context.typography;
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
                    isEditing ? 'Edit Commitment' : 'New Commitment',
                    style: typography.title.copyWith(fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Service Name
              Text('COMMITMENT NAME', style: typography.caption),
              const SizedBox(height: 8),
              CovePillInput(
                controller: _nameController,
                hintText: 'e.g. Netflix, Spotify, Car Loan, Device EMI',
                prefixIcon: Icon(Icons.autorenew_outlined,
                    size: 18, color: colors.textMuted),
              ),
              const SizedBox(height: 18),

              // Amount
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
              const SizedBox(height: 18),

              // Commitment Type Selector (Ongoing Subscription vs Finite EMI / Loan)
              Text('COMMITMENT TYPE', style: typography.caption),
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
                        label: 'Subscription',
                        isSelected: _endDate == null && (_totalInstallments == null || _totalInstallments == 0),
                        onTap: () => setState(() {
                          _endDate = null;
                          _totalInstallments = null;
                          _paidInstallments = null;
                          _paidInstallmentsController.clear();
                        }),
                      ),
                    ),
                    Expanded(
                      child: _buildSelectorPill(
                        label: 'EMI / Loan',
                        isSelected: _endDate != null || (_totalInstallments != null && _totalInstallments! > 0),
                        onTap: () => setState(() {
                          _totalInstallments ??= 12;
                          _paidInstallments ??= 0;
                          _paidInstallmentsController.text = '$_paidInstallments';
                          _recalculateEndDate();
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // EMI Configuration Section
              if (_endDate != null || (_totalInstallments != null && _totalInstallments! > 0)) ...[
                // Financed Through (Card, Person, Bank, etc.)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('FINANCED THROUGH', style: typography.caption),
                    Text(
                      'Card, Person, or Bank',
                      style: typography.caption.copyWith(
                        fontSize: 11,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CovePillInput(
                  controller: _financedThroughController,
                  hintText: 'e.g. HDFC Regalia, Dad, Amex, Apple Card',
                  onChanged: (val) => setState(() {}),
                  prefixIcon: Icon(
                    Icons.credit_card_outlined,
                    size: 18,
                    color: colors.textMuted,
                  ),
                  suffix: _financedThroughController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _financedThroughController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                // Real-time suggestions of previously input text
                if (financingSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
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
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isExact
                                ? colors.accentPrimary.withValues(alpha: 0.2)
                                : colors.surfaceRow,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isExact
                                  ? colors.accentPrimary
                                  : colors.borderHairline,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history,
                                size: 12,
                                color: isExact ? colors.accentPrimary : colors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                source,
                                style: TextStyle(
                                  fontFamily: 'GeneralSans',
                                  fontSize: 12,
                                  fontWeight: isExact ? FontWeight.w600 : FontWeight.w500,
                                  color: isExact ? colors.accentPrimary : colors.textPrimary,
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

                // Actual Number of Months (Tenure) & Installments Paid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL TENURE & INSTALLMENTS', style: typography.caption),
                    if (_totalInstallments != null && _totalInstallments! > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.accentPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: colors.accentPrimary.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '$_effectivePaidInstallments/$_totalInstallments paid',
                          style: TextStyle(
                            fontFamily: 'GeneralSans',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.accentPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceRow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.borderHairline, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total tenure row with stepper
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_totalInstallments ?? 12} Months Total',
                                style: typography.bodyRegular.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tenure duration for this EMI',
                                style: typography.caption.copyWith(
                                  fontSize: 11,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: colors.surfaceCard,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: colors.borderHairline, width: 1),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    '${_totalInstallments ?? 12}',
                                    style: TextStyle(
                                      fontFamily: 'GeneralSans',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: colors.textPrimary,
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
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.accentPrimary.withValues(alpha: 0.18)
                                    : colors.surfaceCard,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isSelected ? colors.accentPrimary : colors.borderHairline,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '$months mos',
                                style: TextStyle(
                                  fontFamily: 'GeneralSans',
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: isSelected ? colors.accentPrimary : colors.textMuted,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Divider(color: colors.borderHairline, height: 1),
                      const SizedBox(height: 14),
                      // Installments Paid row with editable text input and stepper
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Paid So Far',
                                      style: typography.bodyRegular.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: colors.accentPrimary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Syncs with Last Due',
                                        style: TextStyle(
                                          fontFamily: 'GeneralSans',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: colors.accentPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${((_totalInstallments ?? 12) - _effectivePaidInstallments).clamp(0, _totalInstallments ?? 12)} remaining of ${_totalInstallments ?? 12}',
                                  style: typography.caption.copyWith(
                                    fontSize: 11,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: colors.surfaceCard,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: colors.borderHairline, width: 1),
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
                                    style: TextStyle(
                                      fontFamily: 'GeneralSans',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: colors.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                      border: InputBorder.none,
                                      hintText: '$_effectivePaidInstallments',
                                      hintStyle: TextStyle(
                                        fontFamily: 'GeneralSans',
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        color: colors.textMuted.withValues(alpha: 0.5),
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
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Last Installment / Ends On date picker
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('LAST PAYMENT / ENDS ON', style: typography.caption),
                    GestureDetector(
                      onTap: () => setState(() {
                        _endDate = null;
                        _totalInstallments = null;
                        _paidInstallments = null;
                        _paidInstallmentsController.clear();
                      }),
                      child: Text(
                        'Convert to Sub',
                        style: typography.caption.copyWith(
                          color: colors.accentSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickEndDate,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.surfaceRow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.accentPrimary.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_available_outlined,
                          size: 18,
                          color: colors.accentPrimary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _endDate != null
                                    ? DateFormat('EEEE, MMMM d, y').format(_endDate!)
                                    : 'Calculate end date',
                                style: typography.bodyRegular.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _endDate != null
                                    ? 'Ends on ${DateFormat('MMM y').format(_endDate!)} · in sync with paid installments'
                                    : 'Tap to pick custom date',
                                style: typography.caption.copyWith(
                                  fontSize: 11,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.edit_calendar_outlined,
                          size: 18,
                          color: colors.accentPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Billing Cycle
              Text('BILLING CYCLE', style: typography.caption),
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
                      child: _buildCyclePill(
                        label: 'Monthly',
                        isSelected: _billingCycle == 'monthly',
                        onTap: () => setState(() => _billingCycle = 'monthly'),
                      ),
                    ),
                    Expanded(
                      child: _buildCyclePill(
                        label: 'Annual',
                        isSelected: _billingCycle == 'annual',
                        onTap: () => setState(() => _billingCycle = 'annual'),
                      ),
                    ),
                    Expanded(
                      child: _buildCyclePill(
                        label: _billingCycle == 'custom'
                            ? 'Custom (${_customMonths}m)'
                            : 'Custom',
                        isSelected: _billingCycle == 'custom',
                        onTap: () => setState(() => _billingCycle = 'custom'),
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
                  decoration: BoxDecoration(
                    color: colors.surfaceRow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.accentPrimary.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Every $_customMonths months',
                                style: typography.bodyRegular.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _customMonths == 7
                                    ? 'e.g. 6+1 months WiFi plan'
                                    : 'Recurring billing interval',
                                style: typography.caption.copyWith(
                                  color: colors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          // Stepper controls
                          Container(
                            decoration: BoxDecoration(
                              color: colors.surfaceCard,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: colors.borderHairline, width: 1),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    '$_customMonths',
                                    style: TextStyle(
                                      fontFamily: 'GeneralSans',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: colors.textPrimary,
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
                        spacing: 8,
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
              Text('NEXT PAYMENT DATE', style: typography.caption),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.surfaceRow,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colors.borderHairline, width: 1),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 18, color: colors.textMuted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          DateFormat('EEEE, MMMM d, y').format(_nextBillingDate),
                          style: typography.bodyRegular.copyWith(color: colors.textPrimary),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, size: 20, color: colors.accentPrimary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Category Selector
              Text('CATEGORY', style: typography.caption),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _category == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _category = cat),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? colors.accentPrimary : colors.textMuted,
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
                        isSelected: _paidBy == myId ||
                            (_paidBy != 'split' &&
                                _paidBy != '50/50' &&
                                _paidBy != (partnerProfile.userId ?? 'partner_user') &&
                                _paidBy != 'partner_user'),
                        onTap: () => setState(() => _paidBy = myId),
                      ),
                    ),
                    Expanded(
                      child: _buildSelectorPill(
                        label: 'Split (50/50)',
                        isSelected: _paidBy == 'split' || _paidBy == '50/50',
                        onTap: () => setState(() => _paidBy = 'split'),
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
              const SizedBox(height: 22),

              // Visibility Segmented Selector: Shared vs Private
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
                            label: 'Shared with $partnerName',
                            isSelected: !_isPrivate,
                            onTap: () => setState(() => _isPrivate = false),
                          ),
                        ),
                        const SizedBox(width: 4),
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
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                      child: Text(
                        _isPrivate
                            ? 'Private commitments stay strictly on this device and are excluded from shared partner totals. 0 bytes are sent to cloud or $partnerName.'
                            : 'Shared commitments are end-to-end encrypted with your Home key and synced to $partnerName.',
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

              // Save Button
              CovePillButton(
                label: isEditing ? 'Save Changes' : 'Add Commitment',
                isLoading: _isSaving,
                onPressed: _handleSave,
                isFullWidth: true,
              ),

              if (isEditing) ...[
                const SizedBox(height: 12),
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.surfaceCard : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: colors.accentPrimary.withValues(alpha: 0.5), width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? colors.textPrimary : colors.textMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'GeneralSans',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? colors.textPrimary : colors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomMonthChip({required String label, required int months}) {
    final colors = context.colors;
    final isSelected = _customMonths == months;
    return InkWell(
      onTap: () => setState(() => _customMonths = months),
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentPrimary.withValues(alpha: 0.18) : colors.surfaceCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? colors.accentPrimary : colors.borderHairline,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? colors.accentPrimary : colors.textMuted,
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
    final colors = context.colors;
    final typography = context.typography;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.surfaceCard : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: isSelected
              ? Border.all(color: colors.borderHairline, width: 1)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: typography.bodyRegular.copyWith(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? colors.textPrimary : colors.textMuted,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
