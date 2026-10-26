import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'pairing_wordlist.dart';

/// A 32-byte X25519 keypair (`crypto_box` public + secret key) generated
/// ephemerally by a joiner when requesting to join a home with a 6-digit code.
class PairingBoxKeyPair {
  final Uint8List publicKey;
  final Uint8List secretKey;

  PairingBoxKeyPair({
    required Uint8List publicKey,
    required Uint8List secretKey,
  })  : publicKey = Uint8List.fromList(publicKey),
        secretKey = Uint8List.fromList(secretKey) {
    if (this.publicKey.length != PairingCrypto.keyLength) {
      throw ArgumentError(
        'Public key must be ${PairingCrypto.keyLength} bytes.',
      );
    }
    if (this.secretKey.length != PairingCrypto.keyLength) {
      throw ArgumentError(
        'Secret key must be ${PairingCrypto.keyLength} bytes.',
      );
    }
  }

  String get publicKeyBase64 => base64Encode(publicKey);
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

/// Cryptographic primitives for approved-code invites (`17-invite-and-keys.md` §1):
/// - X25519 keypair generation (`crypto_box` 32-byte keys)
/// - Anonymous sealed boxes (`crypto_box_seal` / `crypto_box_seal_open`)
/// - 22-bit Short Authentication String (SAS) two-word derivation from
///   `SHA-256(joiner_public_key ‖ code)` against the 2,048-word list.
class PairingCrypto {
  static const int keyLength = 32;
  static const int _nonceLength = 12;
  static const int _tagLengthBits = 128;
  static const int _tagLengthBytes = 16;

  static final BigInt _p = (BigInt.one << 255) - BigInt.from(19);
  static final BigInt _a24 = BigInt.from(121665);
  static final Uint8List _basePoint = Uint8List(32)..[0] = 9;

  /// Generates a fresh 32-byte X25519 keypair using a CSPRNG.
  static PairingBoxKeyPair generateKeyPair({Random? random}) {
    final rng = random ?? Random.secure();
    final secretKey = Uint8List(keyLength);
    for (var i = 0; i < keyLength; i++) {
      secretKey[i] = rng.nextInt(256);
    }
    final publicKey = _x25519(secretKey, _basePoint);
    return PairingBoxKeyPair(
      publicKey: publicKey,
      secretKey: secretKey,
    );
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
    if (joinerPublicKey.length != keyLength) {
      throw ArgumentError('Joiner public key must be $keyLength bytes.');
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

  /// Convenience helper accepting a Base64-encoded joiner public key.
  static PairingVerificationWords deriveVerificationWordsFromBase64({
    required String joinerPublicKeyBase64,
    required String code,
  }) {
    return deriveVerificationWords(
      joinerPublicKey: Uint8List.fromList(base64Decode(joinerPublicKeyBase64)),
      code: code,
    );
  }

  /// Seals [plaintext] anonymously to [recipientPublicKey] (`crypto_box_seal`).
  /// Output format: `ephemeral_pk (32 bytes) ‖ aead_ciphertext_with_tag`.
  /// Only the holder of the secret key matching [recipientPublicKey] can open it.
  static Uint8List cryptoBoxSeal({
    required Uint8List plaintext,
    required Uint8List recipientPublicKey,
    Random? random,
  }) {
    if (recipientPublicKey.length != keyLength) {
      throw ArgumentError('Recipient public key must be $keyLength bytes.');
    }

    final ephemeral = generateKeyPair(random: random);
    final sharedSecret = _x25519(ephemeral.secretKey, recipientPublicKey);
    _assertNonZeroSharedSecret(sharedSecret);

    final derived = _deriveSealKeyAndNonce(
      sharedSecret: sharedSecret,
      ephemeralPublicKey: ephemeral.publicKey,
      recipientPublicKey: recipientPublicKey,
    );

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(derived.key),
          _tagLengthBits,
          derived.nonce,
          derived.aad,
        ),
      );

    final ciphertextWithTag = cipher.process(plaintext);
    final sealed = Uint8List(keyLength + ciphertextWithTag.length);
    sealed.setRange(0, keyLength, ephemeral.publicKey);
    sealed.setRange(keyLength, sealed.length, ciphertextWithTag);
    return sealed;
  }

  /// Opens a [sealedBox] created by [cryptoBoxSeal] using [recipientKeyPair].
  /// Throws [FormatException] or [InvalidCipherTextException] if the box is
  /// malformed, tampered with, or sealed to a different public key.
  static Uint8List cryptoBoxSealOpen({
    required Uint8List sealedBox,
    required PairingBoxKeyPair recipientKeyPair,
  }) {
    if (sealedBox.length < keyLength + _tagLengthBytes) {
      throw const FormatException('Sealed box is truncated.');
    }

    final ephemeralPublicKey = Uint8List.sublistView(sealedBox, 0, keyLength);
    final ciphertextWithTag = Uint8List.sublistView(sealedBox, keyLength);

    final sharedSecret = _x25519(
      recipientKeyPair.secretKey,
      ephemeralPublicKey,
    );
    _assertNonZeroSharedSecret(sharedSecret);

    final derived = _deriveSealKeyAndNonce(
      sharedSecret: sharedSecret,
      ephemeralPublicKey: ephemeralPublicKey,
      recipientPublicKey: recipientKeyPair.publicKey,
    );

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(derived.key),
          _tagLengthBits,
          derived.nonce,
          derived.aad,
        ),
      );

    return cipher.process(ciphertextWithTag);
  }

  static void _assertNonZeroSharedSecret(Uint8List secret) {
    var acc = 0;
    for (final b in secret) {
      acc |= b;
    }
    if (acc == 0) {
      throw const FormatException('Invalid low-order X25519 public key.');
    }
  }

  static ({Uint8List key, Uint8List nonce, Uint8List aad})
      _deriveSealKeyAndNonce({
    required Uint8List sharedSecret,
    required Uint8List ephemeralPublicKey,
    required Uint8List recipientPublicKey,
  }) {
    final aad = Uint8List(keyLength * 2);
    aad.setRange(0, keyLength, ephemeralPublicKey);
    aad.setRange(keyLength, keyLength * 2, recipientPublicKey);

    // Nonce derived deterministically from ephemeral_pk || recipient_pk
    // (mirrors libsodium crypto_box_seal nonce = H(epk || pk)).
    final nonceDigest = sha256Bytes(aad);
    final nonce = Uint8List.fromList(nonceDigest.sublist(0, _nonceLength));

    // Symmetric key derived from H(shared_secret || ephemeral_pk || recipient_pk).
    final keyMaterial = Uint8List(sharedSecret.length + aad.length);
    keyMaterial.setRange(0, sharedSecret.length, sharedSecret);
    keyMaterial.setRange(sharedSecret.length, keyMaterial.length, aad);
    final key = sha256Bytes(keyMaterial);

    return (key: key, nonce: nonce, aad: aad);
  }

  /// Computes a 32-byte SHA-256 digest of [data].
  static Uint8List sha256Bytes(Uint8List data) {
    return SHA256Digest().process(data);
  }

  /// RFC 7748 X25519 scalar multiplication over Curve25519.
  static Uint8List _x25519(Uint8List scalarBytes, Uint8List uBytes) {
    final k = Uint8List.fromList(scalarBytes);
    k[0] &= 248;
    k[31] &= 127;
    k[31] |= 64;

    final uCopy = Uint8List.fromList(uBytes);
    uCopy[31] &= 127;

    final kInt = _decodeLittleEndian(k);
    final u = _decodeLittleEndian(uCopy) % _p;

    var x1 = u;
    var x2 = BigInt.one;
    var z2 = BigInt.zero;
    var x3 = u;
    var z3 = BigInt.one;
    var swap = 0;

    for (var t = 254; t >= 0; t--) {
      final kT = ((kInt >> t) & BigInt.one).toInt();
      swap ^= kT;
      if (swap != 0) {
        final tmpX = x2;
        x2 = x3;
        x3 = tmpX;
        final tmpZ = z2;
        z2 = z3;
        z3 = tmpZ;
      }
      swap = kT;

      final a = (x2 + z2) % _p;
      final aa = (a * a) % _p;
      final b = (x2 - z2 + _p) % _p;
      final bb = (b * b) % _p;
      final e = (aa - bb + _p) % _p;
      final c = (x3 + z3) % _p;
      final d = (x3 - z3 + _p) % _p;
      final da = (d * a) % _p;
      final cb = (c * b) % _p;

      final dacbSum = (da + cb) % _p;
      x3 = (dacbSum * dacbSum) % _p;

      final dacbDiff = (da - cb + _p) % _p;
      final dacbDiffSq = (dacbDiff * dacbDiff) % _p;
      z3 = (x1 * dacbDiffSq) % _p;

      x2 = (aa * bb) % _p;
      final a24e = (_a24 * e) % _p;
      final aaPlusA24e = (aa + a24e) % _p;
      z2 = (e * aaPlusA24e) % _p;
    }

    if (swap != 0) {
      final tmpX = x2;
      x2 = x3;
      x3 = tmpX;
      final tmpZ = z2;
      z2 = z3;
      z3 = tmpZ;
    }

    final z2Inv = z2.modPow(_p - BigInt.two, _p);
    final result = (x2 * z2Inv) % _p;
    return _encodeLittleEndian(result);
  }

  static BigInt _decodeLittleEndian(Uint8List bytes) {
    var result = BigInt.zero;
    for (var i = bytes.length - 1; i >= 0; i--) {
      result = (result << 8) | BigInt.from(bytes[i]);
    }
    return result;
  }

  static Uint8List _encodeLittleEndian(BigInt value) {
    final out = Uint8List(keyLength);
    var v = value;
    final mask = BigInt.from(0xFF);
    for (var i = 0; i < keyLength; i++) {
      out[i] = (v & mask).toInt();
      v >>= 8;
    }
    return out;
  }
}
