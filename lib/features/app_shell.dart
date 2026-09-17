import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/cove_theme.dart';
import '../core/widgets/cove_bottom_nav.dart';
import '../core/widgets/cove_web_sidebar.dart';
import 'activity/activity_read_status_controller.dart';
import 'activity/activity_screen.dart';
import 'calendar/calendar_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'expenses/expenses_screen.dart';
import 'habits/habits_screen.dart';
import 'home/home_controller.dart';
import 'home/home_switcher_sheet.dart';
import 'lists/lists_screen.dart';
import 'notifications/notification_controller.dart';
import 'notifications/notification_models.dart';
import 'auth/auth_controller.dart';
import 'profile/profile_screen.dart';
import 'profile/user_profile_controller.dart';
import 'routines/routine_screen.dart';
import 'subscriptions/subscriptions_screen.dart';
import 'today/today_screen.dart';
import 'dart:async';
import '../sync/providers/active_home_provider.dart';
import '../sync/providers/cove_sync_providers.dart';
import 'weather/weather_controller.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  DateTime? _lastBackPressed;
  StreamSubscription? _navSub;
  StreamSubscription? _notifSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifService = ref.read(notificationServiceProvider);
      notifService.initializeLocalNotifications();
      notifService.initializeFcm();

      _navSub = notifService.onNavigateToModule.listen((module) {
        _navigateToModule(module);
      });

      _notifSub = notifService.onNotificationReceived.listen((payload) {
        _showInAppNotificationBanner(payload);
      });

      // Start the sync engine, self-heal home synchronization, and pull unread events
      final activeHomeId = ref.read(activeHomeIdProvider);
      final syncEngine = ref.read(syncEngineProvider);
      final homeController = ref.read(homeControllerProvider);

      if (activeHomeId != null && activeHomeId.isNotEmpty) {
        homeController.ensureHomeSyncedToSupabase(activeHomeId).then((_) {
          syncEngine.start(activeHomeId: activeHomeId).then((_) {
            syncEngine.pullLatestEvents(homeId: activeHomeId);
            ref.read(userProfileProvider.notifier).announceProfile();
          });
        });
      } else {
        syncEngine.start().then((_) {
          ref.read(userProfileProvider.notifier).announceProfile();
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Silently refresh weather when returning to app / when location may have been toggled
      ref.read(weatherProvider.notifier).refreshWeather();
      final activeHomeId = ref.read(activeHomeIdProvider);
      if (activeHomeId != null && activeHomeId.isNotEmpty) {
        ref.read(syncEngineProvider).pullLatestEvents(homeId: activeHomeId);
        ref.read(userProfileProvider.notifier).announceProfile();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _navSub?.cancel();
    _notifSub?.cancel();
    super.dispose();
  }

  void _navigateToModule(NotificationModule module) {
    if (!mounted) return;
    switch (module) {
      case NotificationModule.home:
        setState(() => _currentIndex = 0);
        break;
      case NotificationModule.subscriptions:
        setState(() => _currentIndex = 1);
        break;
      case NotificationModule.calendar:
        setState(() => _currentIndex = 2);
        break;
      case NotificationModule.lists:
        setState(() => _currentIndex = 3);
        break;
      case NotificationModule.expenses:
        setState(() => _currentIndex = 4);
        break;
      case NotificationModule.habits:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HabitsScreen()),
        );
        break;
      case NotificationModule.activity:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ActivityScreen()),
        );
        break;
    }
  }

  void _showInAppNotificationBanner(CoveNotificationPayload payload) {
    if (!mounted) return;
    final colors = context.colors;

    IconData icon;
    switch (payload.module) {
      case NotificationModule.expenses:
        icon = Icons.receipt_long_outlined;
        break;
      case NotificationModule.habits:
        icon = Icons.check_circle_outline;
        break;
      case NotificationModule.lists:
        icon = Icons.checklist_outlined;
        break;
      case NotificationModule.subscriptions:
        icon = Icons.credit_card_outlined;
        break;
      case NotificationModule.calendar:
        icon = Icons.calendar_month_outlined;
        break;
      case NotificationModule.home:
        icon = Icons.home_outlined;
        break;
      default:
        icon = Icons.notifications_active_outlined;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: colors.surfaceCard,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.accentPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: colors.accentPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payload.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    payload.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: colors.accentPrimary,
          onPressed: () => _navigateToModule(payload.module),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    ref.listen<NotificationModule?>(notificationNavigationProvider, (prev, next) {
      if (next != null) {
        _navigateToModule(next);
        ref.read(notificationNavigationProvider.notifier).navigateTo(null);
      }
    });

    final profile = ref.watch(userProfileProvider);
    final user = ref.watch(authProvider).value;
    final effectiveName = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : (user?.displayName?.trim().isNotEmpty == true
            ? user!.displayName!.trim()
            : '');
    final firstName = effectiveName.split(' ').firstOrNull ?? '';
    final initialLetter =
        firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U';
    final isDesktop = kIsWeb && MediaQuery.sizeOf(context).width >= 840;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If there is any pushed route, modal sheet, or dialog open, pop it
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }

        // If not on Dashboard tab, switch to Dashboard first
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
            _lastBackPressed = null;
          });
          return;
        }

        // On Dashboard / Home tab: require double press within 2 seconds to exit
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Press back again to exit',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'GeneralSans',
                ),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 76, left: 48, right: 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colors.borderHairline),
              ),
              backgroundColor: colors.surfaceCard,
            ),
          );
          return;
        }

        // Second back press within 2 seconds: close app
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: isDesktop
            ? null
            : AppBar(
                title: const HomeSwitcherAppBarTitle(),
                actions: [
                  IconButton(
                    icon: Icon(
                      Icons.schedule_outlined,
                      size: 22,
                      color: colors.textPrimary,
                    ),
                    tooltip: 'Routines',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RoutineScreen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.wb_sunny_outlined,
                      size: 22,
                      color: colors.textPrimary,
                    ),
                    tooltip: 'Today',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TodayScreen()),
                      );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final unreadCount = ref.watch(unreadActivityCountProvider);
                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              unreadCount > 0
                                  ? Icons.notifications_rounded
                                  : Icons.notifications_none_rounded,
                              size: 22,
                              color: colors.textPrimary,
                            ),
                            tooltip: 'Notifications',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const ActivityScreen()),
                              );
                            },
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 6,
                              top: 8,
                              child: IgnorePointer(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: colors.accentSecondary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(
                                      minWidth: 16, minHeight: 16),
                                  child: Center(
                                    child: Text(
                                      unreadCount > 99 ? '99+' : '$unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16, left: 4),
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        },
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor: (profile.avatarUrl != null &&
                                  profile.avatarUrl!.isNotEmpty)
                              ? colors.surfaceRow
                              : colors.accentPrimary,
                          backgroundImage: (profile.avatarUrl != null &&
                                  profile.avatarUrl!.isNotEmpty)
                              ? NetworkImage(profile.avatarUrl!)
                              : null,
                          child: (profile.avatarUrl != null &&
                                  profile.avatarUrl!.isNotEmpty)
                              ? null
                              : Text(
                                  initialLetter,
                                  style: typography.headline.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: colors.surfaceRow,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: isDesktop
            ? null
            : CoveBottomNav(
                currentIndex: _currentIndex,
                onTap: (index) {
                  if (_currentIndex != index) {
                    setState(() {
                      _currentIndex = index;
                      _lastBackPressed = null;
                    });
                  }
                },
              ),
        body: isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CoveWebSidebar(
                    currentIndex: _currentIndex,
                    onSelectIndex: (index) {
                      if (_currentIndex != index) {
                        setState(() {
                          _currentIndex = index;
                          _lastBackPressed = null;
                        });
                      }
                    },
                  ),
                  Expanded(
                    child: SafeArea(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1320),
                          child: _buildCurrentTab(),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: _buildCurrentTab(),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const SubscriptionsScreen();
      case 2:
        return const CalendarScreen();
      case 3:
        return const ListsScreen();
      case 4:
        return const ExpensesScreen();
      default:
        return const DashboardScreen();
    }
  }
}
