import 'dart:async';

/// Abstract contract for applying decrypted events to the local SQLite database
/// (Drift projections) which serves as the single source of truth for the UI.
abstract class LocalStateStore {
  /// Initializes the local database storage engine (Drift/SQLite).
  Future<void> initialize();

  /// Applies a decrypted event payload into the respective projected tables
  /// (e.g. lists, list_items, subscriptions, expenses, habits) scoped to homeId.
  Future<void> applyEvent({
    String? eventId,
    required String homeId,
    required String eventType,
    required Map<String, dynamic> payload,
    required DateTime timestamp,
    required String authorId,
  });

  /// Clears all local state data (e.g. on sign out or home change).
  Future<void> clearAll();

  /// Checks if an activity event has already been projected into the local database.
  Future<bool> hasEvent(String eventId);

  /// Closes database connections.
  Future<void> close();
}
