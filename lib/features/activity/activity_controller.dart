import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import 'activity_formatter.dart';
import 'activity_models.dart';

class ActivityModuleFilterNotifier extends Notifier<ActivityModule> {
  @override
  ActivityModule build() => ActivityModule.all;

  void setFilter(ActivityModule filter) => state = filter;
}

final activityModuleFilterProvider =
    NotifierProvider<ActivityModuleFilterNotifier, ActivityModule>(
        ActivityModuleFilterNotifier.new);

class ActivityPageLimitNotifier extends Notifier<int> {
  @override
  int build() => 25;

  void loadMore() => state += 25;
}

final activityPageLimitProvider =
    NotifierProvider<ActivityPageLimitNotifier, int>(
        ActivityPageLimitNotifier.new);

final activityFeedProvider =
    StreamProvider.autoDispose<List<FormattedActivityItem>>((ref) {
  final homeId = ref.watch(activeHomeIdProvider);
  if (homeId == null) return Stream.value([]);

  final db = ref.watch(appDatabaseProvider);
  final user = ref.watch(authProvider).value;
  final partnerName = ref.watch(partnerProfileProvider).displayName;
  final selectedFilter = ref.watch(activityModuleFilterProvider);
  final limit = ref.watch(activityPageLimitProvider);
  final currency = ref.watch(currencyPreferenceProvider);

  final eventTypeFilter = selectedFilter.eventTypes;

  return db
      .watchActivityEvents(
        homeId,
        currentUserId: user?.id,
        eventTypeFilter: eventTypeFilter,
        limit: limit,
      )
      .asyncMap((rows) async {
        final list = <FormattedActivityItem>[];
        for (final row in rows) {
          final item = await ActivityFormatter.formatWithDb(
            rawEvent: row,
            currentUserId: user?.id,
            partnerName: partnerName,
            preferredCurrencySymbol: currency.symbol,
            db: db,
          );
          list.add(item);
        }
        return list;
      });
});
