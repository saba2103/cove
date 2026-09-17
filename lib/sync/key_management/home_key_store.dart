import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure platform storage for Home symmetric encryption keys.
/// Stores a map of `homeId -> 256-bit symmetric key` securely in the hardware
/// enclave (iOS/macOS Keychain, Android Keystore, Web LocalStorage).
class HomeKeyStore {
  final FlutterSecureStorage _storage;
  static const String _keyPrefix = 'cove_home_key_';
  static const String _homeIdsListKey = 'cove_registered_home_ids';

  HomeKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  FlutterSecureStorage get storage => _storage;

  /// Saves a symmetric key for a specific home.
  Future<void> saveKey(String homeId, Uint8List key) async {
    final base64Key = base64UrlEncode(key);
    await _storage.write(key: '$_keyPrefix$homeId', value: base64Key);

    // Track list of known home IDs
    final existingIds = await getAllHomeIds();
    if (!existingIds.contains(homeId)) {
      existingIds.add(homeId);
      await _storage.write(
        key: _homeIdsListKey,
        value: jsonEncode(existingIds),
      );
    }
  }

  /// Retrieves the symmetric key for a specific home, or null if not found.
  Future<Uint8List?> getKey(String homeId) async {
    final base64Key = await _storage.read(key: '$_keyPrefix$homeId');
    if (base64Key == null) return null;
    return base64Url.decode(base64Key);
  }

  /// Checks if a key exists for a given home.
  Future<bool> hasKey(String homeId) async {
    final key = await getKey(homeId);
    return key != null;
  }

  /// Returns all registered home IDs.
  Future<List<String>> getAllHomeIds() async {
    final raw = await _storage.read(key: _homeIdsListKey);
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
    await _storage.delete(key: '$_keyPrefix$homeId');
    final existingIds = await getAllHomeIds();
    existingIds.remove(homeId);
    await _storage.write(
      key: _homeIdsListKey,
      value: jsonEncode(existingIds),
    );
  }

  /// Clears all keys across all homes (e.g. on full app reset).
  Future<void> clearAll() async {
    final ids = await getAllHomeIds();
    for (final id in ids) {
      await _storage.delete(key: '$_keyPrefix$id');
    }
    await _storage.delete(key: _homeIdsListKey);
  }
}
