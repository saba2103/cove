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
