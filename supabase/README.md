# Cove Supabase Backend Setup

Cove utilizes Supabase strictly as an **encrypted blind relay** and **store-and-forward mailbox**. No unencrypted household data (item names, amounts, habits, dates) ever touches Supabase.

---

## 1. Local Supabase Setup (via CLI)

If you are running Supabase locally using the Supabase CLI:

```bash
# 1. Initialize Supabase if not already done
supabase init

# 2. Start local Supabase containers (Docker required)
supabase start

# 3. Apply the Cove schema migration
supabase db execute --file supabase/schema.sql
```

Once running, the CLI outputs your local API URL and anon key:
```env
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=eyJhbGciOi...
```

---

## 2. Supabase Cloud Setup

1. Create a new project at [database.new](https://database.new).
2. Open the **SQL Editor** in your Supabase Dashboard.
3. Paste the contents of [`supabase/schema.sql`](./schema.sql) and click **Run**.
4. In **Project Settings > API**, copy your:
   - **Project URL**
   - **anon / public key**
5. In **Authentication > Providers**, enable **Google** provider if using Google Sign-In.

---

## 3. Configuring the Flutter App

Provide your Supabase URL and anon key via environment flags when running or building:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Or configure your local configuration file / `.env` in later missions.

---

## 4. Architecture Summary

| Table | Purpose | Security |
|---|---|---|
| `public.homes` | Metadata for shared households | RLS: visible only to members. |
| `public.home_members` | Join table connecting users to homes | RLS: users join via pairing; multi-home enabled. |
| `public.home_events` | Append-only encrypted event stream | RLS: only home members can read/insert. Payload encrypted client-side. |
| `public.event_deliveries` | Acknowledgment receipts for two-tick delivery | RLS: members confirm receipt with their own user ID. |

---

## 5. Deploying `notify-partner`

`supabase/functions/notify-partner/index.ts` sends **data-only** FCM v1 messages (`home_id`, `event_id`, `event_type`, `module` — with no `notification` block, no title or body, no collapse key, and Android priority `HIGH`). The receiving phone decrypts the event, composes the Quiet Ledger copy (`design/specs/15-notifications.md`), applies 90-second per-list batching, and renders the local notification.

### Prerequisite
**Both phones must already be running an app build that includes 3.14c** (`624b3de` / `a60c7ba` / `662ec23`) before deploying `notify-partner`. Older builds ignore data-only FCM messages and rely on the server-provided `notification` block, so deploying `notify-partner` before updating both phones would stop notifications on whichever phone has not been updated yet.

### Deploy Command
From the repository root:

```bash
supabase functions deploy notify-partner --project-ref <your-project-ref>
```

### How to Roll Back
If either phone is still on a pre-3.14c build or you need to restore the legacy server-rendered `notification` payload, check out the previous version of `supabase/functions/notify-partner/index.ts` from commit `42c300a` (`42c300ae13d7919b285615837050d18416fff854` — or the commit immediately preceding 3.14d, `624b3de`) and redeploy:

```bash
# Restore the previous version of notify-partner from commit 42c300a
git checkout 42c300a -- supabase/functions/notify-partner/index.ts

# Redeploy to Supabase
supabase functions deploy notify-partner --project-ref <your-project-ref>

# When ready to return to the 3.14d version in your working tree:
git checkout HEAD -- supabase/functions/notify-partner/index.ts
```

### Two-Phone Verification Check
Once both phones run a build with 3.14c and `notify-partner` is deployed:
1. Lock or background **Phone B**.
2. On **Phone A**, log **one expense** (e.g., `Coffee beans — dark roast` for `₹820`) and add **three items to Groceries** within 90 seconds (e.g., `Milk`, `Curd, 500g`, `Sourdough`).
3. Check **Phone B**'s notification shade:
   - You should see **one `Expenses` card** (`{Partner} logged ₹820 for Coffee beans — dark roast`).
   - You should see **one batched `Groceries` card** (`{Partner} made three changes` with the three `+ {item}` lines in `InboxStyle`).
