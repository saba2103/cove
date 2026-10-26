import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_avatar.dart';
import '../../core/widgets/cove_checkbox.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/user_profile_controller.dart';

/// Choice metadata for a list selectable in The Slip widget configuration
/// (`design/specs/18-widgets.md` §2).
@immutable
class SlipListChoiceOption {
  final String id;
  final String name;
  final int openCount;
  final int totalCount;
  final bool isMostUsed;

  const SlipListChoiceOption({
    required this.id,
    required this.name,
    required this.openCount,
    required this.totalCount,
    required this.isMostUsed,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'openCount': openCount,
        'totalCount': totalCount,
        'isMostUsed': isMostUsed,
      };

  factory SlipListChoiceOption.fromJson(Map<String, dynamic> map) {
    return SlipListChoiceOption(
      id: map['id'] as String,
      name: map['name'] as String,
      openCount: (map['openCount'] as num?)?.toInt() ?? 0,
      totalCount: (map['totalCount'] as num?)?.toInt() ?? 0,
      isMostUsed: map['isMostUsed'] as bool? ?? false,
    );
  }
}

/// One open item row rendered on The Slip (`design/specs/18-widgets.md` §2).
@immutable
class SlipItemRow {
  final String id;
  final String title;
  final String createdBy;
  final CovePerson person;
  final String actorInitial;
  final bool isTicked;

  const SlipItemRow({
    required this.id,
    required this.title,
    required this.createdBy,
    required this.person,
    required this.actorInitial,
    this.isTicked = false,
  });

  SlipItemRow copyWith({
    bool? isTicked,
  }) {
    return SlipItemRow(
      id: id,
      title: title,
      createdBy: createdBy,
      person: person,
      actorInitial: actorInitial,
      isTicked: isTicked ?? this.isTicked,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'createdBy': createdBy,
        'person': person.name,
        'actorInitial': actorInitial,
        'isTicked': isTicked,
      };

  factory SlipItemRow.fromJson(Map<String, dynamic> map) {
    final personName = map['person'] as String? ?? 'a';
    final person = CovePerson.values.firstWhere(
      (p) => p.name == personName,
      orElse: () => CovePerson.a,
    );
    return SlipItemRow(
      id: map['id'] as String,
      title: map['title'] as String,
      createdBy: map['createdBy'] as String? ?? '',
      person: person,
      actorInitial: map['actorInitial'] as String? ?? 'A',
      isTicked: map['isTicked'] as bool? ?? false,
    );
  }
}

/// Pre-computed summary for The Slip widget (`design/specs/18-widgets.md` §2).
@immutable
class SlipSummary {
  static const int maxRowsFull4Cell = 3;
  static const int maxRowsCompact3Cell = 2;

  final String? listId;
  final String listName;
  final int openCount;
  final List<SlipItemRow> openItems;
  final List<SlipListChoiceOption> availableLists;

  const SlipSummary({
    required this.listId,
    required this.listName,
    required this.openCount,
    required this.openItems,
    this.availableLists = const [],
  });

  bool get isEmpty => openItems.isEmpty;

  String get openBadgeLabel => '$openCount OPEN';

  String get emptyStateLabel => '$listName is empty';

  List<SlipItemRow> visibleRowsFor({bool isCompact3Cell = false}) {
    final limit = isCompact3Cell ? maxRowsCompact3Cell : maxRowsFull4Cell;
    if (openItems.length <= limit) return openItems;
    return openItems.sublist(0, limit);
  }

  int remainingCountFor({bool isCompact3Cell = false}) {
    final visible = visibleRowsFor(isCompact3Cell: isCompact3Cell).length;
    final rem = openCount - visible;
    return rem > 0 ? rem : 0;
  }

  String footerLabelFor({bool isCompact3Cell = false}) {
    final rem = remainingCountFor(isCompact3Cell: isCompact3Cell);
    if (rem > 0) {
      return '+$rem more · tap to tick';
    }
    return 'tap to tick';
  }

  /// Returns a new [SlipSummary] reflecting an optimistic tick on [recordId]
  /// (`design/specs/18-widgets.md` § Ticking rule 1: "The widget re-renders
  /// straight away with the tick shown.").
  SlipSummary withOptimisticTick(
    String recordId, {
    bool toDone = true,
  }) {
    var changed = false;
    final updated = openItems.map((row) {
      if (row.id == recordId && row.isTicked != toDone) {
        changed = true;
        return row.copyWith(isTicked: toDone);
      }
      return row;
    }).toList(growable: false);
    if (!changed) return this;
    final untickedOpenCount = updated.where((r) => !r.isTicked).length;
    return SlipSummary(
      listId: listId,
      listName: listName,
      openCount: untickedOpenCount,
      openItems: updated,
      availableLists: availableLists,
    );
  }

  /// Selects the most-used non-archived list (highest total item count in
  /// [allItems], tie-broken by open item count and then earlier `createdAt`).
  static LocalList? selectMostUsedList(
    List<LocalList> lists,
    List<LocalListItem> allItems,
  ) {
    final activeLists = lists.where((l) => !l.isArchived).toList();
    if (activeLists.isEmpty) return null;

    final totalByList = <String, int>{};
    final openByList = <String, int>{};
    for (final item in allItems) {
      totalByList[item.listId] = (totalByList[item.listId] ?? 0) + 1;
      if (!item.isCompleted) {
        openByList[item.listId] = (openByList[item.listId] ?? 0) + 1;
      }
    }

    activeLists.sort((a, b) {
      final totalA = totalByList[a.id] ?? 0;
      final totalB = totalByList[b.id] ?? 0;
      if (totalA != totalB) return totalB.compareTo(totalA);

      final openA = openByList[a.id] ?? 0;
      final openB = openByList[b.id] ?? 0;
      if (openA != openB) return openB.compareTo(openA);

      return a.createdAt.compareTo(b.createdAt);
    });

    return activeLists.first;
  }

  static SlipSummary compute({
    required List<LocalList> lists,
    required List<LocalListItem> allItems,
    String? selectedListId,
    required String homeCreatedBy,
    required String currentUserId,
    required String myName,
    required String partnerName,
    Set<String> pendingTickedItemIds = const {},
  }) {
    final activeLists = lists.where((l) => !l.isArchived).toList();
    final mostUsed = selectMostUsedList(activeLists, allItems);

    final totalByList = <String, int>{};
    final openByList = <String, int>{};
    for (final item in allItems) {
      totalByList[item.listId] = (totalByList[item.listId] ?? 0) + 1;
      if (!item.isCompleted) {
        openByList[item.listId] = (openByList[item.listId] ?? 0) + 1;
      }
    }

    final options = activeLists
        .map(
          (l) => SlipListChoiceOption(
            id: l.id,
            name: l.name,
            openCount: openByList[l.id] ?? 0,
            totalCount: totalByList[l.id] ?? 0,
            isMostUsed: mostUsed != null && l.id == mostUsed.id,
          ),
        )
        .toList(growable: false);

    LocalList? chosenList;
    if (selectedListId != null && selectedListId.isNotEmpty) {
      for (final l in activeLists) {
        if (l.id == selectedListId) {
          chosenList = l;
          break;
        }
      }
    }
    chosenList ??= mostUsed;

    if (chosenList == null) {
      return const SlipSummary(
        listId: null,
        listName: 'Groceries',
        openCount: 0,
        openItems: [],
        availableLists: [],
      );
    }

    final targetListId = chosenList.id;
    final listOpenItems = allItems
        .where((i) => i.listId == targetListId && !i.isCompleted)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final rows = listOpenItems.map((item) {
      final person = CoveAvatar.resolvePerson(
        homeCreatedBy: homeCreatedBy,
        actorUserId: item.createdBy,
      );
      final isViewer = item.createdBy == currentUserId;
      final rawName = isViewer ? myName : partnerName;
      final fallbackInitial = person == CovePerson.a ? 'A' : 'S';
      final initial = _extractInitial(rawName, fallback: fallbackInitial);
      return SlipItemRow(
        id: item.id,
        title: item.title,
        createdBy: item.createdBy,
        person: person,
        actorInitial: initial,
        isTicked: pendingTickedItemIds.contains(item.id),
      );
    }).toList(growable: false);

    final untickedCount = rows.where((r) => !r.isTicked).length;

    return SlipSummary(
      listId: chosenList.id,
      listName: chosenList.name,
      openCount: untickedCount,
      openItems: rows,
      availableLists: options,
    );
  }

  static String _extractInitial(String name, {required String fallback}) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty &&
        trimmed.toLowerCase() != 'you' &&
        trimmed.toLowerCase() != 'partner') {
      final match = RegExp(r'[A-Za-z]').firstMatch(trimmed);
      if (match != null) {
        return match.group(0)!.toUpperCase();
      }
    }
    return fallback;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'listId': listId,
        'listName': listName,
        'openCount': openCount,
        'openItems': openItems.map((r) => r.toJson()).toList(),
        'availableLists': availableLists.map((o) => o.toJson()).toList(),
      };

  factory SlipSummary.fromJson(Map<String, dynamic> map) {
    final rawItems = map['openItems'] as List<dynamic>? ?? const [];
    final rawOptions = map['availableLists'] as List<dynamic>? ?? const [];
    return SlipSummary(
      listId: map['listId'] as String?,
      listName: map['listName'] as String? ?? 'Groceries',
      openCount: (map['openCount'] as num?)?.toInt() ?? 0,
      openItems: rawItems
          .whereType<Map<String, dynamic>>()
          .map(SlipItemRow.fromJson)
          .toList(growable: false),
      availableLists: rawOptions
          .whereType<Map<String, dynamic>>()
          .map(SlipListChoiceOption.fromJson)
          .toList(growable: false),
    );
  }
}

/// Persists the user's chosen list ID for The Slip widget (`null` means
/// default to the most-used list).
class SlipSelectedListIdNotifier extends Notifier<String?> {
  static const String prefKey = 'cove_widget_slip_selected_list_id';
  static String? cachedInitialListId;

  @override
  String? build() {
    _loadFromPrefs();
    return cachedInitialListId;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefKey);
      if (saved != null && saved.isNotEmpty && state == null) {
        cachedInitialListId = saved;
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> selectList(String? listId) async {
    final normalized = (listId != null && listId.trim().isNotEmpty)
        ? listId.trim()
        : null;
    cachedInitialListId = normalized;
    state = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (normalized == null) {
        await prefs.remove(prefKey);
      } else {
        await prefs.setString(prefKey, normalized);
      }
    } catch (_) {}
  }
}

final slipSelectedListIdProvider =
    NotifierProvider<SlipSelectedListIdNotifier, String?>(
  SlipSelectedListIdNotifier.new,
);

/// Reactive provider computing [SlipSummary] from the active home's lists,
/// items, and selected list preference (`design/specs/18-widgets.md` §2).
final slipSummaryProvider = Provider<SlipSummary>((ref) {
  final lists = ref.watch(activeHomeListsProvider).value ?? const [];
  final allItems = ref.watch(activeHomeAllListItemsProvider).value ?? const [];
  final selectedListId = ref.watch(slipSelectedListIdProvider);
  final home = ref.watch(activeHomeProvider).value;
  final currentUser = ref.watch(authProvider).value;
  final userProfile = ref.watch(userProfileProvider);
  final partnerProfile = ref.watch(partnerProfileProvider);

  final currentUserId = currentUser?.id ?? 'user_alex';
  final homeCreatedBy = home?.createdBy ?? currentUserId;

  return SlipSummary.compute(
    lists: lists,
    allItems: allItems,
    selectedListId: selectedListId,
    homeCreatedBy: homeCreatedBy,
    currentUserId: currentUserId,
    myName: userProfile.displayName,
    partnerName: partnerProfile.displayName,
  );
});

/// Home-screen Slip widget (4×2, resizable to 3×2) per `design/specs/18-widgets.md` §2
/// and `design/screens/widgets/slip-{dark,light}.png`.
class CoveSlipWidget extends ConsumerWidget {
  final ValueChanged<String?>? onTapOpenList;
  final ValueChanged<String>? onTickItem;

  const CoveSlipWidget({
    super.key,
    this.onTapOpenList,
    this.onTickItem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(slipSummaryProvider);
    return CoveSlipCard(
      summary: summary,
      onTapOpenList: onTapOpenList,
      onTickItem: onTickItem,
    );
  }
}

/// Pure presentation card for The Slip (`design/specs/18-widgets.md` §2).
///
/// At 4-cell width (`>= 240dp`), shows up to three open rows.
/// At 3-cell width (`< 240dp`), shows up to two open rows without scaling text
/// down below the type scale.
class CoveSlipCard extends StatelessWidget {
  static const double _kCardFillOpacity =
      0.88; // (literal) ~88% card fill over wallpaper
  static const double _kHairlineWidth =
      1.0; // (literal) 1dp card border & row divider
  static const double _kCompactThreeCellThreshold =
      240.0; // (literal) 3-cell width threshold
  static const double _kCheckboxSize =
      16.0; // (literal) 16dp widget row checkbox size
  static const double _kVerticalPaddingTop =
      14.0; // (literal) 14dp top padding for 4x2 widget height fit
  static const double _kVerticalPaddingBottom =
      10.0; // (literal) 10dp bottom padding for 4x2 widget height fit

  final SlipSummary summary;
  final ValueChanged<String?>? onTapOpenList;
  final ValueChanged<String>? onTickItem;

  const CoveSlipCard({
    super.key,
    required this.summary,
    this.onTapOpenList,
    this.onTickItem,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact3Cell = constraints.maxWidth.isFinite &&
            constraints.maxWidth > 0 &&
            constraints.maxWidth < _kCompactThreeCellThreshold;
        final visibleRows = summary.visibleRowsFor(
          isCompact3Cell: isCompact3Cell,
        );

        return DefaultTextStyle.merge(
          style: const TextStyle(decoration: TextDecoration.none),
          child: Container(
            padding: const EdgeInsets.only(
              left: CoveSpace.lg,
              right: CoveSpace.lg,
              top: _kVerticalPaddingTop,
              bottom: _kVerticalPaddingBottom,
            ),
            decoration: BoxDecoration(
              color: cv.surfaceCard.withValues(alpha: _kCardFillOpacity),
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.hero),
              ),
              border: Border.all(
                color: cv.lineStrong,
                width: _kHairlineWidth,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header: list name in display face, `{n} OPEN` caps on the right.
                GestureDetector(
                  key: const ValueKey('cove_slip_header'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onTapOpenList != null
                      ? () => onTapOpenList!(summary.listId)
                      : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          summary.listName,
                          style: CoveType.slipTitle.copyWith(
                            color: cv.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: CoveSpace.sm),
                      Text(
                        summary.openBadgeLabel,
                        style: CoveType.capsCard.copyWith(
                          color: cv.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),

                if (visibleRows.isEmpty) ...[
                  Expanded(
                    child: GestureDetector(
                      key: const ValueKey('cove_slip_empty'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onTapOpenList != null
                          ? () => onTapOpenList!(summary.listId)
                          : null,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          summary.emptyStateLabel,
                          style: CoveType.body.copyWith(
                            color: cv.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < visibleRows.length; i++) ...[
                          if (i > 0)
                            Container(
                              height: _kHairlineWidth,
                              color: cv.lineHairline,
                            ),
                          _buildItemRow(cv, visibleRows[i], index: i),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    key: const ValueKey('cove_slip_footer'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onTapOpenList != null
                        ? () => onTapOpenList!(summary.listId)
                        : null,
                    child: Text(
                      summary.footerLabelFor(isCompact3Cell: isCompact3Cell),
                      style: CoveType.rowSub.copyWith(
                        color: cv.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemRow(
    CoveTokens cv,
    SlipItemRow row, {
    required int index,
  }) {
    return GestureDetector(
      key: ValueKey('cove_slip_row_$index'),
      behavior: HitTestBehavior.opaque,
      onTap: onTickItem != null ? () => onTickItem!(row.id) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IgnorePointer(
            child: CoveCheckbox(
              size: _kCheckboxSize,
              value: row.isTicked,
              onChanged: (_) {},
            ),
          ),
          const SizedBox(width: CoveSpace.sm),
          Expanded(
            child: Text(
              row.title,
              style: CoveType.rowTitle.copyWith(
                color: row.isTicked ? cv.textTertiary : cv.textPrimary,
                decoration: row.isTicked
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: CoveSpace.xs),
          CoveAvatar.inline(
            person: row.person,
            nameOrInitial: row.actorInitial,
          ),
        ],
      ),
    );
  }
}

/// Sheet allowing the user to pick which list The Slip widget displays when
/// added or reconfigured, defaulting to the most-used list (`design/specs/18-widgets.md` §2).
class SlipListPickerSheet extends ConsumerWidget {
  const SlipListPickerSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const SlipListPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cv = context.cv;
    final summary = ref.watch(slipSummaryProvider);
    final selectedId = summary.listId;
    final options = summary.availableLists;

    return Container(
      padding: const EdgeInsets.all(CoveSpace.xl),
      decoration: BoxDecoration(
        color: cv.surfaceSheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(CoveRadius.sheet),
        ),
        border: Border(
          top: BorderSide(color: cv.lineStrong, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'THE SLIP · CHOOSE A LIST',
              style: CoveType.capsPage.copyWith(color: cv.textTertiary),
            ),
            const SizedBox(height: CoveSpace.xs),
            Text(
              'Which list sits on your home screen?',
              style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
            ),
            const SizedBox(height: CoveSpace.md),
            for (final option in options)
              InkWell(
                key: ValueKey('slip_list_option_${option.id}'),
                onTap: () async {
                  await ref
                      .read(slipSelectedListIdProvider.notifier)
                      .selectList(option.id);
                  if (context.mounted) {
                    Navigator.of(context).pop(option.id);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: CoveSpace.sm),
                  child: Row(
                    children: [
                      Icon(
                        option.id == selectedId
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: CoveSize.avatarInline,
                        color: option.id == selectedId
                            ? cv.accentText
                            : cv.textTertiary,
                      ),
                      const SizedBox(width: CoveSpace.sm),
                      Expanded(
                        child: Text(
                          option.name,
                          style: CoveType.rowTitle.copyWith(
                            color: cv.textPrimary,
                          ),
                        ),
                      ),
                      if (option.isMostUsed) ...[
                        Text(
                          'MOST USED',
                          style: CoveType.capsCard.copyWith(
                            color: cv.accentText,
                          ),
                        ),
                        const SizedBox(width: CoveSpace.sm),
                      ],
                      Text(
                        '${option.openCount} OPEN',
                        style: CoveType.capsCard.copyWith(
                          color: cv.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
