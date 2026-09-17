import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';

class MonthlyBudgetNotifier extends Notifier<double?> {
  static FlutterSecureStorage storage = const FlutterSecureStorage();
  static const _keyPrefix = 'cove_monthly_budget_';
  static final Set<MonthlyBudgetNotifier> _activeNotifiers = {};

  @override
  double? build() {
    _activeNotifiers.add(this);
    ref.onDispose(() => _activeNotifiers.remove(this));

    final homeId = ref.watch(activeHomeIdProvider);
    if (homeId != null && homeId.isNotEmpty) {
      _loadBudget(homeId);
    }
    return null;
  }

  Future<void> _loadBudget(String homeId) async {
    try {
      final val = await storage.read(key: '$_keyPrefix$homeId');
      if (val != null && val.isNotEmpty) {
        final parsed = double.tryParse(val);
        if (parsed != null && parsed > 0) {
          state = parsed;
        }
      }
    } catch (_) {}
  }

  static Future<void> updateFromRemote({
    required String homeId,
    required double? amount,
  }) async {
    try {
      if (amount != null && amount > 0) {
        await storage.write(key: '$_keyPrefix$homeId', value: amount.toString());
      } else {
        await storage.delete(key: '$_keyPrefix$homeId');
      }
    } catch (_) {}

    for (final notifier in _activeNotifiers) {
      final activeHome = notifier.ref.read(activeHomeIdProvider);
      if (activeHome == homeId) {
        notifier.state = (amount != null && amount > 0) ? amount : null;
      }
    }
  }

  Future<void> setBudget(double amount) async {
    if (amount <= 0) return;
    final homeId = ref.read(activeHomeIdProvider);
    if (homeId == null) return;

    state = amount;
    try {
      await storage.write(key: '$_keyPrefix$homeId', value: amount.toString());
    } catch (_) {}

    try {
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'monthly_budget_updated',
        payload: {
          'home_id': homeId,
          'amount': amount,
        },
        targetHomeId: homeId,
      );
    } catch (_) {}
  }

  Future<void> clearBudget() async {
    final homeId = ref.read(activeHomeIdProvider);
    if (homeId == null) return;

    state = null;
    try {
      await storage.delete(key: '$_keyPrefix$homeId');
    } catch (_) {}

    try {
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'monthly_budget_cleared',
        payload: {
          'home_id': homeId,
        },
        targetHomeId: homeId,
      );
    } catch (_) {}
  }
}

final monthlyBudgetProvider =
    NotifierProvider<MonthlyBudgetNotifier, double?>(MonthlyBudgetNotifier.new);
