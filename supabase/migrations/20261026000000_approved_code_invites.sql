-- ==============================================================================
-- Cove Approved-Code Invites Migration (17-invite-and-keys.md §1, §4)
--
-- Creates keyless `public.pairing_codes` and `public.pairing_requests` with
-- strict RLS, rate limiting, and immutability triggers:
-- - `pairing_codes` has no payload column and is readable/deletable ONLY by its
--   inviter (`inviter_id = auth.uid()`).
-- - Joiners check a code exclusively via `lookup_pairing_code(code)`
--   (`SECURITY DEFINER`), which returns only `(home_name, inviter_name, status)`
--   for an open, unexpired code, and counts failed lookups per user (max 5/hour).
-- - One user may make at most 5 pairing requests per hour (checked in
--   `can_insert_pairing_request`), and a code accepts at most 3 requests.
-- - A `BEFORE UPDATE` trigger on `pairing_requests` makes `code`, `joiner_id`,
--   and `joiner_public_key` immutable after insert; the joiner may only set
--   `status = 'done'`, and only the inviter may set `sealed_payload`,
--   `status = 'approved'`, or `status = 'declined'`.
-- - Delete policy on `pairing_requests`: only the joiner or the code's inviter.
-- ==============================================================================

-- 1. Safety cleanup: clear any legacy `pairing:` tags in `homes.description`.
UPDATE public.homes
SET description = NULL
WHERE description LIKE 'pairing:%';

-- 2. Keyless `pairing_codes` table (no payload, no key).
CREATE TABLE IF NOT EXISTS public.pairing_codes (
  code TEXT PRIMARY KEY CHECK (code ~ '^[0-9]{6}$'),
  home_id TEXT NOT NULL REFERENCES public.homes(id) ON DELETE CASCADE,
  inviter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'approved', 'expired')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pairing_codes_home_id
  ON public.pairing_codes(home_id);
CREATE INDEX IF NOT EXISTS idx_pairing_codes_expires_at
  ON public.pairing_codes(expires_at);

ALTER TABLE public.pairing_codes ENABLE ROW LEVEL SECURITY;

-- Inviter creates a keyless code for a home they belong to.
DROP POLICY IF EXISTS "Inviters can insert their own pairing codes" ON public.pairing_codes;
CREATE POLICY "Inviters can insert their own pairing codes"
  ON public.pairing_codes
  FOR INSERT
  TO authenticated
  WITH CHECK (
    inviter_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.home_members hm
      WHERE hm.home_id = pairing_codes.home_id
         AND hm.user_id = auth.uid()
    )
  );

-- Only the inviter can read their own pairing codes.
DROP POLICY IF EXISTS "Inviters can read their own pairing codes" ON public.pairing_codes;
CREATE POLICY "Inviters can read their own pairing codes"
  ON public.pairing_codes
  FOR SELECT
  TO authenticated
  USING (inviter_id = auth.uid());

-- Only the inviter can update status on their own pairing codes.
DROP POLICY IF EXISTS "Inviters can update their own pairing codes" ON public.pairing_codes;
CREATE POLICY "Inviters can update their own pairing codes"
  ON public.pairing_codes
  FOR UPDATE
  TO authenticated
  USING (inviter_id = auth.uid())
  WITH CHECK (inviter_id = auth.uid());

-- Only the inviter can delete their own pairing codes.
DROP POLICY IF EXISTS "Only inviter can delete own pairing codes" ON public.pairing_codes;
CREATE POLICY "Only inviter can delete own pairing codes"
  ON public.pairing_codes
  FOR DELETE
  TO authenticated
  USING (inviter_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.pairing_codes TO authenticated;

-- 2b. `create_pairing_code(target_home_id TEXT)`:
-- Deletes the inviter's own expired codes first, then inserts a new 6-digit code
-- into `public.pairing_codes`, retrying on a primary-key collision up to 5 times.
CREATE OR REPLACE FUNCTION public.create_pairing_code(target_home_id TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_code TEXT;
  v_retry INTEGER;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  -- Delete the inviter's own expired codes first.
  DELETE FROM public.pairing_codes
   WHERE inviter_id = v_uid
     AND expires_at <= now();

  -- Try 1 initial insert + up to 5 retries on a primary-key collision.
  FOR v_retry IN 0..5 LOOP
    v_code := lpad(floor(random() * 1000000)::int::text, 6, '0');
    BEGIN
      INSERT INTO public.pairing_codes (code, home_id, inviter_id, expires_at, status)
      VALUES (v_code, target_home_id, v_uid, now() + interval '10 minutes', 'open');
      RETURN v_code;
    EXCEPTION WHEN unique_violation THEN
      IF v_retry = 5 THEN
        RAISE;
      END IF;
    END;
  END LOOP;

  RAISE EXCEPTION 'Could not allocate a unique pairing code after 5 retries'
    USING ERRCODE = '23505';
END;
$$;

REVOKE ALL ON FUNCTION public.create_pairing_code(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_pairing_code(TEXT) TO authenticated;

-- 3. Rate-limit ledger (RLS enabled, no direct client access; used by SECURITY DEFINER functions).
CREATE TABLE IF NOT EXISTS public.pairing_rate_limit_events (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('failed_lookup', 'pairing_request')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pairing_rate_limit_events_user_kind_time
  ON public.pairing_rate_limit_events(user_id, kind, created_at);

ALTER TABLE public.pairing_rate_limit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.pairing_rate_limit_events FROM PUBLIC, anon, authenticated;

-- 4. Joiner code lookup function: returns ONLY (home_name, inviter_name, status)
-- for an open, unexpired code, and nothing otherwise. Reads the inviter's name
-- from `public.home_members.display_name` (falling back to `auth.users` metadata
-- if `display_name` is null/empty). Counts failed lookups per user (at most 5
-- failed lookups per hour).
CREATE OR REPLACE FUNCTION public.lookup_pairing_code(target_code TEXT)
RETURNS TABLE (
  home_name TEXT,
  inviter_name TEXT,
  status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_failed_count INTEGER;
  v_home_name TEXT;
  v_inviter_name TEXT;
  v_status TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  SELECT count(*)
    INTO v_failed_count
    FROM public.pairing_rate_limit_events e
   WHERE e.user_id = v_uid
     AND e.kind = 'failed_lookup'
     AND e.created_at > now() - interval '1 hour';

  IF v_failed_count >= 5 THEN
    RAISE EXCEPTION 'Rate limit exceeded: at most 5 failed code lookups per hour'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT h.name,
         COALESCE(
           NULLIF(btrim(hm.display_name), ''),
           NULLIF(btrim(u.raw_user_meta_data->>'full_name'), ''),
           NULLIF(btrim(u.raw_user_meta_data->>'name'), ''),
           'Partner'
         ),
         pc.status
    INTO v_home_name, v_inviter_name, v_status
    FROM public.pairing_codes pc
    JOIN public.homes h
      ON h.id = pc.home_id
    LEFT JOIN public.home_members hm
      ON hm.home_id = pc.home_id
     AND hm.user_id = pc.inviter_id
    LEFT JOIN auth.users u
      ON u.id = pc.inviter_id
   WHERE pc.code = target_code
     AND pc.status = 'open'
     AND pc.expires_at > now()
   LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.pairing_rate_limit_events (user_id, kind, created_at)
    VALUES (v_uid, 'failed_lookup', now());
    RETURN;
  END IF;

  RETURN QUERY SELECT v_home_name, v_inviter_name, v_status;
END;
$$;

REVOKE ALL ON FUNCTION public.lookup_pairing_code(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lookup_pairing_code(TEXT) TO authenticated;

-- 5. `pairing_requests` table (holds joiner's public key and sealed box).
CREATE TABLE IF NOT EXISTS public.pairing_requests (
  id TEXT PRIMARY KEY,
  code TEXT NOT NULL REFERENCES public.pairing_codes(code) ON DELETE CASCADE,
  joiner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joiner_name TEXT NOT NULL,
  joiner_public_key TEXT NOT NULL,
  sealed_payload TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'declined', 'done')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pairing_requests_code
  ON public.pairing_requests(code);
CREATE INDEX IF NOT EXISTS idx_pairing_requests_joiner_id
  ON public.pairing_requests(joiner_id);

ALTER TABLE public.pairing_requests ENABLE ROW LEVEL SECURITY;

-- Helper function enforcing:
-- 1) open, unexpired code
-- 2) at most 3 requests per code
-- 3) at most 5 pairing requests per user per hour
CREATE OR REPLACE FUNCTION public.can_insert_pairing_request(target_code TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT auth.uid() IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM public.pairing_codes pc
    WHERE pc.code = target_code
      AND pc.status = 'open'
      AND pc.expires_at > now()
  )
  AND (
    SELECT count(*)
    FROM public.pairing_requests pr
    WHERE pr.code = target_code
  ) < 3
  AND (
    SELECT count(*)
    FROM public.pairing_requests pr
    WHERE pr.joiner_id = auth.uid()
      AND pr.created_at > now() - interval '1 hour'
  ) < 5
  AND (
    SELECT count(*)
    FROM public.pairing_rate_limit_events e
    WHERE e.user_id = auth.uid()
      AND e.kind = 'pairing_request'
      AND e.created_at > now() - interval '1 hour'
  ) < 5;
$$;

REVOKE ALL ON FUNCTION public.can_insert_pairing_request(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_insert_pairing_request(TEXT) TO authenticated;

-- Record every pairing request insert in the rate-limit ledger so deleting a
-- request cannot reset the 5-requests-per-hour limit.
CREATE OR REPLACE FUNCTION public.record_pairing_request_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.pairing_rate_limit_events (user_id, kind, created_at)
  VALUES (NEW.joiner_id, 'pairing_request', COALESCE(NEW.created_at, now()));
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pairing_requests_record_insert ON public.pairing_requests;
CREATE TRIGGER trg_pairing_requests_record_insert
  AFTER INSERT ON public.pairing_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.record_pairing_request_insert();

-- Trigger making `code`, `joiner_id`, and `joiner_public_key` immutable after insert,
-- restricting the joiner to setting `status = 'done'`, and allowing only the inviter
-- to set `sealed_payload`, `'approved'`, or `'declined'`.
CREATE OR REPLACE FUNCTION public.enforce_pairing_request_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_inviter_id UUID;
BEGIN
  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.code IS DISTINCT FROM OLD.code
     OR NEW.joiner_id IS DISTINCT FROM OLD.joiner_id
     OR NEW.joiner_public_key IS DISTINCT FROM OLD.joiner_public_key
     OR NEW.joiner_name IS DISTINCT FROM OLD.joiner_name
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'code, joiner_id, and joiner_public_key are immutable after insert'
      USING ERRCODE = '42501';
  END IF;

  SELECT pc.inviter_id
    INTO v_inviter_id
    FROM public.pairing_codes pc
   WHERE pc.code = OLD.code;

  -- Joiner may only change status to 'done' and may never modify sealed_payload.
  IF v_uid = OLD.joiner_id AND (v_inviter_id IS NULL OR v_uid <> v_inviter_id) THEN
    IF NEW.sealed_payload IS DISTINCT FROM OLD.sealed_payload THEN
      RAISE EXCEPTION 'Only the inviter may set sealed_payload'
        USING ERRCODE = '42501';
    END IF;
    IF NEW.status <> 'done' THEN
      RAISE EXCEPTION 'Joiner may only change status to done'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  -- Only the inviter may set sealed_payload, 'approved', or 'declined'.
  IF v_inviter_id IS NOT NULL AND v_uid = v_inviter_id THEN
    IF NEW.status NOT IN ('approved', 'declined') THEN
      RAISE EXCEPTION 'Inviter may only set status to approved or declined'
        USING ERRCODE = '42501';
    END IF;
    IF NEW.status = 'approved' AND (NEW.sealed_payload IS NULL OR btrim(NEW.sealed_payload) = '') THEN
      RAISE EXCEPTION 'Approved request must include sealed_payload'
        USING ERRCODE = '23514';
    END IF;
    IF NEW.status = 'declined' AND NEW.sealed_payload IS NOT NULL THEN
      RAISE EXCEPTION 'Declined request must not include sealed_payload'
        USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Not authorized to update pairing_requests row'
    USING ERRCODE = '42501';
END;
$$;

DROP TRIGGER IF EXISTS trg_pairing_requests_enforce_update ON public.pairing_requests;
CREATE TRIGGER trg_pairing_requests_enforce_update
  BEFORE UPDATE ON public.pairing_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_pairing_request_update();

-- Joiner (B) inserts its own pending request for an open, unexpired code.
DROP POLICY IF EXISTS "Joiners can insert their own pairing request" ON public.pairing_requests;
CREATE POLICY "Joiners can insert their own pairing request"
  ON public.pairing_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (
    joiner_id = auth.uid()
    AND status = 'pending'
    AND sealed_payload IS NULL
    AND public.can_insert_pairing_request(code)
  );

-- Joiner (B) reads its own request; Inviter (A) reads requests for its own codes.
DROP POLICY IF EXISTS "Inviter and joiner can read pairing requests" ON public.pairing_requests;
CREATE POLICY "Inviter and joiner can read pairing requests"
  ON public.pairing_requests
  FOR SELECT
  TO authenticated
  USING (
    joiner_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.pairing_codes pc
      WHERE pc.code = pairing_requests.code
        AND pc.inviter_id = auth.uid()
    )
  );

-- Inviter (A) updates requests for its own codes; Joiner (B) updates its own request.
-- Column immutability and status transitions are enforced by `trg_pairing_requests_enforce_update`.
DROP POLICY IF EXISTS "Inviter and joiner can update pairing requests" ON public.pairing_requests;
CREATE POLICY "Inviter and joiner can update pairing requests"
  ON public.pairing_requests
  FOR UPDATE
  TO authenticated
  USING (
    joiner_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.pairing_codes pc
      WHERE pc.code = pairing_requests.code
        AND pc.inviter_id = auth.uid()
    )
  )
  WITH CHECK (
    joiner_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.pairing_codes pc
      WHERE pc.code = pairing_requests.code
        AND pc.inviter_id = auth.uid()
    )
  );

-- Delete policy: ONLY the joiner or the code's inviter, never anyone else.
DROP POLICY IF EXISTS "Only joiner or code inviter can delete pairing requests" ON public.pairing_requests;
CREATE POLICY "Only joiner or code inviter can delete pairing requests"
  ON public.pairing_requests
  FOR DELETE
  TO authenticated
  USING (
    joiner_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.pairing_codes pc
      WHERE pc.code = pairing_requests.code
        AND pc.inviter_id = auth.uid()
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.pairing_requests TO authenticated;
