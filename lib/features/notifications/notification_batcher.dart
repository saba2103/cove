import 'dart:convert';

import 'notification_copy.dart';
import 'notification_models.dart';

/// How the phone should act on a [NotificationCopy] offered to [NotificationBatcher]
/// (`design/specs/15-notifications.md` §5).
enum BatchDecisionKind {
  /// Show a brand-new notification card with [BatchDecision.id].
  showNew,

  /// Replace the existing notification card at [BatchDecision.id] with the
  /// combined summary body (`Ancy made two changes`) and InboxStyle [BatchDecision.lines].
  replace,

  /// A removal (`list_item_deleted`) riding along into an already-open batch,
  /// replacing the card at [BatchDecision.id] with the updated count and lines.
  rideAlong,

  /// Drop the event silently (e.g. a removal when no batch is open for that list).
  drop,
}

/// The pure data decision returned by [NotificationBatcher.offer].
class BatchDecision {
  final BatchDecisionKind kind;

  /// Notification ID for the card. Non-null for [BatchDecisionKind.showNew],
  /// [BatchDecisionKind.replace], and [BatchDecisionKind.rideAlong]; `null` for
  /// [BatchDecisionKind.drop].
  final int? id;

  /// Optional notification tag (`batchKey` for list notifications, `null` otherwise).
  final String? tag;

  /// The list ID when this decision belongs to a list batch; `null` otherwise.
  final String? batchKey;

  /// Module group key for Android notification stacking (§6).
  final NotificationModule groupKey;

  /// Notification title (the list name or section title).
  final String title;

  /// Notification body (`Ancy added ...` for a single change, or
  /// `Ancy made two changes` for a multi-change batch).
  final String body;

  /// Ordered InboxStyle lines (`+ item`, `✓ item`, `− item`), oldest first.
  /// Empty for a single-change plain card ([BatchDecisionKind.showNew]).
  final List<String> lines;

  /// Replacements (`replace` and `rideAlong`) must not buzz again (§5 `onlyAlertOnce`).
  final bool onlyAlertOnce;

  const BatchDecision({
    required this.kind,
    required this.id,
    required this.groupKey,
    required this.title,
    required this.body,
    this.tag,
    this.batchKey,
    this.lines = const <String>[],
    this.onlyAlertOnce = false,
  });

  const BatchDecision.drop({
    this.batchKey,
    this.groupKey = NotificationModule.lists,
  })  : kind = BatchDecisionKind.drop,
        id = null,
        tag = batchKey,
        title = '',
        body = '',
        lines = const <String>[],
        onlyAlertOnce = false;

  bool get isShowNew => kind == BatchDecisionKind.showNew;
  bool get isReplace =>
      kind == BatchDecisionKind.replace || kind == BatchDecisionKind.rideAlong;
  bool get isRideAlong => kind == BatchDecisionKind.rideAlong;
  bool get isDrop => kind == BatchDecisionKind.drop;
  bool get shouldShow => kind != BatchDecisionKind.drop;
  bool get isPlainCard => isShowNew && lines.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchDecision &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          id == other.id &&
          tag == other.tag &&
          batchKey == other.batchKey &&
          groupKey == other.groupKey &&
          title == other.title &&
          body == other.body &&
          onlyAlertOnce == other.onlyAlertOnce &&
          _listEquals(lines, other.lines);

  @override
  int get hashCode => Object.hash(
        kind,
        id,
        tag,
        batchKey,
        groupKey,
        title,
        body,
        onlyAlertOnce,
        Object.hashAll(lines),
      );

  @override
  String toString() =>
      'BatchDecision(kind: ${kind.name}, id: $id, batchKey: $batchKey, '
      'title: "$title", body: "$body", lines: $lines, onlyAlertOnce: $onlyAlertOnce)';
}

class _OpenListBatch {
  final String listId;
  final int notificationId;
  String title;
  String partnerName;
  final NotificationModule groupKey;
  final DateTime firstChangeAt;
  final List<String> lines;

  _OpenListBatch({
    required this.listId,
    required this.notificationId,
    required this.title,
    required this.partnerName,
    required this.groupKey,
    required this.firstChangeAt,
    required List<String> lines,
  }) : lines = List<String>.from(lines);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'list_id': listId,
        'notification_id': notificationId,
        'title': title,
        'partner_name': partnerName,
        'group_key': groupKey.name,
        'first_change_at': firstChangeAt.toIso8601String(),
        'lines': List<String>.from(lines),
      };

  factory _OpenListBatch.fromJson(Map<String, dynamic> json) {
    final rawLines = (json['lines'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList();
    return _OpenListBatch(
      listId: (json['list_id'] as String?) ?? '',
      notificationId: (json['notification_id'] as num?)?.toInt() ?? 1,
      title: (json['title'] as String?) ?? 'Shared lists',
      partnerName: (json['partner_name'] as String?) ?? 'Partner',
      groupKey: NotificationModule.fromString(
        (json['group_key'] as String?) ?? 'lists',
        fallback: NotificationModule.lists,
      ),
      firstChangeAt: DateTime.parse(json['first_change_at'] as String),
      lines: rawLines,
    );
  }
}

/// Pure 90-second per-list notification batching state machine
/// (`design/specs/15-notifications.md` §5).
///
/// Contains zero Flutter or plugin dependencies and serializes to/from a small
/// JSON blob ([toJson] / [NotificationBatcher.fromJson]) so its state survives
/// across fresh background isolates via local preferences.
class NotificationBatcher {
  /// Preferences key used to persist the serialized batcher JSON blob.
  static const String preferencesKey = 'cove_notification_batcher_state_v1';

  /// The 90-second batching window measured from the batch's first change (§5).
  static const Duration window = Duration(seconds: 90);

  int _nextNotificationId;
  final Map<String, _OpenListBatch> _batches;

  NotificationBatcher({int initialNextId = 1})
      : _nextNotificationId = initialNextId < 1 ? 1 : initialNextId,
        _batches = <String, _OpenListBatch>{};

  NotificationBatcher._({
    required int nextNotificationId,
    required this._batches,
  }) : _nextNotificationId = nextNotificationId < 1 ? 1 : nextNotificationId;

  /// Offers [copy] at timestamp [now] and returns the resulting [BatchDecision].
  BatchDecision offer(NotificationCopy copy, DateTime now) {
    final listId = copy.batchKey;

    // Non-list events never batch: each event is its own plain card.
    if (listId == null || listId.isEmpty) {
      if (!copy.canStartCard) {
        return BatchDecision.drop(groupKey: copy.groupKey);
      }
      final id = _allocateId();
      return BatchDecision(
        kind: BatchDecisionKind.showNew,
        id: id,
        tag: null,
        batchKey: null,
        groupKey: copy.groupKey,
        title: copy.title,
        body: copy.body,
        lines: const <String>[],
        onlyAlertOnce: false,
      );
    }

    // Expire the existing batch for this list if the 90s window has elapsed.
    final existing = _batches[listId];
    final bool hasOpenWindow = existing != null &&
        !now.isBefore(existing.firstChangeAt) &&
        now.difference(existing.firstChangeAt) <= window;

    if (!hasOpenWindow) {
      _batches.remove(listId);

      // §3 & §5: A removal never starts a card. With no open batch, drop it.
      if (!copy.canStartCard) {
        return BatchDecision.drop(
          batchKey: listId,
          groupKey: copy.groupKey,
        );
      }

      final id = _allocateId();
      final partner = _resolvePartnerName(copy, fallback: 'Partner');
      final initialLine = copy.batchLine;
      _batches[listId] = _OpenListBatch(
        listId: listId,
        notificationId: id,
        title: copy.title,
        partnerName: partner,
        groupKey: copy.groupKey,
        firstChangeAt: now,
        lines: initialLine != null && initialLine.isNotEmpty
            ? <String>[initialLine]
            : <String>[],
      );

      // A single change is a plain card (§2 & §5).
      return BatchDecision(
        kind: BatchDecisionKind.showNew,
        id: id,
        tag: listId,
        batchKey: listId,
        groupKey: copy.groupKey,
        title: copy.title,
        body: copy.body,
        lines: const <String>[],
        onlyAlertOnce: false,
      );
    }

    // Inside the 90s window of an open batch for `listId`:
    final batch = existing;
    if (copy.title.trim().isNotEmpty) {
      batch.title = copy.title;
    }
    final resolvedPartner =
        _resolvePartnerName(copy, fallback: batch.partnerName);
    if (resolvedPartner.isNotEmpty) {
      batch.partnerName = resolvedPartner;
    }
    if (copy.batchLine != null && copy.batchLine!.isNotEmpty) {
      batch.lines.add(copy.batchLine!);
    }

    final countWord = formatCountWordUpToTen(batch.lines.length);
    final summaryBody = '${batch.partnerName} made $countWord changes';
    final decisionKind = copy.canStartCard
        ? BatchDecisionKind.replace
        : BatchDecisionKind.rideAlong;

    return BatchDecision(
      kind: decisionKind,
      id: batch.notificationId,
      tag: listId,
      batchKey: listId,
      groupKey: batch.groupKey,
      title: batch.title,
      body: summaryBody,
      lines: List<String>.unmodifiable(batch.lines),
      onlyAlertOnce: true,
    );
  }

  /// Closes the open batch for [listId] (e.g. when the user opens that list in
  /// the app, §5).
  ///
  /// Returns the notification ID of the closed batch if one was open so the
  /// caller can cancel its active card, or `null` if no batch was open.
  int? closeBatch(String listId) {
    final removed = _batches.remove(listId);
    return removed?.notificationId;
  }

  /// Returns the active notification ID for [listId] if a batch is currently
  /// stored, or `null` otherwise.
  int? activeNotificationIdForList(String listId) =>
      _batches[listId]?.notificationId;

  /// Serializes the batcher state to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'next_id': _nextNotificationId,
      'batches': _batches.map(
        (key, value) => MapEntry<String, dynamic>(key, value.toJson()),
      ),
    };
  }

  /// Serializes the batcher state to a compact JSON string for local preferences.
  String toJsonString() => jsonEncode(toJson());

  /// Reconstructs [NotificationBatcher] from a JSON map produced by [toJson].
  factory NotificationBatcher.fromJson(Map<String, dynamic> json) {
    final nextId = (json['next_id'] as num?)?.toInt() ?? 1;
    final rawBatches = json['batches'];
    final parsedBatches = <String, _OpenListBatch>{};

    if (rawBatches is Map) {
      for (final entry in rawBatches.entries) {
        final key = entry.key.toString();
        final val = entry.value;
        if (val is Map<String, dynamic>) {
          parsedBatches[key] = _OpenListBatch.fromJson(val);
        } else if (val is Map) {
          parsedBatches[key] = _OpenListBatch.fromJson(
            val.map((k, v) => MapEntry(k.toString(), v)),
          );
        }
      }
    }

    return NotificationBatcher._(
      nextNotificationId: nextId,
      batches: parsedBatches,
    );
  }

  /// Reconstructs [NotificationBatcher] from a JSON string stored in local
  /// preferences, returning a fresh batcher if [rawJson] is null, empty, or malformed.
  factory NotificationBatcher.fromJsonString(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) {
      return NotificationBatcher();
    }
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        return NotificationBatcher.fromJson(decoded);
      }
      if (decoded is Map) {
        return NotificationBatcher.fromJson(
          decoded.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    } catch (_) {}
    return NotificationBatcher();
  }

  int _allocateId() {
    final id = _nextNotificationId;
    _nextNotificationId += 1;
    return id;
  }

  static String _resolvePartnerName(
    NotificationCopy copy, {
    required String fallback,
  }) {
    if (copy.partnerName.trim().isNotEmpty) {
      return copy.partnerName.trim();
    }
    final body = copy.body.trim();
    for (final marker in const <String>[
      ' added ',
      ' ticked off ',
      ' started a new list ',
      ' logged ',
      ' kept it',
      ' put it in for ',
      ' moved it to ',
      ' cancelled it ',
      ' paused ',
      ' joined.',
    ]) {
      final idx = body.indexOf(marker);
      if (idx > 0) {
        return body.substring(0, idx).trim();
      }
    }
    return fallback;
  }
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
