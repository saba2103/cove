import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/uuid_generator.dart';
import '../providers/cove_sync_providers.dart';
import 'pairing_crypto.dart';

/// Keyless server record in `public.pairing_codes`.
/// Never contains the pairing payload or home key.
class PairingCodeRecord {
  final String code;
  final String homeId;
  final String inviterId;
  final DateTime expiresAt;
  final String status;
  final DateTime createdAt;

  const PairingCodeRecord({
    required this.code,
    required this.homeId,
    required this.inviterId,
    required this.expiresAt,
    required this.status,
    required this.createdAt,
  });

  bool isExpiredAt(DateTime nowUtc) => !nowUtc.isBefore(expiresAt);

  Map<String, dynamic> toRow() => <String, dynamic>{
        'code': code,
        'home_id': homeId,
        'inviter_id': inviterId,
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'status': status,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory PairingCodeRecord.fromRow(Map<String, dynamic> row) {
    return PairingCodeRecord(
      code: row['code'] as String,
      homeId: row['home_id'] as String,
      inviterId: row['inviter_id'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String).toUtc(),
      status: (row['status'] as String?) ?? 'open',
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String).toUtc()
          : clock.now().toUtc(),
    );
  }

  PairingCodeRecord copyWith({
    String? status,
    DateTime? expiresAt,
  }) {
    return PairingCodeRecord(
      code: code,
      homeId: homeId,
      inviterId: inviterId,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

/// Server record in `public.pairing_requests`.
/// Holds only the joiner's public key and, once approved by the inviter,
/// a sealed box (`crypto_box_seal`) encrypted to that public key.
class PairingRequestRecord {
  final String id;
  final String code;
  final String joinerId;
  final String joinerName;
  final String joinerPublicKey;
  final String? sealedPayload;
  final String status;
  final DateTime createdAt;

  const PairingRequestRecord({
    required this.id,
    required this.code,
    required this.joinerId,
    required this.joinerName,
    required this.joinerPublicKey,
    this.sealedPayload,
    required this.status,
    required this.createdAt,
  });

  Uint8List get joinerPublicKeyBytes =>
      Uint8List.fromList(base64Decode(joinerPublicKey));

  PairingVerificationWords get verificationWords =>
      PairingCrypto.deriveVerificationWords(
        joinerPublicKey: joinerPublicKeyBytes,
        code: code,
      );

  Map<String, dynamic> toRow() => <String, dynamic>{
        'id': id,
        'code': code,
        'joiner_id': joinerId,
        'joiner_name': joinerName,
        'joiner_public_key': joinerPublicKey,
        'sealed_payload': sealedPayload,
        'status': status,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory PairingRequestRecord.fromRow(Map<String, dynamic> row) {
    return PairingRequestRecord(
      id: row['id'] as String,
      code: row['code'] as String,
      joinerId: row['joiner_id'] as String,
      joinerName: (row['joiner_name'] as String?) ?? 'Partner',
      joinerPublicKey: row['joiner_public_key'] as String,
      sealedPayload: row['sealed_payload'] as String?,
      status: (row['status'] as String?) ?? 'pending',
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String).toUtc()
          : clock.now().toUtc(),
    );
  }

  PairingRequestRecord copyWith({
    String? joinerPublicKey,
    String? sealedPayload,
    bool clearSealedPayload = false,
    String? status,
  }) {
    return PairingRequestRecord(
      id: id,
      code: code,
      joinerId: joinerId,
      joinerName: joinerName,
      joinerPublicKey: joinerPublicKey ?? this.joinerPublicKey,
      sealedPayload:
          clearSealedPayload ? null : (sealedPayload ?? this.sealedPayload),
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

/// Transport abstraction for `public.pairing_codes` and `public.pairing_requests`.
abstract class PairingRelay {
  static const int maxRequestsPerCode = 3;

  Future<void> insertPairingCode(PairingCodeRecord record);

  Future<PairingCodeRecord?> getPairingCode(String code);

  Future<PairingRequestRecord> submitJoinRequest({
    required String code,
    required String joinerId,
    required String joinerName,
    required String joinerPublicKey,
  });

  Future<List<PairingRequestRecord>> listPendingRequestsForCode(String code);

  Stream<List<PairingRequestRecord>> watchPendingRequestsForCode(String code);

  Future<PairingRequestRecord?> getRequestById(String requestId);

  Stream<PairingRequestRecord?> watchRequestById(String requestId);

  Future<void> approveRequest({
    required String requestId,
    required String code,
    required String sealedPayload,
  });

  Future<void> declineRequest({required String requestId});

  Future<void> markRequestDone({required String requestId});

  Future<void> cleanupDoneAndExpired({required DateTime nowUtc});
}

/// Supabase-backed implementation of [PairingRelay].
class SupabasePairingRelay implements PairingRelay {
  final SupabaseClient _supabase;

  SupabasePairingRelay(this._supabase);

  @override
  Future<void> insertPairingCode(PairingCodeRecord record) async {
    await _supabase.from('pairing_codes').upsert(record.toRow());
  }

  @override
  Future<PairingCodeRecord?> getPairingCode(String code) async {
    final row = await _supabase
        .from('pairing_codes')
        .select('code, home_id, inviter_id, expires_at, status, created_at')
        .eq('code', code)
        .maybeSingle();
    if (row == null) return null;
    return PairingCodeRecord.fromRow(row);
  }

  @override
  Future<PairingRequestRecord> submitJoinRequest({
    required String code,
    required String joinerId,
    required String joinerName,
    required String joinerPublicKey,
  }) async {
    final now = clock.now().toUtc();
    final codeRow = await getPairingCode(code);
    if (codeRow == null) {
      throw StateError(
        'Invalid or expired 6-digit code. Please check your partner\'s screen.',
      );
    }
    if (codeRow.isExpiredAt(now)) {
      throw StateError(
        'Pairing code has expired. Please request a new code.',
      );
    }
    if (codeRow.status != 'open') {
      throw StateError(
        'This pairing code has already been used. Ask for a new code.',
      );
    }

    final existingRows = await _supabase
        .from('pairing_requests')
        .select('id')
        .eq('code', code);
    if ((existingRows as List).length >= PairingRelay.maxRequestsPerCode) {
      throw StateError(
        'Too many join requests for this code. Please ask for a new code.',
      );
    }

    final request = PairingRequestRecord(
      id: generateCoveUuid(),
      code: code,
      joinerId: joinerId,
      joinerName: joinerName,
      joinerPublicKey: joinerPublicKey,
      status: 'pending',
      createdAt: now,
    );

    await _supabase.from('pairing_requests').insert(request.toRow());
    return request;
  }

  @override
  Future<List<PairingRequestRecord>> listPendingRequestsForCode(
    String code,
  ) async {
    final rows = await _supabase
        .from('pairing_requests')
        .select(
          'id, code, joiner_id, joiner_name, joiner_public_key, sealed_payload, status, created_at',
        )
        .eq('code', code)
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(PairingRequestRecord.fromRow)
        .toList();
  }

  @override
  Stream<List<PairingRequestRecord>> watchPendingRequestsForCode(String code) {
    return _supabase
        .from('pairing_requests')
        .stream(primaryKey: const ['id'])
        .eq('code', code)
        .map(
          (rows) => rows
              .map(PairingRequestRecord.fromRow)
              .where((r) => r.status == 'pending')
              .toList(),
        );
  }

  @override
  Future<PairingRequestRecord?> getRequestById(String requestId) async {
    final row = await _supabase
        .from('pairing_requests')
        .select(
          'id, code, joiner_id, joiner_name, joiner_public_key, sealed_payload, status, created_at',
        )
        .eq('id', requestId)
        .maybeSingle();
    if (row == null) return null;
    return PairingRequestRecord.fromRow(row);
  }

  @override
  Stream<PairingRequestRecord?> watchRequestById(String requestId) {
    return _supabase
        .from('pairing_requests')
        .stream(primaryKey: const ['id'])
        .eq('id', requestId)
        .map(
          (rows) =>
              rows.isEmpty ? null : PairingRequestRecord.fromRow(rows.first),
        );
  }

  @override
  Future<void> approveRequest({
    required String requestId,
    required String code,
    required String sealedPayload,
  }) async {
    await _supabase.from('pairing_requests').update({
      'sealed_payload': sealedPayload,
      'status': 'approved',
    }).eq('id', requestId);

    await _supabase.from('pairing_codes').update({
      'status': 'approved',
    }).eq('code', code);
  }

  @override
  Future<void> declineRequest({required String requestId}) async {
    await _supabase.from('pairing_requests').update({
      'sealed_payload': null,
      'status': 'declined',
    }).eq('id', requestId);
  }

  @override
  Future<void> markRequestDone({required String requestId}) async {
    await _supabase.from('pairing_requests').update({
      'status': 'done',
    }).eq('id', requestId);
  }

  @override
  Future<void> cleanupDoneAndExpired({required DateTime nowUtc}) async {
    try {
      await _supabase
          .from('pairing_requests')
          .delete()
          .inFilter('status', const ['done', 'declined']);
      await _supabase
          .from('pairing_codes')
          .delete()
          .lt('expires_at', nowUtc.toUtc().toIso8601String());
    } catch (_) {}
  }
}

/// Logged write operation recorded by [InMemoryPairingRelay] so tests can
/// inspect every server write and prove no write ever contains the home key.
class PairingRelayWriteLog {
  final String table;
  final String operation;
  final Map<String, dynamic> payload;

  const PairingRelayWriteLog({
    required this.table,
    required this.operation,
    required this.payload,
  });

  String toJsonString() => jsonEncode(payload);
}

/// In-memory implementation of [PairingRelay] enforcing the exact server
/// constraints (expiry, single-use once approved, max 3 requests per code)
/// and recording every write for security inspection.
class InMemoryPairingRelay implements PairingRelay {
  final Map<String, PairingCodeRecord> _codes = <String, PairingCodeRecord>{};
  final Map<String, PairingRequestRecord> _requests =
      <String, PairingRequestRecord>{};
  final List<PairingRelayWriteLog> writeLog = <PairingRelayWriteLog>[];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Map<String, PairingCodeRecord> get codes => Map.unmodifiable(_codes);
  Map<String, PairingRequestRecord> get requests => Map.unmodifiable(_requests);

  void _recordWrite(
    String table,
    String operation,
    Map<String, dynamic> payload,
  ) {
    writeLog.add(
      PairingRelayWriteLog(
        table: table,
        operation: operation,
        payload: Map<String, dynamic>.from(payload),
      ),
    );
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  /// Simulates a hostile server swapping a joiner's public key on a pending
  /// request (MITM test helper).
  void swapJoinerPublicKeyForTest({
    required String requestId,
    required String replacementPublicKeyBase64,
  }) {
    final existing = _requests[requestId];
    if (existing == null) {
      throw StateError('Unknown request $requestId');
    }
    final updated = existing.copyWith(
      joinerPublicKey: replacementPublicKeyBase64,
    );
    _requests[requestId] = updated;
    _recordWrite('pairing_requests', 'mitm_swap', updated.toRow());
  }

  @override
  Future<void> insertPairingCode(PairingCodeRecord record) async {
    _codes[record.code] = record;
    _recordWrite('pairing_codes', 'insert', record.toRow());
  }

  @override
  Future<PairingCodeRecord?> getPairingCode(String code) async {
    return _codes[code];
  }

  @override
  Future<PairingRequestRecord> submitJoinRequest({
    required String code,
    required String joinerId,
    required String joinerName,
    required String joinerPublicKey,
  }) async {
    final now = clock.now().toUtc();
    final codeRow = _codes[code];
    if (codeRow == null) {
      throw StateError(
        'Invalid or expired 6-digit code. Please check your partner\'s screen.',
      );
    }
    if (codeRow.isExpiredAt(now)) {
      throw StateError(
        'Pairing code has expired. Please request a new code.',
      );
    }
    if (codeRow.status != 'open') {
      throw StateError(
        'This pairing code has already been used. Ask for a new code.',
      );
    }

    final existingForCode =
        _requests.values.where((r) => r.code == code).length;
    if (existingForCode >= PairingRelay.maxRequestsPerCode) {
      throw StateError(
        'Too many join requests for this code. Please ask for a new code.',
      );
    }

    final request = PairingRequestRecord(
      id: generateCoveUuid(),
      code: code,
      joinerId: joinerId,
      joinerName: joinerName,
      joinerPublicKey: joinerPublicKey,
      status: 'pending',
      createdAt: now,
    );
    _requests[request.id] = request;
    _recordWrite('pairing_requests', 'insert', request.toRow());
    return request;
  }

  @override
  Future<List<PairingRequestRecord>> listPendingRequestsForCode(
    String code,
  ) async {
    return _requests.values
        .where((r) => r.code == code && r.status == 'pending')
        .toList();
  }

  @override
  Stream<List<PairingRequestRecord>> watchPendingRequestsForCode(
    String code,
  ) async* {
    yield await listPendingRequestsForCode(code);
    await for (final _ in _changes.stream) {
      yield await listPendingRequestsForCode(code);
    }
  }

  @override
  Future<PairingRequestRecord?> getRequestById(String requestId) async {
    return _requests[requestId];
  }

  @override
  Stream<PairingRequestRecord?> watchRequestById(String requestId) async* {
    yield _requests[requestId];
    await for (final _ in _changes.stream) {
      yield _requests[requestId];
    }
  }

  @override
  Future<void> approveRequest({
    required String requestId,
    required String code,
    required String sealedPayload,
  }) async {
    final req = _requests[requestId];
    if (req == null) {
      throw StateError('Unknown pairing request: $requestId');
    }
    final codeRow = _codes[code];
    if (codeRow == null || codeRow.status != 'open') {
      throw StateError('Pairing code $code is no longer open.');
    }

    final updatedReq = req.copyWith(
      sealedPayload: sealedPayload,
      status: 'approved',
    );
    _requests[requestId] = updatedReq;
    _recordWrite('pairing_requests', 'approve', {
      'id': requestId,
      'sealed_payload': sealedPayload,
      'status': 'approved',
    });

    final updatedCode = codeRow.copyWith(status: 'approved');
    _codes[code] = updatedCode;
    _recordWrite('pairing_codes', 'approve', {
      'code': code,
      'status': 'approved',
    });
  }

  @override
  Future<void> declineRequest({required String requestId}) async {
    final req = _requests[requestId];
    if (req == null) return;
    final updatedReq = req.copyWith(
      clearSealedPayload: true,
      status: 'declined',
    );
    _requests[requestId] = updatedReq;
    _recordWrite('pairing_requests', 'decline', {
      'id': requestId,
      'sealed_payload': null,
      'status': 'declined',
    });
  }

  @override
  Future<void> markRequestDone({required String requestId}) async {
    final req = _requests[requestId];
    if (req == null) return;
    final updatedReq = req.copyWith(status: 'done');
    _requests[requestId] = updatedReq;
    _recordWrite('pairing_requests', 'done', {
      'id': requestId,
      'status': 'done',
    });
  }

  @override
  Future<void> cleanupDoneAndExpired({required DateTime nowUtc}) async {
    final doneRequestIds = _requests.values
        .where((r) => r.status == 'done' || r.status == 'declined')
        .map((r) => r.id)
        .toList();
    for (final id in doneRequestIds) {
      _requests.remove(id);
    }

    final expiredCodes = _codes.values
        .where((c) => c.isExpiredAt(nowUtc) || c.status == 'approved')
        .map((c) => c.code)
        .toList();
    for (final code in expiredCodes) {
      final hasPendingOrApproved = _requests.values.any(
        (r) =>
            r.code == code &&
            (r.status == 'pending' || r.status == 'approved'),
      );
      if (!hasPendingOrApproved) {
        _codes.remove(code);
      }
    }
  }
}

final pairingRelayProvider = Provider<PairingRelay?>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  if (supabase == null) return null;
  return SupabasePairingRelay(supabase);
});
