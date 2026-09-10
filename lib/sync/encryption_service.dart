import 'dart:typed_data';

class EncryptedPayload {
  final Uint8List ciphertext;
  final Uint8List nonce;

  const EncryptedPayload({
    required this.ciphertext,
    required this.nonce,
  });
}

/// Abstract contract for on-device authenticated symmetric encryption via libsodium.
abstract class EncryptionService {
  /// Generates a cryptographically secure 256-bit symmetric Home Key.
  Uint8List generateHomeKey();

  /// Encrypts an arbitrary UTF-8/JSON payload with the shared home key.
  Future<EncryptedPayload> encrypt({
    required String plaintextJson,
    required Uint8List homeKey,
  });

  /// Decrypts a ciphertext payload using the shared home key.
  Future<String> decrypt({
    required EncryptedPayload payload,
    required Uint8List homeKey,
  });
}
