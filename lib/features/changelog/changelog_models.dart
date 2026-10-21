import 'package:flutter/material.dart';

const String kCoveCurrentAppVersion = '2.0.0-alpha.1';
const String kCoveLastSeenFreshVersionKey = 'cove_last_seen_fresh_version';

enum ChangelogPreviewType {
  calendarFirst,
  helicopterView,
  smartDecimals,
  profileStudio,
  humanAttribution,
  silentSync,
  strictRenewals,
  e2eeSync,
  twoTickSync,
  dailyRhythms,
  offlineFirst,
}

class ChangelogItem {
  final String id;
  final String title;
  final String tagline;
  final String outcome;
  final String underTheHood;
  final String category;
  final String version;
  final String date;
  final IconData icon;
  final ChangelogPreviewType previewType;
  final bool isFeatured;

  const ChangelogItem({
    required this.id,
    required this.title,
    required this.tagline,
    required this.outcome,
    required this.underTheHood,
    required this.category,
    required this.version,
    required this.date,
    required this.icon,
    required this.previewType,
    this.isFeatured = false,
  });
}

const List<ChangelogItem> kChangelogItems = [
  // 0. v2.0-alpha.1 — The Design System
  ChangelogItem(
    id: 'v2_design_system',
    title: 'v2.0-alpha.1 — The Design System',
    tagline:
        'DTCG token pipeline with generated Dart, WCAG AA contrast, Plus Jakarta Sans & Libre Bodoni typography, and automated quality gates.',
    outcome:
        'Both light and dark modes now run on a unified W3C DTCG design token system with verified WCAG AA contrast across every surface and text pairing. Plus Jakarta Sans replaces General Sans for UI legibility, and Libre Bodoni replaces Bodoni Moda for display titles and hero/card figures with native ₹ glyph support.',
    underTheHood:
        'DTCG token pipeline (design/tokens.json → tool/gen_tokens.dart → CoveTokens, CoveSpace, CoveSize, CoveRadius, CoveType, CoveMotion) serving both light and dark modes, WCAG AA contrast fixes, Plus Jakarta Sans for UI, Libre Bodoni for display and figures, and quality gates (contrast check, style ratchet, version agreement, 84 multi-viewport goldens, and 17-table Drift v11 schema migration test).',
    category: 'Design & Architecture',
    version: 'v2.0-alpha.1',
    date: 'Oct 22, 2026',
    icon: Icons.palette_outlined,
    previewType: ChangelogPreviewType.smartDecimals,
  ),
  // -1. Home-Scoped Properties SQLite Persistence & Cross-Device Sync (v1.0-alpha.1)
  ChangelogItem(
    id: 'home_scoped_properties_sync',
    title: 'Home-Scoped Budget, Currency & Reminders',
    tagline: 'Monthly budgets, currency, anniversary dates, and check-in reminders now permanently persist and sync.',
    outcome:
        'Your sanctuary settings—including monthly expense budget caps, preferred home currency, anniversary milestones, and domestic check-in reminders—are now stored directly in SQLite and synced across partner devices with zero data loss.',
    underTheHood:
        'Drift schema v11 with LocalHomes budget/anniversary columns, dedicated LocalCheckinReminders table, reactive stream projections, and transparent legacy storage migration.',
    category: 'Sync & Settings',
    version: 'v1.0-alpha.1',
    date: 'Sep 25, 2026',
    icon: Icons.sync_rounded,
    previewType: ChangelogPreviewType.silentSync,
  ),

  // 0a. Notification Deep Linking to Exact Detail Bottom Sheets (v1.0-alpha.1)
  ChangelogItem(
    id: 'notification_detail_deep_links',
    title: 'Contextual Notification Deep Linking',
    tagline: 'Tapping a push notification now opens the exact item bottom sheet directly.',
    outcome:
        'When you tap a push or in-app notification about an expense, commitment, or list update, Cove opens the exact entity detail bottom sheet on top of the screen instead of leaving you on a generic page.',
    underTheHood:
        'Entity ID payload parsing in NotificationService, NotificationDetailDispatcher lookup against Drift SQLite, and automatic navigation stack clearance.',
    category: 'Navigation',
    version: 'v1.0-alpha.1',
    date: 'Sep 25, 2026',
    icon: Icons.notifications_active_outlined,
    previewType: ChangelogPreviewType.dailyRhythms,
  ),

  // 0. EMI Tracker, Foreclosure & Sync Delivery Fix (v1.0-alpha.1)
  ChangelogItem(
    id: 'emi_tracker_and_closure',
    title: 'EMI Tracker & Loan Foreclosure',
    tagline: 'Track loan burdens, simulate payoff scenarios, and foreclose with ease.',
    outcome:
        'A dedicated overview for all household EMIs with total outstanding, monthly burden, payoff simulation on multi-select, one-tap foreclosure confirmation, and guaranteed two-tick sync reconciliation.',
    underTheHood:
        'Bodoni Moda hero burden card, sticky MultiSelectBurdenBar, foreclosure projection controller with optional expense ledger entry, and persistent Supabase delivery receipt reconciliation.',
    category: 'Commitments',
    version: 'v1.0-alpha.1',
    date: 'Sep 20, 2026',
    icon: Icons.account_balance_wallet_outlined,
    previewType: ChangelogPreviewType.helicopterView,
    isFeatured: true,
  ),

  // 1. Calendar-First Architecture & Today Home (v1.0-alpha.1)
  ChangelogItem(
    id: 'calendar_first_restructure',
    title: 'Calendar-First Sanctuary & Today Home',
    tagline: 'The calendar now opens first and carries everything dated.',
    outcome:
        'Cove launches directly into your day on the calendar, carrying five quiet layers: events, commitments, money, rhythms, and tasks. Today is now your home tab, gathering monthly spend totals, shared list pills, and recent activity into one calm flow.',
    underTheHood:
        'Unified 5-layer calendar provider, additive due-date database schema, Day view layer filters, Bodoni time gutters, and retired Dashboard architecture.',
    category: 'Architecture',
    version: 'v1.0-alpha.1',
    date: 'Sep 19, 2026',
    icon: Icons.calendar_month_rounded,
    previewType: ChangelogPreviewType.calendarFirst,
    isFeatured: true,
  ),

  // 2. Helicopter View (Featured in Modal #1)
  ChangelogItem(
    id: 'helicopter_view',
    title: 'Commitments Helicopter View',
    tagline: 'See your entire year of household commitments at a single glance.',
    outcome:
        'No more surprise annual renewals or guessing who pays what month-to-month. An adaptive full-screen 12-month bird\'s-eye grid lets you plan ahead together with instant 50/50 split breakdowns and drill-down sheets.',
    underTheHood:
        'Custom LayoutBuilder aspect ratio grid (4x3), dynamic 50/50 attribution toggle, monthly/annual commitment aggregation & bottom sheet sorting.',
    category: 'Commitments',
    version: 'v0.6-alpha',
    date: 'Sep 17, 2026',
    icon: Icons.grid_view_rounded,
    previewType: ChangelogPreviewType.helicopterView,
    isFeatured: true,
  ),

  // 3. Smart Clean Decimals (Featured in Modal #2)
  ChangelogItem(
    id: 'smart_decimals',
    title: 'Clean, Clutter-Free Decimals',
    tagline: 'Financial numbers that stay calm and never shout.',
    outcome:
        'Whole currency amounts stay clean and distraction-free (like ₹250 or \$50 instead of ₹250.00), keeping exact decimal precision only when non-zero cents and paise actually matter.',
    underTheHood:
        'formatCoveAmount with integer modulo normalization across hero cards, notification payloads, list items, and expense ledgers.',
    category: 'Finances',
    version: 'v0.6-alpha',
    date: 'Sep 17, 2026',
    icon: Icons.toll_outlined,
    previewType: ChangelogPreviewType.smartDecimals,
  ),

  // 4. Custom Profile Studio (Featured in Modal #3)
  ChangelogItem(
    id: 'profile_studio',
    title: 'Personal Profile Studio',
    tagline: 'A warm, personalized touch for your shared sanctuary.',
    outcome:
        'Snap a camera portrait, upload from your photo roll, or switch to minimal typography initials. Your custom avatar and preferred currency persist instantly on frame 0 even when launching offline.',
    underTheHood:
        'image_picker binary upload to Supabase Storage avatars bucket, synchronous SharedPreferences frame-0 preload, and OAuth override guards.',
    category: 'Identity',
    version: 'v0.6-alpha',
    date: 'Sep 17, 2026',
    icon: Icons.portrait_rounded,
    previewType: ChangelogPreviewType.profileStudio,
  ),

  // 5. Human-Readable Attribution
  ChangelogItem(
    id: 'human_attribution',
    title: 'Partner-First "Paid By" Details',
    tagline: 'No more machine code or cryptic hashes in your household bills.',
    outcome:
        'Every shared commitment and expense now clearly attributes to "You" or your partner\'s actual name, keeping domestic money conversations natural and transparent.',
    underTheHood:
        'UUID regex detection and fallback resolution mapping session auth IDs and createdBy hashes to partnerProfile.displayName.',
    category: 'Commitments',
    version: 'v0.5-alpha',
    date: 'Sep 17, 2026',
    icon: Icons.person_outline_rounded,
    previewType: ChangelogPreviewType.humanAttribution,
  ),

  // 6. Silent Background Sync
  ChangelogItem(
    id: 'silent_sync',
    title: 'Quiet Background Sync',
    tagline: 'Quiet peace of mind without notification fatigue.',
    outcome:
        'Personal profile tweaks, currency changes, and internal sync events now update silently in the background without buzzing your partner’s phone with push notifications.',
    underTheHood:
        'Supabase Edge Function v3 silent event suppression & client NotificationService broadcast suppression.',
    category: 'Sync & Privacy',
    version: 'v0.5-alpha',
    date: 'Sep 16, 2026',
    icon: Icons.notifications_off_outlined,
    previewType: ChangelogPreviewType.silentSync,
  ),

  // 7. True Calendar Month Bucketing
  ChangelogItem(
    id: 'strict_renewals',
    title: 'True Month Renewal Bucketing',
    tagline: 'Know exactly what\'s due when, without false alarms.',
    outcome:
        'Renewals due next month won\'t clutter your current month\'s commitment total. Commitments strictly categorize into Overdue, This Week, This Month, Next Month, and Later.',
    underTheHood:
        'Replaced rolling 30-day lookaheads with strict calendar month boundary comparisons (DateTime.year & DateTime.month).',
    category: 'Commitments',
    version: 'v0.4-alpha',
    date: 'Sep 17, 2026',
    icon: Icons.calendar_month_outlined,
    previewType: ChangelogPreviewType.strictRenewals,
  ),

  // 8. End-to-End Encrypted Sync
  ChangelogItem(
    id: 'e2ee_sync',
    title: 'Zero-Knowledge Encrypted Sync',
    tagline: 'What happens in your home stays between the two of you.',
    outcome:
        'Your expenses, grocery lists, and daily habits are encrypted on your physical device before ever leaving it. No advertiser, server, or cloud provider can ever read your life.',
    underTheHood:
        'Libsodium XSalsa20-Poly1305 authenticated symmetric encryption with ephemeral private QR key exchange.',
    category: 'Security',
    version: 'v0.3-alpha',
    date: 'Sep 17, 2026',
    icon: Icons.lock_outline_rounded,
    previewType: ChangelogPreviewType.e2eeSync,
  ),

  // 9. Two-Tick Delivery Reassurance
  ChangelogItem(
    id: 'two_tick_sync',
    title: 'Two-Tick Delivery Reassurance',
    tagline: 'Effortless clarity on whether your partner received the update.',
    outcome:
        'One subtle tick means your item is safely stored locally on your device; two ticks means it has successfully synchronized to your partner\'s phone.',
    underTheHood:
        'Local outbox status tracking paired with real-time Supabase WebSocket delivery confirmation broadcasts.',
    category: 'Sync',
    version: 'v0.2-alpha',
    date: 'Sep 10, 2026',
    icon: Icons.done_all_rounded,
    previewType: ChangelogPreviewType.twoTickSync,
  ),

  // 10. Daily Rhythms & Mutual Cheers
  ChangelogItem(
    id: 'daily_rhythms',
    title: 'Daily Rhythms & Mutual Cheers',
    tagline: 'Celebrate the small everyday wins together.',
    outcome:
        'Track shared morning routines, reading goals, and hydration, and send gentle cheering animations when your partner completes their habit.',
    underTheHood:
        'Flexible recurrence schedules (daily, weekly, custom) with Drift local streak calculation and optimistic check-ins.',
    category: 'Rhythms',
    version: 'v0.2-alpha',
    date: 'Sep 8, 2026',
    icon: Icons.favorite_outline_rounded,
    previewType: ChangelogPreviewType.dailyRhythms,
  ),

  // 11. Instant Offline Caching & Multi-Currency
  ChangelogItem(
    id: 'offline_first',
    title: 'Offline-First Architecture & Multi-Currency',
    tagline: 'Works anywhere — even in underground grocery stores with zero signal.',
    outcome:
        'Add groceries, log expenses, and check off items completely offline. Cove writes locally and syncs automatically the moment connectivity returns, with full INR, USD, EUR, GBP, and JPY support.',
    underTheHood:
        'Local-first Drift SQLite database, optimistic mutation pipeline with outbox queues, and multi-currency formatting.',
    category: 'Architecture',
    version: 'v0.1-alpha',
    date: 'Sep 5, 2026',
    icon: Icons.wifi_off_rounded,
    previewType: ChangelogPreviewType.offlineFirst,
  ),
];
