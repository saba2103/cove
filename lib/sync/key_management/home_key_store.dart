import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure platform storage for Home symmetric encryption keys.
/// Stores a map of `homeId -> 256-bit symmetric key` securely across:
/// 1. Fast in-memory cache (zero latency)
/// 2. Primary hardware enclave / EncryptedSharedPreferences
/// 3. Fallback standard secure storage
class HomeKeyStore {
  final FlutterSecureStorage _primaryStorage;
  final FlutterSecureStorage _fallbackStorage;
  final Map<String, Uint8List> _memoryCache = {};

  static const String _keyPrefix = 'cove_home_key_';
  static const String _homeIdsListKey = 'cove_registered_home_ids';

  HomeKeyStore({
    FlutterSecureStorage? storage,
    FlutterSecureStorage? fallbackStorage,
  })  : _primaryStorage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
            ),
        _fallbackStorage = fallbackStorage ??
            (storage ??
                const FlutterSecureStorage(
                  aOptions: AndroidOptions(encryptedSharedPreferences: false),
                  mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
                ));

  FlutterSecureStorage get storage => _primaryStorage;

  /// Saves a symmetric key for a specific home across all storage tiers.
  Future<void> saveKey(String homeId, Uint8List key) async {
    _memoryCache[homeId] = key;
    final base64Key = base64UrlEncode(key);

    try {
      await _primaryStorage.write(key: '$_keyPrefix$homeId', value: base64Key);
    } catch (e) {
      debugPrint('[HomeKeyStore] Primary storage write error: $e');
    }

    try {
      await _fallbackStorage.write(key: '$_keyPrefix$homeId', value: base64Key);
    } catch (_) {}

    // Track list of known home IDs
    try {
      final existingIds = await getAllHomeIds();
      if (!existingIds.contains(homeId)) {
        existingIds.add(homeId);
        final encodedIds = jsonEncode(existingIds);
        await _primaryStorage.write(
          key: _homeIdsListKey,
          value: encodedIds,
        );
        try {
          await _fallbackStorage.write(
            key: _homeIdsListKey,
            value: encodedIds,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[HomeKeyStore] Error tracking home IDs: $e');
    }
  }

  /// Retrieves the symmetric key for a specific home, or null if not found.
  /// Checks memory cache -> primary storage -> fallback storage.
  Future<Uint8List?> getKey(String homeId) async {
    if (_memoryCache.containsKey(homeId)) {
      return _memoryCache[homeId];
    }

    String? base64Key;
    try {
      base64Key = await _primaryStorage.read(key: '$_keyPrefix$homeId');
    } catch (e) {
      debugPrint('[HomeKeyStore] Primary storage read error: $e');
    }

    if (base64Key == null) {
      try {
        base64Key = await _fallbackStorage.read(key: '$_keyPrefix$homeId');
        if (base64Key != null) {
          // Auto-migrate to primary storage
          await _primaryStorage.write(key: '$_keyPrefix$homeId', value: base64Key);
        }
      } catch (_) {}
    }

    if (base64Key == null) return null;

    try {
      final decoded = base64Url.decode(base64Key);
      _memoryCache[homeId] = decoded;
      return decoded;
    } catch (e) {
      debugPrint('[HomeKeyStore] Base64 decode error for key $homeId: $e');
      return null;
    }
  }

  /// Checks if a key exists for a given home.
  Future<bool> hasKey(String homeId) async {
    final key = await getKey(homeId);
    return key != null;
  }

  /// Returns all registered home IDs.
  Future<List<String>> getAllHomeIds() async {
    String? raw;
    try {
      raw = await _primaryStorage.read(key: _homeIdsListKey);
    } catch (_) {}

    if (raw == null) {
      try {
        raw = await _fallbackStorage.read(key: _homeIdsListKey);
      } catch (_) {}
    }

    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Removes the key for a specific home.
  Future<void> removeKey(String homeId) async {
    _memoryCache.remove(homeId);
    try {
      await _primaryStorage.delete(key: '$_keyPrefix$homeId');
    } catch (_) {}
    try {
      await _fallbackStorage.delete(key: '$_keyPrefix$homeId');
    } catch (_) {}

    final existingIds = await getAllHomeIds();
    existingIds.remove(homeId);
    final encodedIds = jsonEncode(existingIds);
    try {
      await _primaryStorage.write(
        key: _homeIdsListKey,
        value: encodedIds,
      );
    } catch (_) {}
    try {
      await _fallbackStorage.write(
        key: _homeIdsListKey,
        value: encodedIds,
      );
    } catch (_) {}
  }

  /// Clears all keys across all homes (e.g. on full app reset).
  Future<void> clearAll() async {
    final ids = await getAllHomeIds();
    for (final id in ids) {
      await removeKey(id);
    }
    _memoryCache.clear();
    try {
      await _primaryStorage.delete(key: _homeIdsListKey);
    } catch (_) {}
    try {
      await _fallbackStorage.delete(key: _homeIdsListKey);
    } catch (_) {}
  }
}
