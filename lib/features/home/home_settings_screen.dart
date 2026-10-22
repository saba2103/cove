import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/cove_tokens.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_avatar.dart';
import '../../core/widgets/cove_max_width.dart';
import '../../core/widgets/cove_metric_card.dart';
import '../../core/widgets/cove_page_header.dart';
import '../../core/widgets/cove_round_button.dart';
import '../../core/widgets/cove_row.dart';
import '../../core/widgets/cove_section_label.dart';
import '../../core/widgets/cove_sheet.dart';
import '../../sync/key_management/pairing_qr_view.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../expenses/monthly_budget_controller.dart';
import '../profile/currency_selector_sheet.dart';
import '../profile/edit_home_dialog.dart';
import '../profile/home_metadata_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../profile/user_profile_controller.dart';
import '../weather/weather_controller.dart';
import 'home_controller.dart';

/// Our home — the Front Door (`design/screens/our-home.md`).
///
/// Order:
/// 1. `CovePageHeader` (back + edit action) and the arch illustration with
///    scrolling radial glow, names beneath, description/location line, and
///    Together / In Cove dates.
/// 2. "This month" — four Almanac-style [CoveMetricCard]s in a [CoveMetricGrid].
/// 3. "Who lives here" — people at [CoveSize.avatarProfile] ([CoveAvatar.profile])
///    with no role captions.
/// 4. "This home" — [CoveRow] list for home details, currency, pairing keys,
///    and leaving the home, followed by the encryption reassurance footer.
class HomeSettingsScreen extends ConsumerWidget {
  const HomeSettingsScreen({super.key});

  static const double _kArchWidth = 176.0;
  static const double _kArchHeight = 208.0;
  static const double _kGlowSize = 260.0;
  static const double _kLeadingIconSize = 16.0;
  static const double _kFooterIconSize = 14.0;

  Widget _buildLeadingOrb(BuildContext context, IconData icon, {Color? color}) {
    final cv = context.cv;
    return SizedBox(
      width: CoveSize.avatarRow,
      height: CoveSize.avatarRow,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cv.accentWash,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            icon,
            size: _kLeadingIconSize,
            color: color ?? cv.accentText,
          ),
        ),
      ),
    );
  }

  Widget _buildChevron(BuildContext context) {
    final cv = context.cv;
    return Icon(
      Icons.chevron_right_rounded,
      size: CoveSpace.lg,
      color: cv.textTertiary,
    );
  }

  Future<void> _showInviteQrSheet(
    BuildContext context,
    HomeController homeController,
    String homeId,
  ) async {
    final payload = await homeController.getPairingPayload(homeId);
    if (payload != null && context.mounted) {
      await CoveSheet.show<void>(
        context: context,
        builder: (_) => PairingQrView(payload: payload),
      );
    }
  }

  Future<void> _confirmLeaveHome(
    BuildContext context,
    HomeController homeController,
    String homeId,
    String homeName,
  ) async {
    final cv = context.cv;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cv.surfaceSheet,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(CoveRadius.card)),
        ),
        title: Text(
          'Leave $homeName?',
          style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
        ),
        content: Text(
          'You will remove the encryption key and access to this Home from this device.',
          style: CoveType.body.copyWith(color: cv.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: CoveType.readout.copyWith(color: cv.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Leave',
              style: CoveType.readout.copyWith(color: cv.statusAlertText),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await homeController.leaveHome(homeId);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cv = context.cv;
    final activeHome = ref.watch(activeHomeProvider).value;
    final user = ref.watch(authProvider).value;
    final userProfile = ref.watch(userProfileProvider);
    final partnerProfile = ref.watch(partnerProfileProvider);
    final homeMeta = ref.watch(homeMetadataProvider);
    final currency = ref.watch(currencyPreferenceProvider);
    final budget = ref.watch(monthlyBudgetProvider);
    final weather = ref.watch(weatherProvider);
    final expenses = ref.watch(activeHomeExpensesProvider).value ?? const [];
    final subscriptions =
        ref.watch(activeHomeSubscriptionsProvider).value ?? const [];
    final lists = ref.watch(activeHomeListsProvider).value ?? const [];
    final listItems =
        ref.watch(activeHomeAllListItemsProvider).value ?? const [];
    final habits = ref.watch(activeHomeHabitsProvider).value ?? const [];
    final homeController = ref.read(homeControllerProvider);

    if (activeHome == null) {
      return Scaffold(
        backgroundColor: cv.surfaceCanvas,
        body: SafeArea(
          child: CoveMaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CovePageHeader(
                  title: 'Our home',
                  leading: CoveRoundButton(
                    icon: Icons.arrow_back_rounded,
                    variant: CoveRoundButtonVariant.ghost,
                    semanticLabel: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'No active home found.',
                      style: CoveType.body.copyWith(color: cv.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Order names strictly by home.createdBy (Person A = creator, Person B = joiner).
    final viewerIsCreator =
        user == null || user.id.isEmpty || user.id == activeHome.createdBy;
    final creatorName = viewerIsCreator
        ? (userProfile.displayName.isNotEmpty
            ? userProfile.displayName
            : 'Alex')
        : (partnerProfile.displayName.isNotEmpty
            ? partnerProfile.displayName
            : 'Partner');
    final joinerName = viewerIsCreator
        ? (partnerProfile.displayName.isNotEmpty
            ? partnerProfile.displayName
            : 'Partner')
        : (userProfile.displayName.isNotEmpty
            ? userProfile.displayName
            : 'Alex');

    final anniversaryDate =
        homeMeta.anniversaryDate ?? activeHome.anniversaryDate;
    final dateFmt = DateFormat('MMM yyyy');
    final togetherText =
        anniversaryDate != null ? dateFmt.format(anniversaryDate) : '—';
    final inCoveText = dateFmt.format(activeHome.createdAt);

    final descriptionLine =
        (activeHome.description != null && activeHome.description!.isNotEmpty)
            ? activeHome.description!
            : (weather?.cityName ?? '');

    // Almanac metrics
    final activeCommitmentsCount =
        subscriptions.where((s) => s.isActive).length;
    final nonTransferExpenses =
        expenses.where((e) => !e.isTransfer).toList();
    final refDate = nonTransferExpenses.isNotEmpty
        ? nonTransferExpenses.first.expenseDate
        : activeHome.createdAt;
    final monthSpent = nonTransferExpenses
        .where(
          (e) =>
              e.expenseDate.year == refDate.year &&
              e.expenseDate.month == refDate.month,
        )
        .fold<double>(0.0, (sum, e) => sum + e.amount);

    final budgetValue = budget != null && budget > 0
        ? formatCoveCurrency(budget, currency.symbol)
        : formatCoveCurrency(monthSpent, currency.symbol);
    final budgetSub = budget != null && budget > 0
        ? 'budget this month · ${formatCoveCurrency(monthSpent, currency.symbol)} spent'
        : 'spent this month';

    final activeListsCount = lists.where((l) => !l.isArchived).length;
    final untickedCount = listItems.where((i) => !i.isCompleted).length;
    final activeHabitsCount = habits.where((h) => !h.isArchived).length;

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: CoveSpace.barClearance + bottomInset,
          ),
          child: CoveMaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CovePageHeader(
                  title: '',
                  leading: CoveRoundButton(
                    icon: Icons.arrow_back_rounded,
                    variant: CoveRoundButtonVariant.ghost,
                    semanticLabel: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  action: CoveRoundButton(
                    icon: Icons.edit_outlined,
                    variant: CoveRoundButtonVariant.ghost,
                    semanticLabel: 'Edit home',
                    onPressed: () => EditHomeDialog.show(context),
                  ),
                ),

                // 1. Arch illustration + radial glow (scrolls with the illustration)
                Column(
                  children: [
                    SizedBox(
                      width: _kGlowSize,
                      height: _kArchHeight,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    cv.accentWash,
                                    cv.surfaceCanvas.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: _kArchWidth,
                            height: _kArchHeight,
                            child: _HomeArchIllustration(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: CoveSpace.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CoveSpace.gutter,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              creatorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: CoveType.title.copyWith(
                                color: cv.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: CoveSpace.sm),
                          Text(
                            '&',
                            style: CoveType.heroFigure.copyWith(
                              color: cv.accentFill,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(width: CoveSpace.sm),
                          Flexible(
                            child: Text(
                              joinerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: CoveType.title.copyWith(
                                color: cv.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (descriptionLine.isNotEmpty) ...[
                      const SizedBox(height: CoveSpace.xs),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CoveSpace.gutter,
                        ),
                        child: Text(
                          descriptionLine,
                          textAlign: TextAlign.center,
                          style: CoveType.readout.copyWith(
                            color: cv.textTertiary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: CoveSpace.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Text(
                              togetherText,
                              style: CoveType.readout.copyWith(
                                color: cv.accentTint,
                              ),
                            ),
                            const SizedBox(height: CoveSpace.xs),
                            const CoveSectionLabel.card(label: 'Together'),
                          ],
                        ),
                        const SizedBox(width: CoveSpace.section),
                        Column(
                          children: [
                            Text(
                              inCoveText,
                              style: CoveType.readout.copyWith(
                                color: cv.accentTint,
                              ),
                            ),
                            const SizedBox(height: CoveSpace.xs),
                            const CoveSectionLabel.card(label: 'In Cove'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: CoveSpace.section),

                // 2. THIS MONTH — Four Almanac-style CoveMetricCards
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.gutter,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CoveSectionLabel.page(label: 'This month'),
                      const SizedBox(height: CoveSpace.md),
                      CoveMetricGrid(
                        children: [
                          CoveMetricCard(
                            label: 'Commitments',
                            value: '$activeCommitmentsCount',
                            subtitle: 'commitments you carry together',
                          ),
                          CoveMetricCard(
                            label: 'Budget',
                            value: budgetValue,
                            subtitle: budgetSub,
                          ),
                          CoveMetricCard(
                            label: 'Lists',
                            value: '$untickedCount',
                            subtitle:
                                'still unticked across $activeListsCount ${activeListsCount == 1 ? 'list' : 'lists'}',
                          ),
                          CoveMetricCard(
                            label: 'Habits',
                            value: '$activeHabitsCount',
                            subtitle: 'habits the two of you keep',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: CoveSpace.section),

                // 3. WHO LIVES HERE — People at CoveSize.avatarProfile, no role captions
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.gutter,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CoveSectionLabel.page(label: 'Who lives here'),
                      const SizedBox(height: CoveSpace.lg),
                      Wrap(
                        spacing: CoveSpace.section,
                        runSpacing: CoveSpace.lg,
                        children: [
                          _HouseholdPersonTile(
                            person: CovePerson.a,
                            name: creatorName,
                            isPrimary: true,
                          ),
                          _HouseholdPersonTile(
                            person: CovePerson.b,
                            name: joinerName,
                            isPrimary: false,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: CoveSpace.section),

                // 4. THIS HOME — CoveRow list
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.gutter,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CoveSectionLabel.page(label: 'This home'),
                      const SizedBox(height: CoveSpace.xs),
                      CoveRow(
                        leading: _buildLeadingOrb(context, Icons.edit_outlined),
                        title: 'Name',
                        subtitle: activeHome.name,
                        trailing: _buildChevron(context),
                        onTap: () => EditHomeDialog.show(context),
                      ),
                      if (weather != null && weather.cityName.isNotEmpty)
                        CoveRow(
                          leading: _buildLeadingOrb(
                            context,
                            Icons.place_outlined,
                          ),
                          title: 'Where',
                          subtitle: weather.cityName,
                        ),
                      CoveRow(
                        leading: _buildLeadingOrb(
                          context,
                          Icons.history_rounded,
                        ),
                        title: 'Our dates',
                        subtitle:
                            'Together $togetherText · in Cove $inCoveText',
                        trailing: _buildChevron(context),
                        onTap: () => EditHomeDialog.show(context),
                      ),
                      CoveRow(
                        leading: _buildLeadingOrb(
                          context,
                          Icons.attach_money_rounded,
                        ),
                        title: 'Currency',
                        subtitle: '${currency.symbol} · ${currency.name}',
                        trailing: _buildChevron(context),
                        onTap: () => CurrencySelectorSheet.show(context),
                      ),
                      CoveRow(
                        leading: _buildLeadingOrb(context, Icons.key_outlined),
                        title: 'Keys',
                        subtitle: 'View / Regenerate Invite QR',
                        trailing: _buildChevron(context),
                        onTap: () => _showInviteQrSheet(
                          context,
                          homeController,
                          activeHome.id,
                        ),
                      ),
                      CoveRow(
                        leading: _buildLeadingOrb(
                          context,
                          Icons.logout_rounded,
                          color: cv.statusAlertText,
                        ),
                        title: 'Leave Home',
                        subtitle: 'Remove encryption key from this device',
                        isLast: true,
                        onTap: () => _confirmLeaveHome(
                          context,
                          homeController,
                          activeHome.id,
                          activeHome.name,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: CoveSpace.section),

                // Footer tagline & encryption reassurance
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.gutter,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Two lives.\nOne calm home.',
                        textAlign: TextAlign.center,
                        style: CoveType.title.copyWith(
                          color: cv.textTertiary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: CoveSpace.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: _kFooterIconSize,
                            color: cv.textTertiary,
                          ),
                          const SizedBox(width: CoveSpace.sm),
                          Flexible(
                            child: Text(
                              'Encrypted on your phones, never on ours',
                              textAlign: TextAlign.center,
                              style: CoveType.rowSub.copyWith(
                                color: cv.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HouseholdPersonTile extends StatelessWidget {
  final CovePerson person;
  final String name;
  final bool isPrimary;

  const _HouseholdPersonTile({
    required this.person,
    required this.name,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoveAvatar.profile(
          person: person,
          nameOrInitial: name,
        ),
        const SizedBox(height: CoveSpace.sm),
        Text(
          name,
          style: CoveType.readout.copyWith(
            color: isPrimary ? cv.textPrimary : cv.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _HomeArchIllustration extends StatelessWidget {
  const _HomeArchIllustration();

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    return CustomPaint(
      painter: _HomeArchPainter(
        outerColor: cv.accentFill,
        innerColor: cv.lineStrong,
        fillTop: cv.surfaceCard,
        fillBottom: cv.surfaceCanvas,
      ),
    );
  }
}

class _HomeArchPainter extends CustomPainter {
  final Color outerColor;
  final Color innerColor;
  final Color fillTop;
  final Color fillBottom;

  static const double _kOuterStroke = 1.5;
  static const double _kInnerStroke = 1.0;
  static const double _kInset = 12.0;

  const _HomeArchPainter({
    required this.outerColor,
    required this.innerColor,
    required this.fillTop,
    required this.fillBottom,
  });

  Path _archPath(Rect rect) {
    final radius = rect.width / 2;
    return Path()
      ..moveTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top + radius)
      ..arcToPoint(
        Offset(rect.right, rect.top + radius),
        radius: Radius.circular(radius),
      )
      ..lineTo(rect.right, rect.bottom);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outerRect = Offset.zero & size;
    final innerRect = Rect.fromLTRB(
      _kInset,
      _kInset,
      size.width - _kInset,
      size.height,
    );

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          fillTop,
          fillBottom.withValues(alpha: 0.0),
        ],
      ).createShader(outerRect);

    final closedOuter = _archPath(outerRect)..close();
    canvas.drawPath(closedOuter, fillPaint);

    final outerStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kOuterStroke
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          outerColor,
          outerColor.withValues(alpha: 0.0),
        ],
      ).createShader(outerRect);
    canvas.drawPath(_archPath(outerRect), outerStrokePaint);

    final innerStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kInnerStroke
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          innerColor,
          innerColor.withValues(alpha: 0.0),
        ],
      ).createShader(innerRect);
    canvas.drawPath(_archPath(innerRect), innerStrokePaint);
  }

  @override
  bool shouldRepaint(covariant _HomeArchPainter oldDelegate) {
    return oldDelegate.outerColor != outerColor ||
        oldDelegate.innerColor != innerColor ||
        oldDelegate.fillTop != fillTop ||
        oldDelegate.fillBottom != fillBottom;
  }
}
