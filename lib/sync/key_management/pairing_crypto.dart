import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart' show SHA256Digest;
// ignore: deprecated_member_use
import 'package:sodium_libs/sodium_libs.dart';

import 'pairing_wordlist.dart';

/// Wrapper around libsodium's `KeyPair` (`crypto_box_keypair`) generated
/// ephemerally by a joiner when requesting to join a home with a 6-digit code.
class PairingBoxKeyPair {
  final KeyPair keyPair;

  PairingBoxKeyPair(this.keyPair) {
    if (keyPair.publicKey.length != PairingCrypto.publicKeyLength) {
      throw ArgumentError(
        'Public key must be ${PairingCrypto.publicKeyLength} bytes.',
      );
    }
    if (keyPair.secretKey.length != PairingCrypto.secretKeyLength) {
      throw ArgumentError(
        'Secret key must be ${PairingCrypto.secretKeyLength} bytes.',
      );
    }
  }

  Uint8List get publicKey => keyPair.publicKey;
  SecureKey get secretKey => keyPair.secretKey;
  String get publicKeyBase64 => base64Encode(publicKey);

  void dispose() => keyPair.dispose();
}

/// Two verification words derived from `SHA-256(joiner_public_key ‖ code)`.
class PairingVerificationWords {
  final String word1;
  final String word2;
  final int word1Index;
  final int word2Index;

  const PairingVerificationWords({
    required this.word1,
    required this.word2,
    required this.word1Index,
    required this.word2Index,
  });

  /// Rendered like `AMBER · HARBOUR`.
  String get formatted => '$word1 · $word2';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PairingVerificationWords &&
          other.word1 == word1 &&
          other.word2 == word2 &&
          other.word1Index == word1Index &&
          other.word2Index == word2Index;

  @override
  int get hashCode => Object.hash(word1, word2, word1Index, word2Index);

  @override
  String toString() => formatted;
}

/// Cryptographic primitives for approved-code invites (`17-invite-and-keys.md` §1)
/// backed directly by `libsodium` (`package:sodium_libs/sodium_libs.dart`):
/// - `sodium.crypto.box.keyPair()`
/// - `sodium.crypto.box.seal(...)` / `sodium.crypto.box.sealOpen(...)`
/// - `sodium.randombytes` for the 6-digit pairing code
/// - 22-bit Short Authentication String (SAS) two-word derivation from
///   `SHA-256(joiner_public_key ‖ code)` against the 2,048-word list.
class PairingCrypto {
  static const int publicKeyLength = 32;
  static const int secretKeyLength = 32;

  static Sodium? _sodium;
  static Future<Sodium>? _initializing;

  /// Initialises `libsodium` once at startup and caches the [Sodium] instance.
  static Future<Sodium> ensureInitialized() async {
    final existing = _sodium;
    if (existing != null) return existing;
    final pending = _initializing;
    if (pending != null) return pending;

    final completer = Completer<Sodium>();
    _initializing = completer.future;
    try {
      final FutureOr<Sodium> initResult = SodiumInit.init();
      final instance = await initResult;
      _sodium = instance;
      completer.complete(instance);
      return instance;
    } catch (e, st) {
      _initializing = null;
      completer.completeError(e, st);
      rethrow;
    }
  }

  /// Returns the initialised [Sodium] instance. On native FFI targets,
  /// lazily initialises synchronously if [ensureInitialized] was not awaited yet.
  static Sodium get sodium {
    final existing = _sodium;
    if (existing != null) return existing;
    final FutureOr<Sodium> initResult = SodiumInit.init();
    if (initResult is Sodium) {
      _sodium = initResult;
      return initResult;
    }
    throw StateError(
      'PairingCrypto.ensureInitialized() must be awaited before using Sodium on Web.',
    );
  }

  /// Generates a fresh 6-digit pairing code (`100000..999999`) using
  /// `libsodium`'s CSPRNG (`randombytes`).
  static String generateSixDigitCode() {
    final s = sodium;
    // Use randombytes.buf with unbiased rejection sampling over 32-bit unsigned ints
    // (< 4294800000, the largest multiple of 900000 under 2^32).
    const int range = 900000;
    const int limit = (0x100000000 ~/ range) * range;
    while (true) {
      final bytes = s.randombytes.buf(4);
      final value = ByteData.sublistView(bytes).getUint32(0, Endian.little);
      if (value < limit) {
        return (100000 + (value % range)).toString();
      }
    }
  }

  /// Generates a fresh X25519 keypair using `sodium.crypto.box.keyPair()`,
  /// or `sodium.crypto.box.seedKeyPair(...)` when [seed] is provided for tests.
  static PairingBoxKeyPair generateKeyPair({Uint8List? seed}) {
    final s = sodium;
    if (seed != null) {
      if (seed.length != s.crypto.box.seedBytes) {
        throw ArgumentError(
          'Seed must be ${s.crypto.box.seedBytes} bytes.',
        );
      }
      final seedKey = s.secureCopy(seed);
      try {
        return PairingBoxKeyPair(s.crypto.box.seedKeyPair(seedKey));
      } finally {
        seedKey.dispose();
      }
    }
    return PairingBoxKeyPair(s.crypto.box.keyPair());
  }

  /// Derives the two matching verification words from
  /// `SHA-256(joiner_public_key ‖ code)`:
  /// the first 22 bits pick two words from the fixed 2,048-word list,
  /// rendered like `AMBER · HARBOUR`.
  static PairingVerificationWords deriveVerificationWords({
    required Uint8List joinerPublicKey,
    required String code,
  }) {
    assert(kPairingWordList.length == 2048);
    if (joinerPublicKey.length != publicKeyLength) {
      throw ArgumentError(
        'Joiner public key must be $publicKeyLength bytes.',
      );
    }
    final normalizedCode = code.replaceAll(RegExp(r'\s+'), '').trim();
    final codeBytes = utf8.encode(normalizedCode);

    final preimage = Uint8List(joinerPublicKey.length + codeBytes.length);
    preimage.setRange(0, joinerPublicKey.length, joinerPublicKey);
    preimage.setRange(joinerPublicKey.length, preimage.length, codeBytes);

    final digest = sha256Bytes(preimage);
    // First 22 bits of the SHA-256 digest:
    // byte 0 (8 bits) || byte 1 (8 bits) || top 6 bits of byte 2.
    final bits22 = (digest[0] << 14) | (digest[1] << 6) | (digest[2] >> 2);
    final word1Index = (bits22 >> 11) & 0x7FF;
    final word2Index = bits22 & 0x7FF;

    return PairingVerificationWords(
      word1: kPairingWordList[word1Index].toUpperCase(),
      word2: kPairingWordList[word2Index].toUpperCase(),
      word1Index: word1Index,
      word2Index: word2Index,
    );
  }

  /// Seals [plaintext] anonymously to [recipientPublicKey] using
  /// `sodium.crypto.box.seal` (`crypto_box_seal`).
  static Uint8List cryptoBoxSeal({
    required Uint8List plaintext,
    required Uint8List recipientPublicKey,
  }) {
    return sodium.crypto.box.seal(
      message: plaintext,
      publicKey: recipientPublicKey,
    );
  }

  /// Opens a [sealedBox] using `sodium.crypto.box.sealOpen` (`crypto_box_seal_open`).
  static Uint8List cryptoBoxSealOpen({
    required Uint8List sealedBox,
    required PairingBoxKeyPair recipientKeyPair,
  }) {
    return sodium.crypto.box.sealOpen(
      cipherText: sealedBox,
      publicKey: recipientKeyPair.publicKey,
      secretKey: recipientKeyPair.secretKey,
    );
  }

  /// Computes a 32-byte SHA-256 digest of [data].
  static Uint8List sha256Bytes(Uint8List data) {
    return SHA256Digest().process(data);
  }
}
