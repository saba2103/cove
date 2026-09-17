# Cove: Complete Launch, Costing & Maintenance Guide

This document provides a comprehensive operational, infrastructure, and financial blueprint for launching, scaling, and maintaining **Cove**.

---

## 1. Executive Summary: The Local-First Cost Advantage

In traditional cloud apps (like Splitwise, Notion, or Mint), every screen view, list filter, and query hits a remote server. As user count grows, hosting bills explode due to database compute, API gateways, and egress bandwidth.

**Cove is built with a Local-First, Zero-Knowledge architecture:**
1. **On-Device SQLite (`Drift`)**: 100% of reads, list displays, balance calculations, and searches happen locally on the user's phone in microseconds.
2. **Zero Cloud Query Load**: The cloud backend never executes heavy queries or analytics.
3. **Backend is Only an Encrypted Event Relay**: Supabase simply stores encrypted sync events (`home_events`) and routes push notifications to the partner.
4. **Minimal Bandwidth**: An active couple creating 10 entries/day uses less than **25 KB of bandwidth per day**.

> [!NOTE]
> Because of this architecture, **infrastructure costs are 90–95% lower** than traditional SaaS applications.

---

## 2. Component Breakdown: What is Free vs What Costs

| Component | Provider | Free or Paid? | Free Tier Limits | When Does It Cost? |
| :--- | :--- | :--- | :--- | :--- |
| **App Framework** | Flutter (Dart) | **100% Free** | Open-source (BSD 3-Clause) | Never |
| **Local DB & Crypto** | SQLite (Drift) + libsodium | **100% Free** | Local embedded engine | Never |
| **Push Notifications (Android)** | Firebase Cloud Messaging (FCM) | **100% Free** | **Unlimited** push notifications forever | Never (FCM is permanently free with no tier limits) |
| **Push Notifications (iOS)** | Apple Push Notification service (APNs) | **Included in Apple Dev** | Unlimited push notifications | Included in the annual Apple Developer Program |
| **Cloud Database & Auth** | Supabase | **Free Tier Available** | **50,000 Monthly Active Users (MAU)**<br>500 MB database storage<br>5 GB bandwidth egress<br>500,000 Edge Function calls/month | **\$25/month** for Pro plan (recommended for production to prevent auto-pausing and enable automated point-in-time recovery) |
| **Web App Hosting** | Cloudflare Pages / Vercel | **100% Free** | Unlimited bandwidth (Cloudflare) / 100 GB (Vercel) | Free tier easily supports millions of hits for static web files |
| **Custom Domain** | Namecheap / Cloudflare Registrar | **Costs \$10 – \$14 / year** | None | Annual registration for `yourdomain.com` |
| **SSL / HTTPS Certificate** | Cloudflare / Let's Encrypt | **100% Free** | Unlimited auto-renewing certificates | Never |
| **Google Play Developer Account** | Google Play Console | **\$25 One-Time Fee** | Lifetime access to publish Android apps | One-time registration fee (never recurs) |
| **Apple Developer Program** | Apple Developer Portal | **\$99 / Year** | Required to publish on the iOS App Store & sign APNs | Annual subscription required by Apple |
| **Uptime Monitoring & Heartbeat** | BetterStack / Uptime Kuma | **100% Free** | 10 monitors, 3-minute checks | Free tier is more than adequate |
| **Crash Reporting & Error Tracking**| Firebase Crashlytics / Sentry | **100% Free** | Crashlytics: 100% free unlimited.<br>Sentry: 5,000 errors/month free | Paid only if exceeding 50,000 errors/mo on Sentry |
| **CI/CD Automated Builds** | GitHub Actions | **100% Free** | 2,000 build minutes/month for private repos | Free tier builds ~40-60 APKs/month |

---

## 3. Scale & Cost Projections Across User Scales

Cove is built for pairs: **every home consists of 2 users (1 couple)**.

* **Bandwidth / Egress per user**: ~2 MB / month (tiny encrypted JSON event payloads).
* **Database storage**: ~1 MB per couple per year (events + metadata).
* **Edge Function invocations**: ~300 calls per couple per month (notifying partner on inserts).

```
10 Users    = 5 Couples
20 Users    = 10 Couples
100 Users   = 50 Couples
1,000 Users = 500 Couples
10,000 Users = 5,000 Couples
50,000 Users = 25,000 Couples
```

---

### Tier 1: Friends & Family (10 to 100 Users / 5 to 50 Couples)
* **Supabase**: **\$0/month** (Free Tier covers up to 50,000 MAU; 100 users consume <0.2% of allowance).
* **Firebase (FCM)**: **\$0**.
* **Web Hosting**: **\$0** (Cloudflare Pages / Vercel).
* **Monitoring & Crash Tracking**: **\$0**.
* **Store Fees**: \$25 one-time (Google) + \$99/year (Apple).
* **Domain**: ~\$12/year.

> **Monthly Operational Cost**: **\$0 / month**  
> **Annual Fixed Overheads**: **\$111 / year** (Apple Dev + Domain)

---

### Tier 2: Public Launch / Early Growth (1,000 Users / 500 Couples)
* **Supabase Pro**: **\$25/month** (Required for guaranteed 99.9% uptime, no project sleeping, and 7-day daily automated backups).
  - *Included in Pro*: 8 GB database, 250 GB egress, 2M Edge Function invocations, 100,000 MAUs.
  - *Actual usage*: ~0.5 GB storage, ~5 GB egress, ~150,000 Edge Function calls. Well within base limits.
* **Firebase (FCM)**: **\$0**.
* **Web Hosting & SSL**: **\$0**.
* **Monitoring**: **\$0** (BetterStack free tier).

> **Monthly Operational Cost**: **\$25 / month** (₹2,100/mo)  
> **Annual Total**: **\$411 / year** (including Apple Dev & Domain)  
> **Cost per active couple**: **\$0.068 / month** (~5.5 rupees/couple/mo)

---

### Tier 3: Medium Scale (5,000 Users / 2,500 Couples)
* **Supabase Pro Base**: **\$25/month**.
* **Supabase Compute Upgrade**: Micro compute is included; upgrade to Small compute (2 vCPU, 2 GB RAM) for extra concurrency headroom $\to$ **+\$10/month**.
* **Storage**: 2,500 couples $\times$ 3 MB = 7.5 GB (within 8 GB included $\to$ **\$0**).
* **Edge Functions**: 2,500 $\times$ 300 = 750,000 calls (within 2M included $\to$ **\$0**).
* **Egress**: 25 GB (within 250 GB included $\to$ **\$0**).
* **Firebase (FCM)**: **\$0**.

> **Monthly Operational Cost**: **\$35 / month** (₹2,950/mo)  
> **Annual Total**: **\$531 / year**  
> **Cost per active couple**: **\$0.017 / month** (~1.4 rupees/couple/mo)

---

### Tier 4: Scaling Up (10,000 Users / 5,000 Couples)
* **Supabase Pro Base + Small Compute**: **\$35/month**.
* **Database Storage**: 5,000 couples $\times$ 5 MB = 25 GB (8 GB included + 17 GB $\times$ \$0.125/GB = **+\$2.12/month**).
* **Edge Functions**: 5,000 $\times$ 300 = 1.5M calls (within 2M included $\to$ **\$0**).
* **Egress**: 50 GB (within 250 GB included $\to$ **\$0**).
* **Sentry (Crash/Performance Monitoring)**: **+\$26/month** (Team tier for deeper tracing).

> **Monthly Operational Cost**: **~\$63 / month** (₹5,300/mo)  
> **Annual Total**: **\$867 / year**  
> **Cost per active couple**: **\$0.014 / month** (~1.1 rupees/couple/mo)

---

### Tier 5: High Scale (50,000 Users / 25,000 Couples)
* **Supabase Pro + Medium Compute (2 vCPU, 4 GB RAM)**: **\$25 + \$50 = \$75/month**.
* **Database Storage**: ~100 GB $\to$ **+\$11.50/month**.
* **Edge Functions**: 7.5M invocations (2M included + 5.5M $\times$ \$2/million = **+\$11.00/month**).
* **Egress**: ~250 GB $\to$ Included in plan.
* **Transactional Email (Resend/Postmark)**: **+\$20/month**.
* **Sentry / Monitoring**: **+\$26/month**.

> **Monthly Operational Cost**: **~\$143.50 / month** (₹12,000/mo)  
> **Annual Total**: **\$1,827 / year**  
> **Cost per active couple**: **\$0.0057 / month** (less than half a cent / ~45 paise per couple/mo)

---

## 4. Cost Matrix Overview

| Scale | Couples | Monthly Cloud Infra Cost | Annual App Store & Domain | Total Annual Spend | Cost / Couple / Month |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **10 – 100 Users** | 5 – 50 | **\$0 / mo** | \$111 / yr | **\$111 / yr** | ~\$0.18 |
| **1,000 Users** | 500 | **\$25 / mo** | \$111 / yr | **\$411 / yr** | **\$0.068** |
| **5,000 Users** | 2,500 | **\$35 / mo** | \$111 / yr | **\$531 / yr** | **\$0.017** |
| **10,000 Users** | 5,000 | **\$63 / mo** | \$111 / yr | **\$867 / yr** | **\$0.014** |
| **50,000 Users** | 25,000 | **\$143 / mo** | \$111 / yr | **\$1,827 / yr** | **\$0.006** |

---

## 5. Step-by-Step Launch Plan

### Phase 1: Accounts & Registrations
1. **Google Play Console**:
   - Register at [play.google.com/console](https://play.google.com/console) (\$25 one-time).
   - Complete personal or organizational identity verification.
   - *Requirement for new personal accounts*: Google Play mandates a 14-day closed test with at least 12 opt-in testers before publishing to production.
2. **Apple Developer Program**:
   - Register at [developer.apple.com](https://developer.apple.com) (\$99/year).
   - Requires Apple ID with 2FA; D-U-N-S number needed if registering as a company.
3. **Legal Compliance**:
   - Host a **Privacy Policy** and **Terms of Service** (mandatory for store submissions).
   - Cove's privacy policy is straightforward: *"All financial, list, and calendar records are client-side encrypted on user devices using libsodium and never inspected or monetized."*
   - Can be hosted for free on Cloudflare Pages, GitHub Pages, or Notion.

### Phase 2: Backend Production Hardening
1. **Upgrade Supabase to Pro (\$25/mo)**:
   - Prevents project auto-pausing after 7 days of inactivity.
   - Enables daily automated backups with 7-day Point-In-Time-Recovery (PITR).
2. **Automated Maintenance Routine**:
   - Set up an automatic retention cleanup for delivered event receipts:
     ```sql
     -- Cleans delivery acknowledgements older than 90 days to keep the database small
     DELETE FROM public.event_deliveries WHERE delivered_at < now() - INTERVAL '90 days';
     ```

### Phase 3: Push Notification Verification
1. **Android (FCM)**:
   - `google-services.json` already placed in `android/app/google-services.json`.
   - FCM v1 service account credentials already stored in Supabase secrets (`FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`).
   - `user_devices` table and `trigger_notify_partner` already active in Supabase.
2. **iOS (APNs)**:
   - In Apple Developer Portal, generate a `.p8` key under *Certificates, Identifiers & Profiles > Keys > Apple Push Notifications service (APNs)*.
   - Upload the `.p8` key, Key ID, and Team ID into Firebase Console under *Project Settings > Cloud Messaging > Apple app configuration*.

### Phase 4: App Packaging & Signing
1. **Android Release**:
   - Create release keystore:
     ```bash
     keytool -genkey -v -keystore cove-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cove
     ```
   - Build Android App Bundle (`.aab`):
     ```bash
     flutter build appbundle --release
     ```
2. **iOS Release**:
   - Open `ios/Runner.xcworkspace` in Xcode.
   - Set Signing Team and Bundle Identifier (`com.app.cove`).
   - Archive and upload to TestFlight / App Store Connect.
3. **Web Release**:
   - Build optimized web files:
     ```bash
     flutter build web --release
     ```
   - Deploy `build/web` to Cloudflare Pages (connects directly to GitHub repo for automatic continuous deployment).

### Phase 5: Monitoring & Day-to-Day Maintenance
* **Uptime Monitoring**: Add a free monitor on [BetterStack](https://betterstack.com) pinging `https://<supabase-id>.supabase.co/functions/v1/notify-partner` every 3 minutes.
* **Error Tracking**: Firebase Crashlytics automatically logs unhandled exceptions, device models, and OS versions with zero cost.
* **Maintenance Schedule**:
  - **Monthly**: Check database size and event delivery table cleanup.
  - **Quarterly**: Run `flutter pub outdated` and update minor dependencies.
  - **Annually**: Renew Apple Developer membership (\$99) and domain name (~$12).
