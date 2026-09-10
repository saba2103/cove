import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/cove_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/widgets.dart';
import 'features/app_shell.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_gate.dart';
import 'features/home/create_home_screen.dart';
import 'features/home/join_home_screen.dart';
import 'features/home/onboarding_choice_screen.dart';
import 'features/expenses/expenses_screen.dart';
import 'features/lists/lists_screen.dart';
import 'features/subscriptions/subscriptions_screen.dart';
import 'sync/db/app_database.dart';
import 'sync/providers/active_home_provider.dart';
import 'sync/providers/cove_sync_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: CoveApp(),
    ),
  );
}

class CoveApp extends ConsumerWidget {
  final Widget? homeOverride;

  const CoveApp({super.key, this.homeOverride});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final urlTheme = Uri.base.queryParameters['theme'];
    final effectiveTheme = urlTheme == 'light'
        ? ThemeMode.light
        : (urlTheme == 'dark' ? ThemeMode.dark : themeMode);

    final isShowcase = Uri.base.queryParameters['showcase'] == 'true';
    final preview = Uri.base.queryParameters['preview'];

    Widget resolveScreen() {
      if (homeOverride != null) return homeOverride!;
      if (isShowcase) return const ComponentShowcaseScreen();
      switch (preview) {
        case 'onboarding':
          return const OnboardingChoiceScreen();
        case 'create_home':
          return const CreateHomeScreen();
        case 'join_home':
          return const JoinHomeScreen(initialShowManualInput: true);
        case 'app_shell':
          return const AppShell();
        case 'subscriptions':
          return const _SubscriptionsPreviewScaffold();
        case 'lists':
          return const _ListsPreviewScaffold();
        case 'expenses':
          return const _ExpensesPreviewScaffold();
        default:
          return const AuthGate();
      }
    }

    return MaterialApp(
      title: 'Cove',
      debugShowCheckedModeBanner: false,
      theme: CoveTheme.lightTheme,
      darkTheme: CoveTheme.darkTheme,
      themeMode: effectiveTheme,
      home: resolveScreen(),
    );
  }
}

class ComponentShowcaseScreen extends ConsumerStatefulWidget {
  const ComponentShowcaseScreen({super.key});

  @override
  ConsumerState<ComponentShowcaseScreen> createState() =>
      _ComponentShowcaseScreenState();
}

class _ComponentShowcaseScreenState
    extends ConsumerState<ComponentShowcaseScreen> {
  int _selectedTab = 0;
  int _navIndex = 0;
  bool _item1Checked = false;
  bool _item2Checked = true;
  bool _notificationsEnabled = true;
  bool _backupEnabled = false;
  final TextEditingController _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cove',
          style: typography.headline.copyWith(fontSize: 22),
        ),
        actions: [
          Row(
            children: [
              Text(
                isDark ? 'Dark' : 'Light',
                style: typography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.accentPrimary,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Toggle Theme',
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 20,
                  color: colors.textPrimary,
                ),
                onPressed: () {
                  ref.read(themeModeProvider.notifier).toggleTheme();
                },
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
      bottomNavigationBar: CoveBottomNav(
        currentIndex: _navIndex,
        onTap: (index) => setState(() => _navIndex = index),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // Intro Card / Header
              Text(
                'Shared Home OS',
                style: typography.caption.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: colors.accentPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Foundational Design System',
                style: typography.headline,
              ),
              const SizedBox(height: 8),
              Text(
                'Editorial, quiet, and grounded. Built for two people sharing a home.',
                style: typography.bodyRegular.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: 28),

              // Section 1: Two-Tick Delivery-Status Indicator
              _buildSectionHeader(
                title: 'Two-Tick Delivery Indicator',
                subtitle:
                    'Understated muted checks. Strictly two states: saved locally & synced to partner.',
              ),
              const SizedBox(height: 12),
              CoveCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const CoveSyncTick(
                          status: CoveSyncStatus.savedLocally,
                          size: 16,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'One Tick: Saved locally on this device',
                            style: typography.bodyMedium,
                          ),
                        ),
                        Text(
                          '1 tick',
                          style: typography.caption,
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: colors.borderHairline, height: 1),
                    ),
                    Row(
                      children: [
                        const CoveSyncTick(
                          status: CoveSyncStatus.syncedToPartner,
                          size: 16,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Two Ticks: Synced to partner\'s device',
                            style: typography.bodyMedium,
                          ),
                        ),
                        Text(
                          '2 ticks',
                          style: typography.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Section 2: Typography & Large-Number Presence
              _buildSectionHeader(
                title: 'Typography & Large Numbers',
                subtitle:
                    'Bodoni Moda for totals & headlines. General Sans for functional UI copy.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CoveCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SUBSCRIPTIONS', style: typography.caption),
                          const SizedBox(height: 6),
                          Text('\$184', style: typography.largeNumber),
                          const SizedBox(height: 2),
                          Text('/month shared', style: typography.caption),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: CoveCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MORNING WALK', style: typography.caption),
                          const SizedBox(height: 8),
                          const CoveStreakIndicator(count: 14, label: 'days'),
                          const SizedBox(height: 6),
                          Text('Active joint rhythm', style: typography.caption),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Section 3: Tab Row & Shared Lists
              _buildSectionHeader(
                title: 'Tab Row & Shared Lists',
                subtitle:
                    'Active tab 2px underline. Grouped rows with 1px hairlines & 5px rounded checkboxes.',
              ),
              const SizedBox(height: 12),
              CoveTabRow(
                tabs: const ['Groceries', 'Home Supplies', 'Packing', 'Wishlist'],
                selectedIndex: _selectedTab,
                onTabSelected: (index) => setState(() => _selectedTab = index),
              ),
              const SizedBox(height: 14),
              CoveGroupedCard(
                children: [
                  CoveChecklistRow(
                    value: _item1Checked,
                    onChanged: (val) => setState(() => _item1Checked = val),
                    title: 'Oat milk (unsweetened)',
                    subtitle: 'Added by Sarah',
                    trailing: const CoveSyncTick(
                      status: CoveSyncStatus.syncedToPartner,
                    ),
                  ),
                  CoveChecklistRow(
                    value: _item2Checked,
                    onChanged: (val) => setState(() => _item2Checked = val),
                    title: 'Sourdough bread',
                    subtitle: 'Added by Alex',
                    trailing: const CoveSyncTick(
                      status: CoveSyncStatus.syncedToPartner,
                    ),
                  ),
                  CoveChecklistRow(
                    value: false,
                    onChanged: (val) {},
                    title: 'Fresh rosemary & garlic',
                    subtitle: 'Saved just now',
                    trailing: const CoveSyncTick(
                      status: CoveSyncStatus.savedLocally,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CovePillInput(
                controller: _inputController,
                hintText: 'Add an item to ${_selectedTab == 0 ? "Groceries" : "List"}…',
                prefixIcon: Icon(
                  Icons.add,
                  size: 18,
                  color: colors.textMuted,
                ),
                suffix: Icon(
                  Icons.arrow_upward_rounded,
                  size: 18,
                  color: colors.accentPrimary,
                ),
              ),
              const SizedBox(height: 28),

              // Section 4: Pill Buttons & Toggles
              _buildSectionHeader(
                title: 'Pill Buttons & Toggles',
                subtitle:
                    '999px capsule radius. Champagne-filled on-state & outline off-state.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CovePillButton(
                      label: 'Sign In with Google',
                      onPressed: () {},
                      icon: const Icon(Icons.login, size: 16),
                      isFullWidth: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CovePillButton(
                      label: 'Pair Partner',
                      variant: CoveButtonVariant.secondary,
                      onPressed: () {},
                      icon: const Icon(Icons.qr_code_2_outlined, size: 16),
                      isFullWidth: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CoveGroupedCard(
                children: [
                  CoveGroupedRow(
                    title: Text('Push Notifications', style: typography.bodyMedium),
                    subtitle: Text(
                      'Alert when partner updates an item',
                      style: typography.caption,
                    ),
                    trailing: CoveToggleSwitch(
                      value: _notificationsEnabled,
                      onChanged: (v) =>
                          setState(() => _notificationsEnabled = v),
                    ),
                  ),
                  CoveGroupedRow(
                    title: Text('Google Drive Backup', style: typography.bodyMedium),
                    subtitle: Text(
                      'Auto-snapshot encrypted SQLite db',
                      style: typography.caption,
                    ),
                    trailing: CoveToggleSwitch(
                      value: _backupEnabled,
                      onChanged: (v) => setState(() => _backupEnabled = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Section 5: Activity Log Row
              _buildSectionHeader(
                title: 'Activity Feed Row',
                subtitle:
                    'Quiet chronological log of household actions without notification noise.',
              ),
              const SizedBox(height: 12),
              CoveGroupedCard(
                children: const [
                  CoveActivityRow(
                    authorName: 'Sarah',
                    actionText: 'checked off Oat milk',
                    timestamp: '4m ago',
                    syncStatus: CoveSyncStatus.syncedToPartner,
                  ),
                  CoveActivityRow(
                    authorName: 'Alex',
                    actionText: 'logged \$42 for Farmer\'s Market',
                    timestamp: '1h ago',
                    syncStatus: CoveSyncStatus.syncedToPartner,
                  ),
                  CoveActivityRow(
                    authorName: 'Sarah',
                    actionText: 'renewed Spotify Duo subscription',
                    timestamp: 'Yesterday',
                    syncStatus: CoveSyncStatus.syncedToPartner,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Section 6: Empty & Loading States
              _buildSectionHeader(
                title: 'States: Empty & Loading',
                subtitle:
                    'Calm, spacious placeholders with serene, non-intrusive loading spinners.',
              ),
              const SizedBox(height: 12),
              CoveCard(
                child: const CoveEmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'All caught up',
                  description:
                      'No pending household errands or grocery items. Enjoy your evening together.',
                ),
              ),
              const SizedBox(height: 14),
              const CoveLoading(
                message: 'Syncing with partner\'s device…',
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    final typography = context.typography;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: typography.title.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: typography.caption.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

class _SubscriptionsPreviewScaffold extends ConsumerStatefulWidget {
  const _SubscriptionsPreviewScaffold();

  @override
  ConsumerState<_SubscriptionsPreviewScaffold> createState() =>
      _SubscriptionsPreviewScaffoldState();
}

class _SubscriptionsPreviewScaffoldState
    extends ConsumerState<_SubscriptionsPreviewScaffold> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final db = ref.read(appDatabaseProvider);
      // Ensure demo user & home exist
      ref.read(authProvider.notifier).signInWithDemoUser('Alex');
      final activeHomeNotifier = ref.read(activeHomeIdProvider.notifier);
      activeHomeNotifier.setActiveHome('demo_home');

      final existingHomes = await (db.select(db.localHomes)..where((t) => t.id.equals('demo_home'))).get();
      if (existingHomes.isEmpty) {
        await db.into(db.localHomes).insert(
              LocalHomesCompanion.insert(
                id: 'demo_home',
                name: 'Our Sanctuary',
                createdAt: DateTime.now(),
                createdBy: 'demo-user-alex',
              ),
            );
      }

      final existingSubs = await (db.select(db.localSubscriptions)..where((t) => t.homeId.equals('demo_home'))).get();
      if (existingSubs.isEmpty) {
        final now = DateTime.now();
        await db.into(db.localSubscriptions).insert(
              LocalSubscriptionsCompanion.insert(
                id: 'sub_1',
                homeId: 'demo_home',
                name: 'Spotify Family',
                amount: 19.99,
                billingCycle: const drift.Value('monthly'),
                nextBillingDate: now.add(const Duration(days: 3)),
                category: const drift.Value('streaming'),
                isActive: const drift.Value(true),
                isPrivate: const drift.Value(false),
                createdBy: const drift.Value('demo-user-alex'),
                createdAt: now,
              ),
            );
        await db.into(db.localSubscriptions).insert(
              LocalSubscriptionsCompanion.insert(
                id: 'sub_2',
                homeId: 'demo_home',
                name: '1Password Families',
                amount: 59.88,
                billingCycle: const drift.Value('annual'),
                nextBillingDate: now.add(const Duration(days: 6)),
                category: const drift.Value('software'),
                isActive: const drift.Value(true),
                isPrivate: const drift.Value(false),
                createdBy: const drift.Value('demo-user-alex'),
                createdAt: now,
              ),
            );
        await db.into(db.localSubscriptions).insert(
              LocalSubscriptionsCompanion.insert(
                id: 'sub_3',
                homeId: 'demo_home',
                name: 'Fiber Internet',
                amount: 80.00,
                billingCycle: const drift.Value('monthly'),
                nextBillingDate: now.add(const Duration(days: 18)),
                category: const drift.Value('utilities'),
                isActive: const drift.Value(true),
                isPrivate: const drift.Value(false),
                createdBy: const drift.Value('demo-user-alex'),
                createdAt: now,
              ),
            );
        await db.into(db.localSubscriptions).insert(
              LocalSubscriptionsCompanion.insert(
                id: 'sub_4',
                homeId: 'demo_home',
                name: 'Kindle Unlimited (Private)',
                amount: 11.99,
                billingCycle: const drift.Value('monthly'),
                nextBillingDate: now.add(const Duration(days: 12)),
                category: const drift.Value('news'),
                isActive: const drift.Value(true),
                isPrivate: const drift.Value(true),
                createdBy: const drift.Value('demo-user-alex'),
                createdAt: now,
              ),
            );
        await db.into(db.localSubscriptions).insert(
              LocalSubscriptionsCompanion.insert(
                id: 'sub_5',
                homeId: 'demo_home',
                name: 'NYT Games',
                amount: 4.00,
                billingCycle: const drift.Value('monthly'),
                nextBillingDate: now.add(const Duration(days: 20)),
                category: const drift.Value('news'),
                isActive: const drift.Value(false),
                isPrivate: const drift.Value(false),
                createdBy: const drift.Value('demo-user-alex'),
                createdAt: now,
              ),
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sampleSubs = [
      LocalSubscription(
        id: 'sub_1',
        homeId: 'demo_home',
        name: 'Spotify Family',
        amount: 19.99,
        currency: 'USD',
        billingCycle: 'monthly',
        nextBillingDate: now.add(const Duration(days: 3)),
        category: 'streaming',
        isActive: true,
        isPrivate: false,
        createdBy: 'demo-user-alex',
        createdAt: now,
      ),
      LocalSubscription(
        id: 'sub_2',
        homeId: 'demo_home',
        name: '1Password Families',
        amount: 59.88,
        currency: 'USD',
        billingCycle: 'annual',
        nextBillingDate: now.add(const Duration(days: 6)),
        category: 'software',
        isActive: true,
        isPrivate: false,
        createdBy: 'demo-user-alex',
        createdAt: now,
      ),
      LocalSubscription(
        id: 'sub_3',
        homeId: 'demo_home',
        name: 'Fiber Internet',
        amount: 80.00,
        currency: 'USD',
        billingCycle: 'monthly',
        nextBillingDate: now.add(const Duration(days: 18)),
        category: 'utilities',
        isActive: true,
        isPrivate: false,
        createdBy: 'demo-user-alex',
        createdAt: now,
      ),
      LocalSubscription(
        id: 'sub_4',
        homeId: 'demo_home',
        name: 'Kindle Unlimited',
        amount: 11.99,
        currency: 'USD',
        billingCycle: 'monthly',
        nextBillingDate: now.add(const Duration(days: 12)),
        category: 'news',
        isActive: true,
        isPrivate: true,
        createdBy: 'demo-user-alex',
        createdAt: now,
      ),
      LocalSubscription(
        id: 'sub_5',
        homeId: 'demo_home',
        name: 'NYT Games',
        amount: 4.00,
        currency: 'USD',
        billingCycle: 'monthly',
        nextBillingDate: now.add(const Duration(days: 20)),
        category: 'news',
        isActive: false,
        isPrivate: false,
        createdBy: 'demo-user-alex',
        createdAt: now,
      ),
    ];

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: SubscriptionsScreen(initialSubscriptions: sampleSubs),
        ),
      ),
    );
  }
}

class _ListsPreviewScaffold extends StatelessWidget {
  const _ListsPreviewScaffold();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sampleLists = [
      LocalList(
        id: 'list_grocery',
        homeId: 'demo_home',
        name: 'Grocery',
        isArchived: false,
        createdAt: now,
        createdBy: 'demo-user-alex',
      ),
      LocalList(
        id: 'list_travel',
        homeId: 'demo_home',
        name: 'Travel',
        isArchived: false,
        createdAt: now,
        createdBy: 'demo-user-alex',
      ),
      LocalList(
        id: 'list_planning',
        homeId: 'demo_home',
        name: 'Planning',
        isArchived: false,
        createdAt: now,
        createdBy: 'demo-user-alex',
      ),
    ];

    final sampleItems = [
      LocalListItem(
        id: 'item_1',
        homeId: 'demo_home',
        listId: 'list_grocery',
        title: 'Oat milk (barista blend)',
        isCompleted: false,
        createdBy: 'demo-user-alex',
        createdAt: now.subtract(const Duration(minutes: 42)),
      ),
      LocalListItem(
        id: 'item_2',
        homeId: 'demo_home',
        listId: 'list_grocery',
        title: 'Fresh rosemary & thyme',
        isCompleted: false,
        createdBy: 'partner-user-sarah',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      LocalListItem(
        id: 'item_3',
        homeId: 'demo_home',
        listId: 'list_grocery',
        title: 'Sourdough loaf (Tartine)',
        isCompleted: false,
        createdBy: 'demo-user-alex',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      LocalListItem(
        id: 'item_4',
        homeId: 'demo_home',
        listId: 'list_grocery',
        title: 'Greek whole milk yogurt',
        isCompleted: true,
        createdBy: 'partner-user-sarah',
        createdAt: now.subtract(const Duration(days: 1)),
        completedAt: now.subtract(const Duration(hours: 1)),
        completedBy: 'demo-user-alex',
      ),
      LocalListItem(
        id: 'item_5',
        homeId: 'demo_home',
        listId: 'list_grocery',
        title: 'Organic olive oil',
        isCompleted: true,
        createdBy: 'demo-user-alex',
        createdAt: now.subtract(const Duration(days: 2)),
        completedAt: now.subtract(const Duration(hours: 4)),
        completedBy: 'partner-user-sarah',
      ),
    ];

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: ListsScreen(
            initialLists: sampleLists,
            initialItems: sampleItems,
          ),
        ),
      ),
    );
  }
}

class _ExpensesPreviewScaffold extends StatelessWidget {
  const _ExpensesPreviewScaffold();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sampleExpenses = [
      LocalExpense(
        id: 'exp_1',
        homeId: 'demo_home',
        title: 'Farmers Market Produce',
        amount: 54.80,
        currency: 'USD',
        paidBy: 'demo-user-alex',
        splitRatio: 0.5,
        expenseDate: now.subtract(const Duration(hours: 4)),
        category: 'Groceries',
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      LocalExpense(
        id: 'exp_2',
        homeId: 'demo_home',
        title: 'Home Depot Hardware & Supplies',
        amount: 86.10,
        currency: 'USD',
        paidBy: 'partner-user-sarah',
        splitRatio: 0.5,
        expenseDate: now.subtract(const Duration(days: 2)),
        category: 'Home & Utilities',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      LocalExpense(
        id: 'exp_3',
        homeId: 'demo_home',
        title: 'Osteria Mozza Dinner',
        amount: 142.50,
        currency: 'USD',
        paidBy: 'demo-user-alex',
        splitRatio: 0.5,
        expenseDate: now.subtract(const Duration(days: 5)),
        category: 'Dining Out',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      LocalExpense(
        id: 'exp_4',
        homeId: 'demo_home',
        title: 'Japanese Ceramic Planter',
        amount: 65.00,
        currency: 'USD',
        paidBy: 'demo-user-alex',
        splitRatio: 0.0, // partnerCanSee
        expenseDate: now.subtract(const Duration(days: 7)),
        category: 'Shopping',
        createdAt: now.subtract(const Duration(days: 7)),
      ),
      LocalExpense(
        id: 'exp_5',
        homeId: 'demo_home',
        title: 'Boutique Fragrance (Surprise)',
        amount: 110.00,
        currency: 'USD',
        paidBy: 'demo-user-alex',
        splitRatio: -1.0, // privateToMe
        expenseDate: now.subtract(const Duration(days: 9)),
        category: 'Shopping',
        createdAt: now.subtract(const Duration(days: 9)),
      ),
    ];

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: ExpensesScreen(initialExpenses: sampleExpenses),
        ),
      ),
    );
  }
}

