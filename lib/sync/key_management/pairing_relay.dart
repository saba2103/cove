import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/uuid_generator.dart';
import '../providers/cove_sync_providers.dart';
import 'pairing_crypto.dart';

/// Thrown when inserting a new 6-digit code into `public.pairing_codes`
/// collides with an existing primary key (`23505` / `duplicate key`).
class PairingCodeCollisionException implements Exception {
  final String code;

  const PairingCodeCollisionException(this.code);

  @override
  String toString() =>
      'PairingCodeCollisionException: code $code already exists.';
}

/// Keyless server record in `public.pairing_codes`.
/// Never contains the pairing payload or home key.
/// Readable only by the inviter (`inviter_id = auth.uid()`).
class PairingCodeRecord {
  final String code;
  final String homeId;
  final String inviterId;
  final DateTime expiresAt;
  final String status;
  final DateTime createdAt;
  final String? homeName;
  final String? inviterName;

  const PairingCodeRecord({
    required this.code,
    required this.homeId,
    required this.inviterId,
    required this.expiresAt,
    required this.status,
    required this.createdAt,
    this.homeName,
    this.inviterName,
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
      homeName: homeName,
      inviterName: inviterName,
    );
  }
}

/// Result returned by the `SECURITY DEFINER` function `lookup_pairing_code(code)`
/// for an open, unexpired code. Never exposes `home_id`, `inviter_id`, or keys.
class PairingCodeLookupResult {
  final String homeName;
  final String inviterName;
  final String status;

  const PairingCodeLookupResult({
    required this.homeName,
    required this.inviterName,
    required this.status,
  });

  factory PairingCodeLookupResult.fromRow(Map<String, dynamic> row) {
    return PairingCodeLookupResult(
      homeName: (row['home_name'] as String?) ?? 'Home',
      inviterName: (row['inviter_name'] as String?) ?? 'Partner',
      status: (row['status'] as String?) ?? 'open',
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
    String? code,
    String? joinerId,
    String? joinerPublicKey,
    String? sealedPayload,
    bool clearSealedPayload = false,
    String? status,
  }) {
    return PairingRequestRecord(
      id: id,
      code: code ?? this.code,
      joinerId: joinerId ?? this.joinerId,
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
  static const int maxRequestsPerUserPerHour = 5;
  static const int maxFailedLookupsPerUserPerHour = 5;

  /// Deletes the inviter's own expired `pairing_codes` rows before minting a
  /// new code.
  Future<void> deleteOwnExpiredCodes({
    required String inviterId,
    required DateTime nowUtc,
  });

  /// Inserts a new `pairing_codes` row. Throws [PairingCodeCollisionException]
  /// if `record.code` already exists.
  Future<void> insertPairingCode(PairingCodeRecord record);

  /// Reads a `pairing_codes` row owned by [inviterId].
  /// Under RLS, only the inviter can read their own `pairing_codes` rows.
  Future<PairingCodeRecord?> getOwnPairingCode({
    required String code,
    required String inviterId,
  });

  /// Calls the `SECURITY DEFINER` function `lookup_pairing_code(code)`, which
  /// returns only `home_name`, `inviter_name`, and `status` for an open,
  /// unexpired code, and `null` otherwise (counting failed lookups per user,
  /// max 5 per hour).
  Future<PairingCodeLookupResult?> lookupPairingCode({
    required String code,
    required String callerUserId,
  });

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
    String? actorUserId,
  });

  Future<void> declineRequest({
    required String requestId,
    String? actorUserId,
  });

  Future<void> markRequestDone({
    required String requestId,
    String? actorUserId,
  });

  Future<void> cleanupDoneAndExpired({
    required DateTime nowUtc,
    String? actorUserId,
  });
}

/// Supabase-backed implementation of [PairingRelay].
class SupabasePairingRelay implements PairingRelay {
  final SupabaseClient _supabase;

  SupabasePairingRelay(this._supabase);

  @override
  Future<void> deleteOwnExpiredCodes({
    required String inviterId,
    required DateTime nowUtc,
  }) async {
    await _supabase
        .from('pairing_codes')
        .delete()
        .eq('inviter_id', inviterId)
        .lt('expires_at', nowUtc.toUtc().toIso8601String());
  }

  @override
  Future<void> insertPairingCode(PairingCodeRecord record) async {
    try {
      await _supabase.from('pairing_codes').insert(record.toRow());
    } on PostgrestException catch (e) {
      if (e.code == '23505' ||
          e.message.toLowerCase().contains('duplicate key')) {
        throw PairingCodeCollisionException(record.code);
      }
      rethrow;
    }
  }

  @override
  Future<PairingCodeRecord?> getOwnPairingCode({
    required String code,
    required String inviterId,
  }) async {
    final row = await _supabase
        .from('pairing_codes')
        .select('code, home_id, inviter_id, expires_at, status, created_at')
        .eq('code', code)
        .eq('inviter_id', inviterId)
        .maybeSingle();
    if (row == null) return null;
    return PairingCodeRecord.fromRow(row);
  }

  @override
  Future<PairingCodeLookupResult?> lookupPairingCode({
    required String code,
    required String callerUserId,
  }) async {
    final res = await _supabase.rpc(
      'lookup_pairing_code',
      params: <String, dynamic>{'target_code': code},
    );
    if (res == null) return null;
    if (res is List) {
      if (res.isEmpty) return null;
      return PairingCodeLookupResult.fromRow(
        Map<String, dynamic>.from(res.first as Map),
      );
    }
    if (res is Map) {
      return PairingCodeLookupResult.fromRow(Map<String, dynamic>.from(res));
    }
    return null;
  }

  @override
  Future<PairingRequestRecord> submitJoinRequest({
    required String code,
    required String joinerId,
    required String joinerName,
    required String joinerPublicKey,
  }) async {
    final now = clock.now().toUtc();
    final lookup = await lookupPairingCode(
      code: code,
      callerUserId: joinerId,
    );
    if (lookup == null || lookup.status != 'open') {
      throw StateError(
        'Invalid or expired 6-digit code. Please check your partner\'s screen.',
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
    String? actorUserId,
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
  Future<void> declineRequest({
    required String requestId,
    String? actorUserId,
  }) async {
    await _supabase.from('pairing_requests').update({
      'sealed_payload': null,
      'status': 'declined',
    }).eq('id', requestId);
  }

  @override
  Future<void> markRequestDone({
    required String requestId,
    String? actorUserId,
  }) async {
    await _supabase.from('pairing_requests').update({
      'status': 'done',
    }).eq('id', requestId);
  }

  @override
  Future<void> cleanupDoneAndExpired({
    required DateTime nowUtc,
    String? actorUserId,
  }) async {
    try {
      await _supabase
          .from('pairing_requests')
          .delete()
          .inFilter('status', const ['done', 'declined']);
      if (actorUserId != null) {
        await deleteOwnExpiredCodes(
          inviterId: actorUserId,
          nowUtc: nowUtc,
        );
      }
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
/// constraints:
/// - Inviter reads only their own `pairing_codes`; joiners use `lookupPairingCode`.
/// - `insertPairingCode` rejects primary-key collisions with
///   [PairingCodeCollisionException].
/// - `deleteOwnExpiredCodes` removes only the inviter's own expired codes.
/// - Rate limits: max 5 failed code lookups per user per hour, and max 5
///   pairing requests per user per hour (plus max 3 requests per code).
/// - Immutability trigger on `pairing_requests`: `code`, `joiner_id`, and
///   `joiner_public_key` cannot be changed after insert; joiner may only set
///   `status = 'done'`; only inviter may set `sealed_payload`, `'approved'`,
///   or `'declined'`.
/// - Delete policy: only the joiner or the code's inviter may delete a request,
///   and only the code's inviter may delete a pairing code.
class InMemoryPairingRelay implements PairingRelay {
  final Map<String, PairingCodeRecord> _codes = <String, PairingCodeRecord>{};
  final Map<String, PairingRequestRecord> _requests =
      <String, PairingRequestRecord>{};
  final Map<String, List<DateTime>> _failedLookupTimestampsByUser =
      <String, List<DateTime>>{};
  final Map<String, List<DateTime>> _requestTimestampsByUser =
      <String, List<DateTime>>{};
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

  /// Simulates a hostile server (bypassing normal client triggers) swapping a
  /// joiner's public key on a pending request row in storage.
  void swapJoinerPublicKeyOnServerForTest({
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
    _recordWrite('pairing_requests', 'server_mitm_swap', updated.toRow());
  }

  @override
  Future<void> deleteOwnExpiredCodes({
    required String inviterId,
    required DateTime nowUtc,
  }) async {
    final expiredOwnCodes = _codes.values
        .where((c) => c.inviterId == inviterId && c.isExpiredAt(nowUtc))
        .map((c) => c.code)
        .toList();
    for (final code in expiredOwnCodes) {
      _codes.remove(code);
      _recordWrite('pairing_codes', 'delete_expired', {
        'code': code,
        'inviter_id': inviterId,
      });
    }
  }

  @override
  Future<void> insertPairingCode(PairingCodeRecord record) async {
    if (_codes.containsKey(record.code)) {
      throw PairingCodeCollisionException(record.code);
    }
    _codes[record.code] = record;
    _recordWrite('pairing_codes', 'insert', record.toRow());
  }

  /// Attempts to read `pairing_codes` as [inviterId].
  /// Under RLS, only the inviter (`record.inviterId == inviterId`) can see
  /// the row; any other authenticated user sees `null`.
  @override
  Future<PairingCodeRecord?> getOwnPairingCode({
    required String code,
    required String inviterId,
  }) async {
    final record = _codes[code];
    if (record == null) return null;
    if (record.inviterId != inviterId) return null;
    return record;
  }

  @override
  Future<PairingCodeLookupResult?> lookupPairingCode({
    required String code,
    required String callerUserId,
  }) async {
    final now = clock.now().toUtc();
    final cutoff = now.subtract(const Duration(hours: 1));
    final failures =
        (_failedLookupTimestampsByUser[callerUserId] ?? <DateTime>[])
          ..removeWhere((t) => !t.isAfter(cutoff));
    _failedLookupTimestampsByUser[callerUserId] = failures;

    if (failures.length >= PairingRelay.maxFailedLookupsPerUserPerHour) {
      throw StateError(
        'Too many failed code lookups. Please try again later.',
      );
    }

    final record = _codes[code];
    if (record == null ||
        record.status != 'open' ||
        record.isExpiredAt(now)) {
      failures.add(now);
      return null;
    }

    return PairingCodeLookupResult(
      homeName: record.homeName ?? 'The Nest',
      inviterName: record.inviterName ?? 'Partner',
      status: record.status,
    );
  }

  @override
  Future<PairingRequestRecord> submitJoinRequest({
    required String code,
    required String joinerId,
    required String joinerName,
    required String joinerPublicKey,
  }) async {
    final now = clock.now().toUtc();
    final cutoff = now.subtract(const Duration(hours: 1));

    // 1. Check per-user hourly request rate limit (max 5 requests per hour)
    final userHistory = (_requestTimestampsByUser[joinerId] ?? <DateTime>[])
      ..removeWhere((t) => !t.isAfter(cutoff));
    _requestTimestampsByUser[joinerId] = userHistory;
    if (userHistory.length >= PairingRelay.maxRequestsPerUserPerHour) {
      throw StateError(
        'Too many pairing requests. You can make at most 5 requests per hour.',
      );
    }

    // 2. Check code via lookupPairingCode (also enforces failed lookup rate limit)
    final codeRow = _codes[code];
    if (codeRow != null && codeRow.isExpiredAt(now)) {
      final failures =
          (_failedLookupTimestampsByUser[joinerId] ?? <DateTime>[])
            ..removeWhere((t) => !t.isAfter(cutoff));
      if (failures.length >= PairingRelay.maxFailedLookupsPerUserPerHour) {
        throw StateError(
          'Too many failed code lookups. Please try again later.',
        );
      }
      failures.add(now);
      _failedLookupTimestampsByUser[joinerId] = failures;
      throw StateError(
        'Pairing code has expired. Please request a new code.',
      );
    }
    if (codeRow != null && codeRow.status != 'open') {
      final failures =
          (_failedLookupTimestampsByUser[joinerId] ?? <DateTime>[])
            ..removeWhere((t) => !t.isAfter(cutoff));
      if (failures.length >= PairingRelay.maxFailedLookupsPerUserPerHour) {
        throw StateError(
          'Too many failed code lookups. Please try again later.',
        );
      }
      failures.add(now);
      _failedLookupTimestampsByUser[joinerId] = failures;
      throw StateError(
        'This pairing code has already been used. Ask for a new code.',
      );
    }

    final lookup = await lookupPairingCode(
      code: code,
      callerUserId: joinerId,
    );
    if (lookup == null) {
      throw StateError(
        'Invalid or expired 6-digit code. Please check your partner\'s screen.',
      );
    }

    // 3. Check per-code max 3 requests
    final existingForCode =
        _requests.values.where((r) => r.code == code).length;
    if (existingForCode >= PairingRelay.maxRequestsPerCode) {
      throw StateError(
        'Too many join requests for this code. Please ask for a new code.',
      );
    }

    userHistory.add(now);

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

  /// Simulates the SQL `BEFORE UPDATE ON public.pairing_requests` trigger
  /// and RLS update policy.
  Future<void> updateRequestWithTriggerChecks({
    required String requestId,
    required String actorUserId,
    String? newCode,
    String? newJoinerId,
    String? newJoinerPublicKey,
    String? newSealedPayload,
    bool clearSealedPayload = false,
    String? newStatus,
  }) async {
    final existing = _requests[requestId];
    if (existing == null) {
      throw StateError('Pairing request not found: $requestId');
    }
    final codeRow = _codes[existing.code];
    final inviterId = codeRow?.inviterId;

    final isJoiner = actorUserId == existing.joinerId;
    final isInviter = inviterId != null && actorUserId == inviterId;
    if (!isJoiner && !isInviter) {
      throw StateError('RLS violation: user cannot update this request.');
    }

    // Trigger check 1: code, joiner_id, and joiner_public_key are immutable
    if (newCode != null && newCode != existing.code) {
      throw StateError('Trigger violation: code is immutable after insert.');
    }
    if (newJoinerId != null && newJoinerId != existing.joinerId) {
      throw StateError(
        'Trigger violation: joiner_id is immutable after insert.',
      );
    }
    if (newJoinerPublicKey != null &&
        newJoinerPublicKey != existing.joinerPublicKey) {
      throw StateError(
        'Trigger violation: joiner_public_key is immutable after insert.',
      );
    }

    final targetStatus = newStatus ?? existing.status;
    final targetSealed = clearSealedPayload
        ? null
        : (newSealedPayload ?? existing.sealedPayload);

    // Trigger check 2: role-restricted transitions
    if (isJoiner && !isInviter) {
      if (targetStatus != 'done') {
        throw StateError(
          'Trigger violation: joiner may only change status to done.',
        );
      }
      if (targetSealed != existing.sealedPayload) {
        throw StateError(
          'Trigger violation: only the inviter may set sealed_payload.',
        );
      }
    } else if (isInviter) {
      if (targetStatus != 'approved' && targetStatus != 'declined') {
        throw StateError(
          'Trigger violation: inviter may only set status to approved or declined.',
        );
      }
      if (targetStatus == 'approved' &&
          (targetSealed == null || targetSealed.isEmpty)) {
        throw StateError(
          'Trigger violation: approved request requires sealed_payload.',
        );
      }
      if (targetStatus == 'declined' && targetSealed != null) {
        throw StateError(
          'Trigger violation: declined request cannot carry sealed_payload.',
        );
      }
    }

    final updated = existing.copyWith(
      sealedPayload: targetSealed,
      clearSealedPayload: targetSealed == null,
      status: targetStatus,
    );
    _requests[requestId] = updated;
    _recordWrite('pairing_requests', 'update', {
      'id': requestId,
      'sealed_payload': updated.sealedPayload,
      'status': updated.status,
    });
  }

  /// Enforces the `DELETE` RLS policy on `pairing_requests`:
  /// only the joiner or the code's inviter may delete a request, never anyone else.
  Future<void> deleteRequest({
    required String requestId,
    required String actorUserId,
  }) async {
    final existing = _requests[requestId];
    if (existing == null) return;
    final inviterId = _codes[existing.code]?.inviterId;
    if (actorUserId != existing.joinerId && actorUserId != inviterId) {
      throw StateError(
        'RLS violation: only the joiner or the code\'s inviter may delete a pairing request.',
      );
    }
    _requests.remove(requestId);
    _recordWrite('pairing_requests', 'delete', {'id': requestId});
  }

  /// Enforces the `DELETE` RLS policy on `pairing_codes`:
  /// only the code's inviter may delete their pairing code.
  Future<void> deletePairingCode({
    required String code,
    required String actorUserId,
  }) async {
    final existing = _codes[code];
    if (existing == null) return;
    if (actorUserId != existing.inviterId) {
      throw StateError(
        'RLS violation: only the code\'s inviter may delete a pairing code.',
      );
    }
    _codes.remove(code);
    _recordWrite('pairing_codes', 'delete', {'code': code});
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
    String? actorUserId,
  }) async {
    final codeRow = _codes[code];
    if (codeRow == null || codeRow.status != 'open') {
      throw StateError('Pairing code $code is no longer open.');
    }
    final effectiveActor = actorUserId ?? codeRow.inviterId;
    await updateRequestWithTriggerChecks(
      requestId: requestId,
      actorUserId: effectiveActor,
      newSealedPayload: sealedPayload,
      newStatus: 'approved',
    );

    final updatedCode = codeRow.copyWith(status: 'approved');
    _codes[code] = updatedCode;
    _recordWrite('pairing_codes', 'approve', {
      'code': code,
      'status': 'approved',
    });
  }

  @override
  Future<void> declineRequest({
    required String requestId,
    String? actorUserId,
  }) async {
    final req = _requests[requestId];
    if (req == null) return;
    final inviterId = _codes[req.code]?.inviterId;
    final effectiveActor = actorUserId ?? inviterId ?? '';
    await updateRequestWithTriggerChecks(
      requestId: requestId,
      actorUserId: effectiveActor,
      clearSealedPayload: true,
      newStatus: 'declined',
    );
  }

  @override
  Future<void> markRequestDone({
    required String requestId,
    String? actorUserId,
  }) async {
    final req = _requests[requestId];
    if (req == null) return;
    final effectiveActor = actorUserId ?? req.joinerId;
    await updateRequestWithTriggerChecks(
      requestId: requestId,
      actorUserId: effectiveActor,
      newStatus: 'done',
    );
  }

  @override
  Future<void> cleanupDoneAndExpired({
    required DateTime nowUtc,
    String? actorUserId,
  }) async {
    final doneRequests = _requests.values
        .where((r) => r.status == 'done' || r.status == 'declined')
        .toList();
    for (final req in doneRequests) {
      final inviterId = _codes[req.code]?.inviterId;
      if (actorUserId == null ||
          actorUserId == req.joinerId ||
          actorUserId == inviterId) {
        _requests.remove(req.id);
      }
    }

    final expiredCodes = _codes.values
        .where((c) => c.isExpiredAt(nowUtc) || c.status == 'approved')
        .toList();
    for (final codeRow in expiredCodes) {
      if (actorUserId != null && actorUserId != codeRow.inviterId) {
        continue;
      }
      final hasPendingOrApproved = _requests.values.any(
        (r) =>
            r.code == codeRow.code &&
            (r.status == 'pending' || r.status == 'approved'),
      );
      if (!hasPendingOrApproved) {
        _codes.remove(codeRow.code);
      }
    }
  }
}

final pairingRelayProvider = Provider<PairingRelay?>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  if (supabase == null) return null;
  return SupabasePairingRelay(supabase);
});
