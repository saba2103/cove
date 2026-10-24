import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

/// Thrown when a backup cannot be decrypted with the supplied passphrase.
class BackupWrongPassphraseException implements Exception {
  const BackupWrongPassphraseException();
  @override
  String toString() => 'That passphrase does not unlock this backup.';
}

/// Thrown when a backup file is malformed or from an unknown format.
class BackupFormatException implements Exception {
  final String message;
  const BackupFormatException(this.message);
  @override
  String toString() => message;
}

/// Argon2id parameters used to stretch the recovery passphrase into a
/// 256-bit key-encryption key (KEK). Stored in clear inside every backup
/// envelope so any device can re-derive the KEK from the passphrase alone.
class BackupKdfParams {
  /// OWASP 2024 minimum profile for Argon2id: m=19 MiB, t=2, p=1.
  static const int defaultMemoryKiB = 19456;
  static const int defaultIterations = 2;
  static const int defaultParallelism = 1;
  static const int saltLength = 16;

  final Uint8List salt;
  final int memoryKiB;
  final int iterations;
  final int parallelism;

  const BackupKdfParams({
    required this.salt,
    this.memoryKiB = defaultMemoryKiB,
    this.iterations = defaultIterations,
    this.parallelism = defaultParallelism,
  });

  factory BackupKdfParams.generate({
    int memoryKiB = defaultMemoryKiB,
    int iterations = defaultIterations,
    int parallelism = defaultParallelism,
  }) {
    return BackupKdfParams(
      salt: BackupCrypto.randomBytes(saltLength),
      memoryKiB: memoryKiB,
      iterations: iterations,
      parallelism: parallelism,
    );
  }

  Map<String, dynamic> toJson() => {
        'alg': 'argon2id',
        'salt': base64Encode(salt),
        'm': memoryKiB,
        't': iterations,
        'p': parallelism,
      };

  factory BackupKdfParams.fromJson(Map<String, dynamic> json) {
    if (json['alg'] != 'argon2id') {
      throw BackupFormatException('Unsupported key derivation: ${json['alg']}');
    }
    return BackupKdfParams(
      salt: base64Decode(json['salt'] as String),
      memoryKiB: (json['m'] as num).toInt(),
      iterations: (json['t'] as num).toInt(),
      parallelism: (json['p'] as num).toInt(),
    );
  }
}

/// Self-describing encrypted backup file.
///
/// Layout (UTF-8 JSON):
/// - clear metadata: format, version, createdAt, schemaVersion, appVersion, kdf
/// - `wrap`: per-backup data key (DEK) sealed with the passphrase KEK (AES-256-GCM)
/// - `data`: gzipped JSON snapshot sealed with the DEK (AES-256-GCM)
class BackupEnvelope {
  static const String formatId = 'cove-backup';
  static const int formatVersion = 1;

  final DateTime createdAt;
  final int schemaVersion;
  final String appVersion;
  final BackupKdfParams kdf;
  final Uint8List wrapNonce;
  final Uint8List wrappedKey;
  final Uint8List dataNonce;
  final Uint8List dataCiphertext;

  const BackupEnvelope({
    required this.createdAt,
    required this.schemaVersion,
    required this.appVersion,
    required this.kdf,
    required this.wrapNonce,
    required this.wrappedKey,
    required this.dataNonce,
    required this.dataCiphertext,
  });

  /// Associated data binding every ciphertext to the envelope format, so a
  /// sealed blob cannot be transplanted into a different container version.
  static final Uint8List _aad = Uint8List.fromList(utf8.encode('$formatId/v$formatVersion'));

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode({
        'format': formatId,
        'v': formatVersion,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'schemaVersion': schemaVersion,
        'appVersion': appVersion,
        'kdf': kdf.toJson(),
        'wrap': {'nonce': base64Encode(wrapNonce), 'ct': base64Encode(wrappedKey)},
        'data': {'nonce': base64Encode(dataNonce), 'ct': base64Encode(dataCiphertext)},
      })));

  factory BackupEnvelope.fromBytes(Uint8List bytes) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupFormatException('This file is not a Cove backup.');
    }
    if (json['format'] != formatId) {
      throw const BackupFormatException('This file is not a Cove backup.');
    }
    final v = (json['v'] as num?)?.toInt() ?? 0;
    if (v > formatVersion) {
      throw const BackupFormatException(
        'This backup was made by a newer version of Cove. Update the app to restore it.',
      );
    }
    try {
      final wrap = json['wrap'] as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      return BackupEnvelope(
        createdAt: DateTime.parse(json['createdAt'] as String),
        schemaVersion: (json['schemaVersion'] as num).toInt(),
        appVersion: json['appVersion'] as String? ?? '',
        kdf: BackupKdfParams.fromJson(json['kdf'] as Map<String, dynamic>),
        wrapNonce: base64Decode(wrap['nonce'] as String),
        wrappedKey: base64Decode(wrap['ct'] as String),
        dataNonce: base64Decode(data['nonce'] as String),
        dataCiphertext: base64Decode(data['ct'] as String),
      );
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      throw const BackupFormatException('This backup file is damaged or incomplete.');
    }
  }
}

/// Result of decrypting a backup: the snapshot payload plus the KEK that
/// unlocked it (so the restoring device can keep using the same passphrase).
class OpenedBackup {
  final BackupEnvelope envelope;
  final Map<String, dynamic> payload;
  final Uint8List kek;

  const OpenedBackup({required this.envelope, required this.payload, required this.kek});
}

/// Pure-Dart cryptography for Drive backups (AES-256-GCM + Argon2id).
class BackupCrypto {
  static const int keyLength = 32;
  static const int nonceLength = 12;
  static const int tagBits = 128;

  static final Random _random = Random.secure();

  static Uint8List randomBytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _random.nextInt(256);
    }
    return out;
  }

  /// Derives the KEK from a passphrase. Runs Argon2id on a background isolate
  /// (where supported) so the UI stays responsive.
  static Future<Uint8List> deriveKey(String passphrase, BackupKdfParams params) {
    return compute(_deriveKeySync, <Object>[
      Uint8List.fromList(utf8.encode(passphrase)),
      params.salt,
      params.memoryKiB,
      params.iterations,
      params.parallelism,
    ]);
  }

  static Uint8List _deriveKeySync(List<Object> args) {
    final generator = Argon2BytesGenerator()
      ..init(Argon2Parameters(
        Argon2Parameters.ARGON2_id,
        args[1] as Uint8List,
        desiredKeyLength: keyLength,
        memory: args[2] as int,
        iterations: args[3] as int,
        lanes: args[4] as int,
      ));
    return generator.process(args[0] as Uint8List);
  }

  /// Encrypts [payload] into a backup envelope sealed with [kek].
  static Uint8List seal({
    required Map<String, dynamic> payload,
    required Uint8List kek,
    required BackupKdfParams kdf,
    required int schemaVersion,
    required String appVersion,
    DateTime? createdAt,
  }) {
    final dek = randomBytes(keyLength);
    final wrapNonce = randomBytes(nonceLength);
    final dataNonce = randomBytes(nonceLength);

    final compressed = GZipEncoder().encodeBytes(utf8.encode(jsonEncode(payload)));

    final envelope = BackupEnvelope(
      createdAt: createdAt ?? clock.now(),
      schemaVersion: schemaVersion,
      appVersion: appVersion,
      kdf: kdf,
      wrapNonce: wrapNonce,
      wrappedKey: _gcm(true, kek, wrapNonce, dek),
      dataNonce: dataNonce,
      dataCiphertext: _gcm(true, dek, dataNonce, compressed),
    );
    return envelope.toBytes();
  }

  /// Decrypts a backup with the user's recovery passphrase.
  static Future<OpenedBackup> open({
    required Uint8List envelopeBytes,
    required String passphrase,
  }) async {
    final envelope = BackupEnvelope.fromBytes(envelopeBytes);
    final kek = await deriveKey(passphrase, envelope.kdf);
    return OpenedBackup(
      envelope: envelope,
      payload: openWithKey(envelope, kek),
      kek: kek,
    );
  }

  /// Decrypts an already-parsed envelope with a known KEK.
  static Map<String, dynamic> openWithKey(BackupEnvelope envelope, Uint8List kek) {
    final Uint8List dek;
    try {
      dek = _gcm(false, kek, envelope.wrapNonce, envelope.wrappedKey);
    } on InvalidCipherTextException {
      throw const BackupWrongPassphraseException();
    } on ArgumentError {
      throw const BackupWrongPassphraseException();
    }

    try {
      final compressed = _gcm(false, dek, envelope.dataNonce, envelope.dataCiphertext);
      final json = utf8.decode(GZipDecoder().decodeBytes(compressed));
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupFormatException('This backup file is damaged or incomplete.');
    }
  }

  static Uint8List _gcm(bool encrypt, Uint8List key, Uint8List nonce, List<int> input) {
    if (key.length != keyLength) {
      throw ArgumentError('Key must be exactly $keyLength bytes.');
    }
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        encrypt,
        AEADParameters(KeyParameter(key), tagBits, nonce, BackupEnvelope._aad),
      );
    return cipher.process(Uint8List.fromList(input));
  }
}
