import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../../sync/db/app_database.dart';
import 'subscription_controller.dart';

class SubscriptionFormSheet extends ConsumerStatefulWidget {
  final LocalSubscription? existing;

  const SubscriptionFormSheet({super.key, this.existing});

  static Future<void> show(BuildContext context, {LocalSubscription? existing}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubscriptionFormSheet(existing: existing),
    );
  }

  @override
  ConsumerState<SubscriptionFormSheet> createState() => _SubscriptionFormSheetState();
}

class _SubscriptionFormSheetState extends ConsumerState<SubscriptionFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late String _currency;
  late String _billingCycle; // 'monthly' | 'annual'
  late DateTime _nextBillingDate;
  String? _category;
  late bool _isPrivate;
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
      text: item != null ? item.amount.toStringAsFixed(2) : '',
    );
    _currency = item?.currency ?? 'USD';
    _billingCycle = item?.billingCycle ?? 'monthly';
    _nextBillingDate = item?.nextBillingDate ?? DateTime.now().add(const Duration(days: 30));
    _category = item?.category ?? 'Streaming';
    _isPrivate = item?.isPrivate ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
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

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter a subscription name.');
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

    try {
      final controller = ref.read(subscriptionControllerProvider);
      if (widget.existing != null) {
        await controller.updateSubscription(
          id: widget.existing!.id,
          name: name,
          amount: amount,
          currency: _currency,
          billingCycle: _billingCycle,
          nextBillingDate: _nextBillingDate,
          category: _category,
          isPrivate: _isPrivate,
        );
      } else {
        await controller.createSubscription(
          name: name,
          amount: amount,
          currency: _currency,
          billingCycle: _billingCycle,
          nextBillingDate: _nextBillingDate,
          category: _category,
          isPrivate: _isPrivate,
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
    final isEditing = widget.existing != null;
    final mediaQuery = MediaQuery.of(context);

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
                    isEditing ? 'Edit Subscription' : 'New Subscription',
                    style: typography.title.copyWith(fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name Input
              Text('SERVICE NAME', style: typography.caption),
              const SizedBox(height: 8),
              CovePillInput(
                controller: _nameController,
                hintText: 'e.g. Spotify Duo, Netflix, Fiber',
                prefixIcon: Icon(Icons.repeat_outlined, size: 18, color: colors.textMuted),
              ),
              const SizedBox(height: 18),

              // Amount & Cycle Row
              Row(
                children: [
                  Expanded(
                    flex: 5,
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
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Next Renewal Date
              Text('NEXT RENEWAL DATE', style: typography.caption),
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
                            label: 'Shared with Partner',
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
                            ? 'Private subscriptions stay strictly on this device and are excluded from shared partner totals. 0 bytes are sent to cloud or partner.'
                            : 'Shared subscriptions are end-to-end encrypted with your Home key and synced to your partner.',
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
                label: isEditing ? 'Save Changes' : 'Add Subscription',
                isLoading: _isSaving,
                onPressed: _handleSave,
                isFullWidth: true,
              ),

              if (isEditing) ...[
                const SizedBox(height: 12),
                CovePillButton(
                  label: widget.existing!.isActive
                      ? 'Cancel / Pause Subscription'
                      : 'Reactivate Subscription',
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
              color: isSelected ? colors.accentPrimary : colors.textMuted,
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
}
