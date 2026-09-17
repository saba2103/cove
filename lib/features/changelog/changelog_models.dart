import 'package:flutter/material.dart';

const String kCoveCurrentAppVersion = '2.4.0';
const String kCoveLastSeenFreshVersionKey = 'cove_last_seen_fresh_version';

enum ChangelogPreviewType {
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
    required this.icon,
    required this.previewType,
    this.isFeatured = false,
  });
}

const List<ChangelogItem> kChangelogItems = [
  // 1. Helicopter View (Featured in Modal #1)
  ChangelogItem(
    id: 'helicopter_view',
    title: 'Commitments Helicopter View',
    tagline: 'See your entire year of household commitments at a single glance.',
    outcome:
        'No more surprise annual renewals or guessing who pays what month-to-month. An adaptive full-screen 12-month bird\'s-eye grid lets you plan ahead together with instant 50/50 split breakdowns and drill-down sheets.',
    underTheHood:
        'Custom LayoutBuilder aspect ratio grid (4x3), dynamic 50/50 attribution toggle, monthly/annual commitment aggregation & bottom sheet sorting.',
    category: 'Commitments',
    version: 'v2.4',
    icon: Icons.grid_view_rounded,
    previewType: ChangelogPreviewType.helicopterView,
    isFeatured: true,
  ),

  // 2. Smart Clean Decimals (Featured in Modal #2)
  ChangelogItem(
    id: 'smart_decimals',
    title: 'Clean, Clutter-Free Decimals',
    tagline: 'Financial numbers that stay calm and never shout.',
    outcome:
        'Whole currency amounts stay clean and distraction-free (like ₹250 or \$50 instead of ₹250.00), keeping exact decimal precision only when non-zero cents and paise actually matter.',
    underTheHood:
        'formatCoveAmount with integer modulo normalization across hero cards, notification payloads, list items, and expense ledgers.',
    category: 'Finances',
    version: 'v2.4',
    icon: Icons.toll_outlined,
    previewType: ChangelogPreviewType.smartDecimals,
    isFeatured: true,
  ),

  // 3. Custom Profile Studio (Featured in Modal #3)
  ChangelogItem(
    id: 'profile_studio',
    title: 'Personal Profile Studio',
    tagline: 'A warm, personalized touch for your shared sanctuary.',
    outcome:
        'Snap a camera portrait, upload from your photo roll, or switch to minimal typography initials. Your custom avatar and preferred currency persist instantly on frame 0 even when launching offline.',
    underTheHood:
        'image_picker binary upload to Supabase Storage avatars bucket, synchronous SharedPreferences frame-0 preload, and OAuth override guards.',
    category: 'Identity',
    version: 'v2.4',
    icon: Icons.portrait_rounded,
    previewType: ChangelogPreviewType.profileStudio,
    isFeatured: true,
  ),

  // 4. Human-Readable Attribution
  ChangelogItem(
    id: 'human_attribution',
    title: 'Partner-First "Paid By" Details',
    tagline: 'No more machine code or cryptic hashes in your household bills.',
    outcome:
        'Every shared commitment and expense now clearly attributes to "You" or your partner\'s actual name, keeping domestic money conversations natural and transparent.',
    underTheHood:
        'UUID regex detection and fallback resolution mapping session auth IDs and createdBy hashes to partnerProfile.displayName.',
    category: 'Commitments',
    version: 'v2.3',
    icon: Icons.person_outline_rounded,
    previewType: ChangelogPreviewType.humanAttribution,
  ),

  // 5. Silent Background Sync
  ChangelogItem(
    id: 'silent_sync',
    title: 'Quiet Background Sync',
    tagline: 'Quiet peace of mind without notification fatigue.',
    outcome:
        'Personal profile tweaks, currency changes, and internal sync events now update silently in the background without buzzing your partner’s phone with push notifications.',
    underTheHood:
        'Supabase Edge Function v3 silent event suppression & client NotificationService broadcast suppression.',
    category: 'Sync & Privacy',
    version: 'v2.3',
    icon: Icons.notifications_off_outlined,
    previewType: ChangelogPreviewType.silentSync,
  ),

  // 6. True Calendar Month Bucketing
  ChangelogItem(
    id: 'strict_renewals',
    title: 'True Month Renewal Bucketing',
    tagline: 'Know exactly what\'s due when, without false alarms.',
    outcome:
        'Renewals due next month won\'t clutter your current month\'s commitment total. Commitments strictly categorize into Overdue, This Week, This Month, Next Month, and Later.',
    underTheHood:
        'Replaced rolling 30-day lookaheads with strict calendar month boundary comparisons (DateTime.year & DateTime.month).',
    category: 'Commitments',
    version: 'v2.2',
    icon: Icons.calendar_month_outlined,
    previewType: ChangelogPreviewType.strictRenewals,
  ),

  // 7. End-to-End Encrypted Sync
  ChangelogItem(
    id: 'e2ee_sync',
    title: 'Zero-Knowledge Encrypted Sync',
    tagline: 'What happens in your home stays between the two of you.',
    outcome:
        'Your expenses, grocery lists, and daily habits are encrypted on your physical device before ever leaving it. No advertiser, server, or cloud provider can ever read your life.',
    underTheHood:
        'Libsodium XSalsa20-Poly1305 authenticated symmetric encryption with ephemeral private QR key exchange.',
    category: 'Security',
    version: 'v2.1',
    icon: Icons.lock_outline_rounded,
    previewType: ChangelogPreviewType.e2eeSync,
  ),

  // 8. Two-Tick Delivery Reassurance
  ChangelogItem(
    id: 'two_tick_sync',
    title: 'Two-Tick Delivery Reassurance',
    tagline: 'Effortless clarity on whether your partner received the update.',
    outcome:
        'One subtle tick means your item is safely stored locally on your device; two ticks means it has successfully synchronized to your partner\'s phone.',
    underTheHood:
        'Local outbox status tracking paired with real-time Supabase WebSocket delivery confirmation broadcasts.',
    category: 'Sync',
    version: 'v2.0',
    icon: Icons.done_all_rounded,
    previewType: ChangelogPreviewType.twoTickSync,
  ),

  // 9. Daily Rhythms & Mutual Cheers
  ChangelogItem(
    id: 'daily_rhythms',
    title: 'Daily Rhythms & Mutual Cheers',
    tagline: 'Celebrate the small everyday wins together.',
    outcome:
        'Track shared morning routines, reading goals, and hydration, and send gentle cheering animations when your partner completes their habit.',
    underTheHood:
        'Flexible recurrence schedules (daily, weekly, custom) with Drift local streak calculation and optimistic check-ins.',
    category: 'Rhythms',
    version: 'v2.0',
    icon: Icons.favorite_outline_rounded,
    previewType: ChangelogPreviewType.dailyRhythms,
  ),

  // 10. Instant Offline Caching & Multi-Currency
  ChangelogItem(
    id: 'offline_first',
    title: 'Offline-First Architecture & Multi-Currency',
    tagline: 'Works anywhere — even in underground grocery stores with zero signal.',
    outcome:
        'Add groceries, log expenses, and check off items completely offline. Cove writes locally and syncs automatically the moment connectivity returns, with full INR, USD, EUR, GBP, and JPY support.',
    underTheHood:
        'Local-first Drift SQLite database, optimistic mutation pipeline with outbox queues, and multi-currency formatting.',
    category: 'Architecture',
    version: 'v1.9',
    icon: Icons.wifi_off_rounded,
    previewType: ChangelogPreviewType.offlineFirst,
  ),
];
