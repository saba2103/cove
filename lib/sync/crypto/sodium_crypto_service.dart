import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import '../encryption_service.dart';

/// Cryptographic service providing authenticated symmetric encryption.
/// Generates 256-bit symmetric keys and encrypts event payloads using
/// Authenticated Encryption with Associated Data (AEAD - AES-GCM / SecretBox).
class SodiumCryptoService implements EncryptionService {
  static const int keyLength = 32; // 256 bits
  static const int nonceLength = 12; // 96 bits for GCM / ChaCha
  static const int tagLength = 16; // 128 bits tag

  final Random _secureRandom = Random.secure();

  @override
  Uint8List generateHomeKey() {
    final key = Uint8List(keyLength);
    for (int i = 0; i < keyLength; i++) {
      key[i] = _secureRandom.nextInt(256);
    }
    return key;
  }

  Uint8List generateNonce() {
    final nonce = Uint8List(nonceLength);
    for (int i = 0; i < nonceLength; i++) {
      nonce[i] = _secureRandom.nextInt(256);
    }
    return nonce;
  }

  @override
  Future<EncryptedPayload> encrypt({
    required String plaintextJson,
    required Uint8List homeKey,
  }) async {
    if (homeKey.length != keyLength) {
      throw ArgumentError('Home key must be exactly $keyLength bytes.');
    }

    final nonce = generateNonce();
    final plaintextBytes = utf8.encode(plaintextJson);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true, // forEncryption
        AEADParameters(
          KeyParameter(homeKey),
          tagLength * 8, // 128 bit tag
          nonce,
          Uint8List(0), // associated data
        ),
      );

    final ciphertext = cipher.process(Uint8List.fromList(plaintextBytes));

    return EncryptedPayload(
      ciphertext: ciphertext,
      nonce: nonce,
    );
  }

  @override
  Future<String> decrypt({
    required EncryptedPayload payload,
    required Uint8List homeKey,
  }) async {
    if (homeKey.length != keyLength) {
      throw ArgumentError('Home key must be exactly $keyLength bytes.');
    }

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false, // forDecryption
        AEADParameters(
          KeyParameter(homeKey),
          tagLength * 8,
          payload.nonce,
          Uint8List(0),
        ),
      );

    final decryptedBytes = cipher.process(payload.ciphertext);
    return utf8.decode(decryptedBytes);
  }

  /// Serializes EncryptedPayload into a single Base64 transport string
  /// suitable for Supabase's `home_events.encrypted_payload` column.
  String serializeToTransportString(EncryptedPayload payload) {
    final combined = <String, dynamic>{
      'c': base64Encode(payload.ciphertext),
      'n': base64Encode(payload.nonce),
    };
    return jsonEncode(combined);
  }

  /// Deserializes a transport string from Supabase back into an EncryptedPayload.
  EncryptedPayload deserializeFromTransportString(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return EncryptedPayload(
      ciphertext: base64Decode(decoded['c'] as String),
      nonce: base64Decode(decoded['n'] as String),
    );
  }
}
