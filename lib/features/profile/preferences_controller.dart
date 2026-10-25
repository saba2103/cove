import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../add/add_draft.dart';

class CurrencyOption {
  final String code;
  final String symbol;
  final String name;

  const CurrencyOption({
    required this.code,
    required this.symbol,
    required this.name,
  });
}

const supportedCurrencies = [
  CurrencyOption(code: 'USD', symbol: '\$', name: 'US Dollar'),
  CurrencyOption(code: 'EUR', symbol: '€', name: 'Euro'),
  CurrencyOption(code: 'GBP', symbol: '£', name: 'British Pound'),
  CurrencyOption(code: 'CAD', symbol: 'CA\$', name: 'Canadian Dollar'),
  CurrencyOption(code: 'AUD', symbol: 'AU\$', name: 'Australian Dollar'),
  CurrencyOption(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
  CurrencyOption(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
  CurrencyOption(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc'),
];

class CurrencyNotifier extends Notifier<CurrencyOption> {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _currencyKey = 'cove_preferred_currency';
  static const _homeCurrencyKeyPrefix = 'cove_home_currency_';
  static String? cachedInitialCurrency;

  @override
  CurrencyOption build() {
    // 1. Active home's currency from the database is authoritative
    final activeHomeAsync = ref.watch(activeHomeProvider);
    final activeHome = activeHomeAsync.value;
    if (activeHome != null && activeHome.currency.isNotEmpty) {
      final match = supportedCurrencies.firstWhere(
        (c) => c.code == activeHome.currency,
        orElse: () => supportedCurrencies.first,
      );
      cachedInitialCurrency = match.code;
      return match;
    }

    // 2. Fallback while home is loading or before first home is selected
    if (cachedInitialCurrency != null && cachedInitialCurrency!.isNotEmpty) {
      final match = supportedCurrencies.firstWhere(
        (c) => c.code == cachedInitialCurrency,
        orElse: () => supportedCurrencies.first,
      );
      return match;
    }

    final activeHomeId = ref.watch(activeHomeIdProvider);
    if (activeHomeId != null) {
      _loadHomeCurrency(activeHomeId);
    } else {
      _loadLegacyCurrency();
    }
    return supportedCurrencies.first; // Default USD
  }

  Future<void> _loadHomeCurrency(String homeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pCode = prefs.getString('$_homeCurrencyKeyPrefix$homeId') ?? prefs.getString(_currencyKey);
      if (pCode != null) {
        cachedInitialCurrency = pCode;
        state = supportedCurrencies.firstWhere(
          (c) => c.code == pCode,
          orElse: () => supportedCurrencies.first,
        );
        return;
      }
      final code = await _storage.read(key: '$_homeCurrencyKeyPrefix$homeId');
      if (code != null) {
        final match = supportedCurrencies.firstWhere(
          (c) => c.code == code,
          orElse: () => supportedCurrencies.first,
        );
        state = match;
      } else {
        await _loadLegacyCurrency();
      }
    } catch (_) {}
  }

  Future<void> _loadLegacyCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pCode = prefs.getString(_currencyKey);
      if (pCode != null) {
        cachedInitialCurrency = pCode;
        state = supportedCurrencies.firstWhere(
          (c) => c.code == pCode,
          orElse: () => supportedCurrencies.first,
        );
        return;
      }
      final code = await _storage.read(key: _currencyKey);
      if (code != null) {
        final match = supportedCurrencies.firstWhere(
          (c) => c.code == code,
          orElse: () => supportedCurrencies.first,
        );
        state = match;
      }
    } catch (_) {}
  }

  Future<void> setCurrency(CurrencyOption option) async {
    state = option;
    cachedInitialCurrency = option.code;
    final activeHomeId = ref.read(activeHomeIdProvider);

    // 1. Synchronously persist to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currencyKey, option.code);
      if (activeHomeId != null) {
        await prefs.setString('$_homeCurrencyKeyPrefix$activeHomeId', option.code);
      }
    } catch (_) {}

    // 2. Persist to active home in local database
    if (activeHomeId != null) {
      try {
        final db = ref.read(appDatabaseProvider);
        await (db.update(db.localHomes)..where((t) => t.id.equals(activeHomeId))).write(
          LocalHomesCompanion(currency: drift.Value(option.code)),
        );
        await (db.update(db.localExpenses)..where((t) => t.homeId.equals(activeHomeId))).write(
          LocalExpensesCompanion(currency: drift.Value(option.code)),
        );
        await (db.update(db.localSubscriptions)..where((t) => t.homeId.equals(activeHomeId))).write(
          LocalSubscriptionsCompanion(currency: drift.Value(option.code)),
        );
        await _storage.write(key: '$_homeCurrencyKeyPrefix$activeHomeId', value: option.code);
      } catch (_) {}

      // 3. Emit home_currency_updated sync event so partner's device updates instantly
      try {
        final emitAction = ref.read(coveEmitActionProvider);
        await emitAction(
          eventType: 'home_currency_updated',
          payload: {
            'id': activeHomeId,
            'currency': option.code,
          },
          targetHomeId: activeHomeId,
        );
      } catch (_) {}

      // 4. Update homes table in Supabase if online
      final supabase = ref.read(supabaseClientProvider);
      if (supabase != null) {
        try {
          await supabase.from('homes').update({'currency': option.code}).eq('id', activeHomeId);
        } catch (_) {}
      }
    }

    // 5. Fallback device cache
    try {
      await _storage.write(key: _currencyKey, value: option.code);
    } catch (_) {}
  }
}

final currencyPreferenceProvider =
    NotifierProvider<CurrencyNotifier, CurrencyOption>(CurrencyNotifier.new);

/// Persisted `{kind, id}` reference for the **Again** row in the Add picker
/// (`design/specs/14-add-flow.md` §6).
///
/// Only `expense`, `task`, and `event` are ever stored here; `habit`,
/// `commitment`, and `routine` renew themselves and never become Again.
@immutable
class AddAgainPreference {
  final AddKind kind;
  final String id;

  const AddAgainPreference({
    required this.kind,
    required this.id,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddAgainPreference && kind == other.kind && id == other.id;

  @override
  int get hashCode => Object.hash(kind, id);
}

class AddAgainPreferenceNotifier extends Notifier<AddAgainPreference?> {
  static const String kindPreferenceKey = 'cove_add_again_kind';
  static const String idPreferenceKey = 'cove_add_again_id';
  static AddAgainPreference? cachedInitialAgain;

  static bool isSupportedKind(AddKind kind) =>
      kind == AddKind.expense ||
      kind == AddKind.task ||
      kind == AddKind.event;

  static AddKind? parseSupportedKind(String? rawKind) {
    switch (rawKind) {
      case 'expense':
        return AddKind.expense;
      case 'task':
        return AddKind.task;
      case 'event':
        return AddKind.event;
      default:
        return null;
    }
  }

  @override
  AddAgainPreference? build() {
    _load();
    return cachedInitialAgain;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawKind = prefs.getString(kindPreferenceKey);
      final rawId = prefs.getString(idPreferenceKey);
      final kind = parseSupportedKind(rawKind);
      if (kind != null && rawId != null && rawId.isNotEmpty) {
        final loaded = AddAgainPreference(kind: kind, id: rawId);
        if (state != loaded) {
          state = loaded;
        }
      }
    } catch (_) {}
  }

  Future<void> setAgain(AddKind kind, String id) async {
    if (!isSupportedKind(kind)) return;
    final cleanId = id.trim();
    if (cleanId.isEmpty) return;

    final next = AddAgainPreference(kind: kind, id: cleanId);
    state = next;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kindPreferenceKey, kind.name);
      await prefs.setString(idPreferenceKey, cleanId);
    } catch (_) {}
  }

  Future<void> clear() async {
    state = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kindPreferenceKey);
      await prefs.remove(idPreferenceKey);
    } catch (_) {}
  }
}

final addAgainPreferenceProvider =
    NotifierProvider<AddAgainPreferenceNotifier, AddAgainPreference?>(
  AddAgainPreferenceNotifier.new,
);
