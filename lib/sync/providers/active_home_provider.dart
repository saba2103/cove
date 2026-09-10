import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import 'cove_sync_providers.dart';

class ActiveHomeNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setActiveHome(String homeId) {
    state = homeId;
  }
}

/// Holds the currently selected active Home ID.
/// All feature-module queries and emissions are scoped to this Home.
final activeHomeIdProvider =
    NotifierProvider<ActiveHomeNotifier, String?>(ActiveHomeNotifier.new);

/// Streams the list of all Homes the user belongs to from the local database.
final userHomesProvider = StreamProvider<List<LocalHome>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchHomes();
});

/// Streams the currently active Home object.
final activeHomeProvider = StreamProvider<LocalHome?>((ref) {
  final activeId = ref.watch(activeHomeIdProvider);
  if (activeId == null) return Stream.value(null);

  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.localHomes)
        ..where((t) => t.id.equals(activeId)))
      .watchSingleOrNull();
});
