import 'dart:async';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/cove_theme.dart';
import '../core/widgets/cove_floating_bar.dart';
import '../core/widgets/cove_web_sidebar.dart';
import '../sync/providers/active_home_provider.dart';
import '../sync/providers/cove_sync_providers.dart';
import 'activity/activity_screen.dart';
import 'add/add_flow.dart';
import 'backup/drive_backup_controller.dart';
import 'calendar/calendar_screen.dart';
import 'changelog/whats_fresh_modal.dart';
import 'expenses/expenses_screen.dart';
import 'habits/habits_screen.dart';
import 'home/home_controller.dart';
import 'lists/list_controller.dart';
import 'lists/lists_screen.dart';
import 'notifications/notification_controller.dart';
import 'notifications/notification_detail_dispatcher.dart';
import 'notifications/notification_models.dart';
import 'profile/user_profile_controller.dart';
import 'routines/routine_screen.dart';
import 'subscriptions/commitment_detail_sheet.dart';
import 'subscriptions/commitments_helicopter_screen.dart';
import 'subscriptions/emi_tracker_screen.dart';
import 'subscriptions/subscriptions_screen.dart';
import 'today/today_screen.dart';
import 'weather/weather_controller.dart';
import 'widgets/cove_slip_widget.dart';
import 'widgets/cove_widget_service.dart';
import 'widgets/cove_widget_tick_service.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  /// Switches the active bar destination when an [AppShell] ancestor is present
  /// on mobile/non-desktop layouts. Returns `true` if handled by [AppShell].
  static bool maybeNavigateTo(BuildContext context, String destinationId) {
    final state = context.findAncestorStateOfType<_AppShellState>();
    if (state == null) return false;
    final isDesktop = kIsWeb && MediaQuery.sizeOf(context).width >= 840;
    if (isDesktop) {
      return state._navigateDesktopToDestination(destinationId);
    }
    state._handleSeatTap(destinationId);
    return true;
  }

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  String _activeDestination = 'home';
  String _moneySeatId = 'expenses';
  CoveFloatingBarState _barState =
      const CoveFloatingBarState.rest(selectedId: 'home');
  DateTime? _selectedCalendarDate;
  DateTime? _lastBackPressed;
  StreamSubscription? _navSub;
  StreamSubscription? _notifSub;
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifService = ref.read(notificationServiceProvider);
      notifService.initializeLocalNotifications();
      notifService.initializeFcm();

      _navSub = notifService.onNavigateToPayload.listen((payload) {
        _navigateToPayload(payload);
      });

      _notifSub = notifService.onNotificationReceived.listen((payload) {
        _showInAppNotificationBanner(payload);
      });

      // Check if a notification launched the app and navigate to its module and detail sheet immediately
      final pendingPayload =
          notifService.consumePendingNotificationPayload() ??
              ref.read(notificationPayloadNavigationProvider);
      final pendingModule =
          notifService.consumePendingNavigationModule() ??
              ref.read(notificationNavigationProvider);

      if (pendingPayload != null) {
        ref.read(notificationPayloadNavigationProvider.notifier).navigateTo(null);
        ref.read(notificationNavigationProvider.notifier).navigateTo(null);
        _navigateToPayload(pendingPayload);
      } else if (pendingModule != null) {
        ref.read(notificationNavigationProvider.notifier).navigateTo(null);
        _navigateToModule(pendingModule);
      }

      // Start the sync engine, self-heal home synchronization, and pull unread events
      // only if the active home has its encryption key on this device.
      final activeHomeId = ref.read(activeHomeIdProvider);
      final syncEngine = ref.read(syncEngineProvider);
      final homeController = ref.read(homeControllerProvider);

      if (activeHomeId != null && activeHomeId.isNotEmpty) {
        ref.read(homeKeyStoreProvider).hasKey(activeHomeId).then((hasKey) {
          if (!mounted || !hasKey) return;
          homeController.ensureHomeSyncedToSupabase(activeHomeId).then((_) {
            if (!mounted) return;
            syncEngine.start(activeHomeId: activeHomeId).then((_) {
              if (!mounted) return;
              syncEngine.pullLatestEvents(homeId: activeHomeId);
              ref.read(userProfileProvider.notifier).announceProfile();
            });
          });
        });
      } else {
        syncEngine.start().then((_) {
          if (!mounted) return;
          ref.read(userProfileProvider.notifier).announceProfile();
        });
      }

      // Check and present What's Fresh modal once per new release (only if not navigating via notification)
      if (pendingPayload == null && pendingModule == null) {
        WhatsFreshModal.checkAndShow(context);
      }

      // Wake the Drive backup controller so the nightly backup job is
      // (re)registered with WorkManager on every launch.
      ref.read(driveBackupProvider);

      // Schedule the 30-minute periodic WorkManager refresh for home-screen
      // widgets, register the widget tick port & replay any unapplied intents
      // on app start, and wire widget tap deep links (18-widgets.md).
      final widgetService = ref.read(coveWidgetServiceProvider);
      final widgetTickService = ref.read(coveWidgetTickServiceProvider);
      widgetTickService.registerMainIsolatePort();
      unawaited(widgetTickService.replayUnappliedIntentsOnAppStart());
      unawaited(widgetService.scheduler.schedulePeriodicRefresh());
      unawaited(widgetService.registerInteractivityCallback());
      unawaited(
        widgetService.bridge.initiallyLaunchedFromHomeWidget().then((uri) {
          if (!mounted || uri == null) return;
          _handleWidgetLaunchUri(uri);
        }),
      );
      _widgetClickSub = widgetService.bridge.widgetClicked.listen((uri) {
        if (!mounted || uri == null) return;
        _handleWidgetLaunchUri(uri);
      });
    });
  }

  void _handleWidgetLaunchUri(Uri uri) {
    if (uri.scheme != 'cove' || uri.host != 'widget') return;
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;

    Navigator.of(context).popUntil((route) => route.isFirst);

    switch (segments.first) {
      case 'arc':
        _selectedCalendarDate = clock.now();
        _handleSeatTap('day');
        break;
      case 'slip':
        final listId = uri.queryParameters['listId'];
        if (listId != null && listId.isNotEmpty) {
          ref.read(selectedListIdProvider.notifier).selectList(listId);
        } else {
          final currentSlipListId = ref.read(slipSummaryProvider).listId;
          if (currentSlipListId != null && currentSlipListId.isNotEmpty) {
            ref
                .read(selectedListIdProvider.notifier)
                .selectList(currentSlipListId);
          }
        }
        _handleSeatTap('todo');
        if (segments.length > 1 && segments[1] == 'configure') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            SlipListPickerSheet.show(context);
          });
        }
        break;
      case 'sheet':
        final kind = uri.queryParameters['kind'];
        if (kind == 'event') {
          _selectedCalendarDate = clock.now();
          _handleSeatTap('day');
        } else if (kind == 'routine') {
          _handleSeatTap('routines');
        } else if (kind == 'expenses') {
          _handleSeatTap('expenses');
        } else {
          _handleSeatTap('home');
        }
        break;
      case 'ledger':
        final target = segments.length > 1 ? segments[1] : 'expenses';
        if (target == 'commitment' || target == 'commitments') {
          _handleSeatTap('commitments');
          final commitmentId = uri.queryParameters['id'];
          if (commitmentId != null && commitmentId.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final subs =
                  ref.read(activeHomeSubscriptionsProvider).value ?? const [];
              for (final sub in subs) {
                if (sub.id == commitmentId) {
                  CommitmentDetailSheet.show(context, sub);
                  break;
                }
              }
            });
          }
        } else {
          _handleSeatTap('expenses');
        }
        break;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref
            .read(coveWidgetTickServiceProvider)
            .replayUnappliedIntentsOnAppStart(),
      );
      // Pick up results of a nightly backup that ran while the app was closed.
      ref.read(driveBackupProvider.notifier).refresh();
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
    _widgetClickSub?.cancel();
    super.dispose();
  }

  bool _navigateDesktopToDestination(String destinationId) {
    switch (destinationId) {
      case 'home':
        setState(() {
          _currentIndex = 0;
          _lastBackPressed = null;
        });
        return true;
      case 'commitments':
        setState(() {
          _currentIndex = 1;
          _lastBackPressed = null;
        });
        return true;
      case 'day':
      case 'calendar':
        setState(() {
          _currentIndex = 2;
          _lastBackPressed = null;
        });
        return true;
      case 'todo':
      case 'tasks':
        setState(() {
          _currentIndex = 3;
          _lastBackPressed = null;
        });
        return true;
      case 'expenses':
      case 'money':
        setState(() {
          _currentIndex = 4;
          _lastBackPressed = null;
        });
        return true;
      default:
        return false;
    }
  }

  void _handleSeatTap(String id) {
    setState(() {
      _lastBackPressed = null;
      switch (id) {
        case 'home':
          _activeDestination = 'home';
          _currentIndex = 0;
          _barState = const CoveFloatingBarState.rest(selectedId: 'home');
          break;
        case 'money':
        case 'expenses':
          _activeDestination = 'expenses';
          _moneySeatId = 'expenses';
          _currentIndex = 4;
          _barState = const CoveFloatingBarState.money(selectedId: 'expenses');
          break;
        case 'commitments':
          _activeDestination = 'commitments';
          _moneySeatId = 'commitments';
          _currentIndex = 1;
          _barState =
              const CoveFloatingBarState.money(selectedId: 'commitments');
          break;
        case 'more':
          if (_barState.mode == CoveFloatingBarMode.more) {
            _barState = CoveFloatingBarState.money(selectedId: _moneySeatId);
          } else {
            _barState = CoveFloatingBarState.more(selectedId: _moneySeatId);
          }
          break;
        case 'tasks':
        case 'todo':
          _activeDestination = 'todo';
          _currentIndex = 3;
          _barState = const CoveFloatingBarState.tasks(selectedId: 'todo');
          break;
        case 'habits':
          _activeDestination = 'habits';
          _barState = const CoveFloatingBarState.tasks(selectedId: 'habits');
          break;
        case 'calendar':
        case 'day':
          _activeDestination = 'day';
          _currentIndex = 2;
          _selectedCalendarDate ??= clock.now();
          _barState = const CoveFloatingBarState.calendar(selectedId: 'day');
          break;
        case 'routines':
          _activeDestination = 'routines';
          _barState =
              const CoveFloatingBarState.calendar(selectedId: 'routines');
          break;
      }
    });
  }

  void _handleOverflowItemTap(String id) {
    setState(() {
      _lastBackPressed = null;
      _barState = CoveFloatingBarState.money(selectedId: _moneySeatId);
    });
    switch (id) {
      case 'emis':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EmiTrackerScreen()),
        );
        break;
      case 'year':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CommitmentsHelicopterScreen(),
          ),
        );
        break;
    }
  }

  void _handleAddTap() {
    if (_barState.mode == CoveFloatingBarMode.more) {
      setState(() {
        _barState = CoveFloatingBarState.money(selectedId: _moneySeatId);
      });
    }
    final anchor = _activeDestination == 'day'
        ? (_selectedCalendarDate ?? clock.now())
        : clock.now();
    AddFlow.show(context, anchor: anchor);
  }

  void _navigateToModule(NotificationModule module) {
    if (!mounted) return;

    // Pop any open modals, sheets, or pushed routes to return to the root shell
    Navigator.of(context).popUntil((route) => route.isFirst);

    final isDesktop = kIsWeb && MediaQuery.sizeOf(context).width >= 840;

    switch (module) {
      case NotificationModule.home:
        _handleSeatTap('home');
        break;
      case NotificationModule.subscriptions:
        _handleSeatTap('commitments');
        break;
      case NotificationModule.calendar:
        _handleSeatTap('day');
        break;
      case NotificationModule.lists:
        _handleSeatTap('todo');
        break;
      case NotificationModule.expenses:
        _handleSeatTap('expenses');
        break;
      case NotificationModule.habits:
        if (isDesktop) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HabitsScreen()),
          );
        } else {
          _handleSeatTap('habits');
        }
        break;
      case NotificationModule.activity:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ActivityScreen()),
        );
        break;
    }
  }

  void _navigateToPayload(CoveNotificationPayload payload) {
    _navigateToModule(payload.module);
    NotificationDetailDispatcher.openDetailForNotification(
      context,
      ref,
      payload,
    );
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
        margin: const EdgeInsets.symmetric(
          horizontal: CoveSpace.lg,
          vertical: CoveSpace.md,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(CoveRadius.card)),
        ),
        backgroundColor: colors.surfaceCard,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.accentPrimary.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.all(
                  Radius.circular(CoveRadius.inline),
                ),
              ),
              child: Icon(icon, color: colors.accentPrimary, size: 20),
            ),
            const SizedBox(width: CoveSpace.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payload.title,
                    style: CoveType.rowTitle.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    payload.body,
                    style: CoveType.rowSub.copyWith(
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
          onPressed: () => _navigateToPayload(payload),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    ref.watch(coveWidgetAutoSyncProvider);

    ref.listen<NotificationModule?>(notificationNavigationProvider, (
      prev,
      next,
    ) {
      if (next != null) {
        _navigateToModule(next);
        ref.read(notificationNavigationProvider.notifier).navigateTo(null);
      }
    });

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

        if (isDesktop) {
          if (_currentIndex != 0) {
            setState(() {
              _currentIndex = 0;
              _lastBackPressed = null;
            });
            return;
          }
        } else {
          // Android back: from any category destination -> Home.
          if (_activeDestination != 'home' ||
              _barState.mode != CoveFloatingBarMode.rest) {
            _handleSeatTap('home');
            return;
          }
        }

        // From Home -> the system default, as today (double press within 2s to exit)
        final now = clock.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Press back again to exit',
                textAlign: TextAlign.center,
                style: CoveType.rowSub.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 76, left: 48, right: 48),
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(
                  Radius.circular(CoveRadius.card),
                ),
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
                          child: _buildDesktopTab(),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Stack(
                children: [
                  Positioned.fill(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: _buildBarDestination(),
                      ),
                    ),
                  ),
                  if (_barState.isMoreMenuOpen)
                    Positioned.fill(
                      child: GestureDetector(
                        key: const ValueKey('cove_bar_more_outside_scrim'),
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _handleSeatTap('more'),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: CoveFloatingBar(
                      state: _barState,
                      onSeatTap: _handleSeatTap,
                      onOverflowItemTap: _handleOverflowItemTap,
                      onAddTap: _handleAddTap,
                      onDismissMore: () => _handleSeatTap('more'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDesktopTab() {
    switch (_currentIndex) {
      case 0:
        return const TodayScreen();
      case 1:
        return const SubscriptionsScreen();
      case 2:
        return const CalendarScreen();
      case 3:
        return const ListsScreen();
      case 4:
        return const ExpensesScreen();
      default:
        return const TodayScreen();
    }
  }

  Widget _buildBarDestination() {
    switch (_activeDestination) {
      case 'home':
        return const TodayScreen();
      case 'expenses':
        return const ExpensesScreen();
      case 'commitments':
        return const SubscriptionsScreen();
      case 'todo':
        return const ListsScreen();
      case 'habits':
        return const HabitsScreen();
      case 'day':
        return CalendarScreen(
          initialSelectedDate: _selectedCalendarDate,
          onSelectedDateChanged: (d) {
            _selectedCalendarDate = d;
          },
        );
      case 'routines':
        return const RoutineScreen();
      default:
        return const TodayScreen();
    }
  }
}
