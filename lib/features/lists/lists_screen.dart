import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_checkbox.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../core/widgets/cove_tab_row.dart';

class ListsScreen extends ConsumerStatefulWidget {
  const ListsScreen({super.key});

  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen> {
  int _tabIndex = 0;
  bool _item1 = false;
  bool _item2 = true;
  bool _item3 = false;
  final TextEditingController _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Tab Row
        CoveTabRow(
          tabs: const ['Groceries', 'Home Supplies', 'Packing', 'Wishlist'],
          selectedIndex: _tabIndex,
          onTabSelected: (i) => setState(() => _tabIndex = i),
        ),
        const SizedBox(height: 16),

        // Grouped Items Card
        CoveGroupedCard(
          children: [
            CoveChecklistRow(
              value: _item1,
              onChanged: (v) => setState(() => _item1 = v),
              title: 'Oat milk (unsweetened)',
              subtitle: 'Added by Sarah',
              trailing: const CoveSyncTick(status: CoveSyncStatus.syncedToPartner),
            ),
            CoveChecklistRow(
              value: _item2,
              onChanged: (v) => setState(() => _item2 = v),
              title: 'Sourdough bread',
              subtitle: 'Added by Alex',
              trailing: const CoveSyncTick(status: CoveSyncStatus.syncedToPartner),
            ),
            CoveChecklistRow(
              value: _item3,
              onChanged: (v) => setState(() => _item3 = v),
              title: 'Fresh rosemary & garlic',
              subtitle: 'Saved just now',
              trailing: const CoveSyncTick(status: CoveSyncStatus.savedLocally),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Quick Add Pill Input
        CovePillInput(
          controller: _inputController,
          hintText: 'Add an item to ${_tabIndex == 0 ? "Groceries" : "List"}…',
          prefixIcon: Icon(Icons.add, size: 18, color: colors.textMuted),
          suffix: Icon(Icons.arrow_upward_rounded, size: 18, color: colors.accentPrimary),
        ),
      ],
    );
  }
}
