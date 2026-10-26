# 17 — Invites and keys

**The rule:** the home key leaves a phone in exactly two ways: inside an in-person QR code, or
sealed for one specific phone that the owner approved. It never reaches the server readable,
and nothing ever invents a new key for an existing home.

## What's wrong today (found 26 Oct)

1. `createPairingCode` uploads the full pairing payload, **including the home key in base64**,
   to `pairing_codes.payload` for 10 minutes. If that table is missing, it writes the payload
   into `homes.description`, where nothing clears it.
2. A 6-digit code is the only thing protecting it, and it can be guessed.
3. `SyncEngineImpl.start` (and the join path near line 360) "self-heals" a missing key by
   generating a new one. A phone that lost its key would then quietly encrypt with a key its
   partner can't read, and fork the home.

## 1. Joining with a code — approved on the inviter's phone

Libsodium's `crypto_box` keypairs and sealed boxes (already a dependency).

1. **The inviter (A)** taps Send a key. The app creates a `pairing_codes` row: `code` (6
   digits, CSPRNG), `home_id`, `inviter_id`, `expires_at` (now + 10 min), `status = 'open'`.
   **No payload, no key.**
2. **The joiner (B)** types the code. B's phone generates a fresh keypair and writes a
   `pairing_requests` row: `code`, `joiner_id`, `joiner_name`, `joiner_public_key`,
   `status = 'pending'`. A code accepts at most 3 requests, and is single-use once approved.
3. **Both phones show the same two words**, derived from
   `SHA-256(joiner_public_key ‖ code)`: the first 22 bits pick two words from a fixed
   2,048-word list, rendered like `AMBER · HARBOUR`. B's phone shows "Ask {A} to check these
   words."
4. **A's phone** gets a sheet (realtime while open; a push otherwise): "{B} wants to join {home}.
   Do these words match on their phone? AMBER · HARBOUR" with **Let them in** / **Not them**.
5. On **Let them in**, A seals the pairing payload (home id, name, key, inviter) to B's
   public key (`crypto_box_seal`) and writes only the sealed blob to the request,
   `status = 'approved'`.
6. B opens it with its secret key, saves the home key, joins as today, then sets
   `status = 'done'`. A server-side job (or the next app open) deletes done and expired
   rows.

If the server swaps B's public key, the words don't match and A taps Not them. Guessing a code
gets an attacker a request A will decline. The server only ever holds public keys and a
sealed blob it can't open.

## 2. The QR code

The in-person QR keeps carrying the payload directly from A's screen to B's camera. It
never touches the server. The QR view must stop calling `createPairingCode` for the payload. It
may show A's 6-digit code next to the QR (from step 1, keyless).

## 3. A missing key is a restore, not a new key

Remove the self-heal in `SyncEngineImpl.start` and in the join path. If the active home has no
key on this phone, sync doesn't start, and the app shows a full-screen state:

> **This phone doesn't have your home's key.**
> Restore it from your Drive backup, or ask {partner} to send a key again.
> [Restore from backup] [Join again with a code]

Never generate a key except in "create a home".

## 4. Server changes (Supabase)

- A migration in `supabase/migrations/`:
  - drop `pairing_codes.payload`
  - add `pairing_codes.status`
  - create `pairing_requests` with RLS: B inserts its own request; A reads and updates requests
    for its own codes; B reads its own request
- Delete every existing `pairing_codes` row (they hold keys).
- Clear `homes.description` wherever it starts with `pairing:`.
- Remove the `homes.description` fallback from the app.
- These run with `supabase db push`, after Saba approves the SQL.

## 5. Compatibility

Ancy's phone may still run the old app for a while. The old app can't join with a code after
this, which is fine: nobody is joining. Old code rows are deleted. QR joining keeps working
for both.
