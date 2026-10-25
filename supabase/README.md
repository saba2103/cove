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

`supabase/functions/notify-partner/index.ts` branches per device based on `public.user_devices.platform`, so **deploying is safe at any time** (there is no "both phones first" prerequisite):
- **`platform === "android:data-v1"`** (registered automatically on launch by Android builds that include 3.14c+): sends a **data-only** FCM v1 message (`home_id`, `event_id`, `event_type`, `module`, Android priority `HIGH`, no `notification` block, no collapse key). The phone decrypts the event, writes the Quiet Ledger copy (`design/specs/15-notifications.md`), applies 90-second per-list batching, and shows the local notification.
- **Every other device** (`"android"`, `"ios"`, etc.): sends the **legacy** FCM v1 message exactly as `42c300a` did (`notification` block, `title`, `body`, and `collapse_key`).

The server-side silent filter (§3) applies to both paths.

### 1. Save the Currently Running Version Before Deploying
Before deploying, download the version of `notify-partner` that is actually running on Supabase (in case it differs from git) and back it up outside the tracked function directory:

```bash
# Stash or back up your local 3.14e index.ts first so download doesn't overwrite it without a copy
cp supabase/functions/notify-partner/index.ts /tmp/notify-partner.314e.index.ts

# Download the currently deployed function from Supabase
supabase functions download notify-partner --project-ref <your-project-ref>
cp supabase/functions/notify-partner/index.ts /tmp/notify-partner.running-backup.index.ts

# Restore the 3.14e version to deploy
cp /tmp/notify-partner.314e.index.ts supabase/functions/notify-partner/index.ts
```

### 2. Deploy Command
From the repository root:

```bash
supabase functions deploy notify-partner --project-ref <your-project-ref>
```

### 3. How to Roll Back
To roll back to the exact version that was running before the deploy, restore the downloaded backup (or `42c300a` from git if needed) and redeploy:

```bash
# Restore the version downloaded via `supabase functions download notify-partner`
cp /tmp/notify-partner.running-backup.index.ts supabase/functions/notify-partner/index.ts

# Redeploy the previous running version
supabase functions deploy notify-partner --project-ref <your-project-ref>

# (Optional) Return your working tree to HEAD afterwards
git checkout HEAD -- supabase/functions/notify-partner/index.ts
```

### 4. Two-Phone Verification Check
Once a phone is running a 3.14c+ build (so its row in `public.user_devices` has `platform = 'android:data-v1'`) and `notify-partner` is deployed:
1. Lock or background **Phone B**.
2. On **Phone A**, log **one expense** (e.g., `Coffee beans — dark roast` for `₹820`) and add **three items to Groceries** within 90 seconds (e.g., `Milk`, `Curd, 500g`, `Sourdough`).
3. Check **Phone B**'s notification shade:
   - You should see **one `Expenses` card** (`{Partner} logged ₹820 for Coffee beans — dark roast`).
   - You should see **one batched `Groceries` card** (`{Partner} made three changes` with the three `+ {item}` lines in `InboxStyle`).
