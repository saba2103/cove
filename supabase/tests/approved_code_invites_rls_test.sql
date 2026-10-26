-- ==============================================================================
-- SQL Verification Suite for `20261026000000_approved_code_invites.sql`
--
-- How to run against a local PostgreSQL / Supabase instance:
--   psql -v ON_ERROR_STOP=1 -f supabase/tests/approved_code_invites_rls_test.sql
--
-- Or with an ephemeral local PostgreSQL cluster (macOS Homebrew Postgres):
--   pg_tmp_dir=$(mktemp -d)
--   initdb -D "$pg_tmp_dir" --no-locale -E UTF8
--   pg_ctl -D "$pg_tmp_dir" -l "$pg_tmp_dir/logfile" -o "-k $pg_tmp_dir -h ''" start
--   psql -h "$pg_tmp_dir" postgres -v ON_ERROR_STOP=1 -f supabase/tests/approved_code_invites_rls_test.sql
--   pg_ctl -D "$pg_tmp_dir" stop
--   rm -rf "$pg_tmp_dir"
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 0. Minimal Supabase-compatible harness (`auth.users`, `auth.uid()`, `authenticated`)
-- ------------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS auth;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
END
$$;

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA auth TO authenticated;

CREATE TABLE IF NOT EXISTS auth.users (
  id UUID PRIMARY KEY
);

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::UUID;
$$;

GRANT EXECUTE ON FUNCTION auth.uid() TO PUBLIC;

CREATE TABLE IF NOT EXISTS public.homes (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  icon TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.home_members (
  home_id TEXT NOT NULL REFERENCES public.homes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  avatar_url TEXT,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (home_id, user_id)
);

GRANT SELECT ON public.homes, public.home_members TO authenticated;

-- Seed 3 users: Inviter A, Joiner B, Outsider C
INSERT INTO auth.users (id) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc')
ON CONFLICT DO NOTHING;

INSERT INTO public.homes (id, name, description, created_by)
VALUES (
  'home_nest',
  'The Nest',
  'pairing:legacy_should_be_cleared',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

INSERT INTO public.home_members (home_id, user_id, display_name)
VALUES (
  'home_nest',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Saba'
);

-- ------------------------------------------------------------------------------
-- 1. Apply the migration
-- ------------------------------------------------------------------------------
\ir ../migrations/20261026000000_approved_code_invites.sql

GRANT SELECT, INSERT, UPDATE, DELETE ON public.pairing_codes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pairing_requests TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pairing_rate_limit_events TO authenticated;

-- Verify legacy `pairing:` description was cleared
DO $$
DECLARE
  v_desc TEXT;
BEGIN
  SELECT description INTO v_desc FROM public.homes WHERE id = 'home_nest';
  IF v_desc IS NOT NULL THEN
    RAISE EXCEPTION 'Expected legacy pairing: description to be cleared, got %', v_desc;
  END IF;
END
$$;

-- ------------------------------------------------------------------------------
-- 2. Inviter A creates codes; only Inviter A can SELECT from `pairing_codes`
-- ------------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

INSERT INTO public.pairing_codes (code, home_id, inviter_id, expires_at, status)
VALUES
  ('111111', 'home_nest', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() + interval '10 minutes', 'open'),
  ('222222', 'home_nest', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() + interval '10 minutes', 'open'),
  ('333333', 'home_nest', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() - interval '1 minute', 'open');

DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT count(*) INTO v_count FROM public.pairing_codes;
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'Expected Inviter A to read all 3 of their own codes, got %', v_count;
  END IF;
END
$$;

-- Switch to Joiner B: direct SELECT on `pairing_codes` must return 0 rows
SELECT set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);

DO $$
DECLARE
  v_count INTEGER;
  v_home_name TEXT;
  v_inviter_name TEXT;
  v_status TEXT;
BEGIN
  SELECT count(*) INTO v_count FROM public.pairing_codes;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Joiner B must not be able to read pairing_codes directly, got % rows', v_count;
  END IF;

  -- Joiner B looks up open code '111111' via SECURITY DEFINER function
  SELECT l.home_name, l.inviter_name, l.status
    INTO v_home_name, v_inviter_name, v_status
    FROM public.lookup_pairing_code('111111') l;

  IF v_home_name <> 'The Nest' OR v_inviter_name <> 'Saba' OR v_status <> 'open' THEN
    RAISE EXCEPTION 'Unexpected lookup_pairing_code result: %, %, %', v_home_name, v_inviter_name, v_status;
  END IF;

  -- Expired code '333333' returns 0 rows
  SELECT count(*) INTO v_count FROM public.lookup_pairing_code('333333');
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Expired code lookup must return 0 rows, got %', v_count;
  END IF;
END
$$;

-- ------------------------------------------------------------------------------
-- 3. Failed lookup rate limit: 5 failed lookups per hour per user
-- ------------------------------------------------------------------------------
SELECT set_config('request.jwt.claim.sub', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true);

DO $$
DECLARE
  v_i INTEGER;
  v_count INTEGER;
  v_rate_limited BOOLEAN := false;
BEGIN
  FOR v_i IN 1..5 LOOP
    SELECT count(*) INTO v_count FROM public.lookup_pairing_code('00000' || v_i::TEXT);
    IF v_count <> 0 THEN
      RAISE EXCEPTION 'Expected 0 rows for invalid code';
    END IF;
  END LOOP;

  -- 6th lookup (even of valid code '111111') must fail with rate-limit error
  BEGIN
    PERFORM * FROM public.lookup_pairing_code('111111');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%at most 5 failed code lookups per hour%' THEN
      v_rate_limited := true;
    ELSE
      RAISE;
    END IF;
  END;

  IF NOT v_rate_limited THEN
    RAISE EXCEPTION 'Expected 6th lookup after 5 failed lookups to be rate-limited';
  END IF;
END
$$;

-- ------------------------------------------------------------------------------
-- 4. Request cap per code (3) and immutability / role triggers on `pairing_requests`
-- ------------------------------------------------------------------------------
SELECT set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);

INSERT INTO public.pairing_requests (id, code, joiner_id, joiner_name, joiner_public_key, status)
VALUES
  ('req_1', '111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ancy', 'pk_base64_1', 'pending'),
  ('req_2', '111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ancy', 'pk_base64_2', 'pending'),
  ('req_3', '111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ancy', 'pk_base64_3', 'pending');

-- 4th request on code '111111' must fail RLS WITH CHECK
DO $$
DECLARE
  v_blocked BOOLEAN := false;
BEGIN
  BEGIN
    INSERT INTO public.pairing_requests (id, code, joiner_id, joiner_name, joiner_public_key, status)
    VALUES ('req_4', '111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ancy', 'pk_base64_4', 'pending');
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;

  IF NOT v_blocked THEN
    RAISE EXCEPTION 'Expected 4th request on the same code to be rejected';
  END IF;
END
$$;

-- Joiner B cannot mutate `joiner_public_key`, `code`, `joiner_id`, `sealed_payload`, or set `status = 'approved'`
DO $$
DECLARE
  v_blocked BOOLEAN;
BEGIN
  v_blocked := false;
  BEGIN
    UPDATE public.pairing_requests SET joiner_public_key = 'swapped_pk' WHERE id = 'req_1';
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'Expected joiner_public_key mutation to be rejected by trigger';
  END IF;

  v_blocked := false;
  BEGIN
    UPDATE public.pairing_requests SET code = '222222' WHERE id = 'req_1';
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'Expected code mutation to be rejected by trigger';
  END IF;

  v_blocked := false;
  BEGIN
    UPDATE public.pairing_requests SET joiner_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' WHERE id = 'req_1';
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'Expected joiner_id mutation to be rejected by trigger';
  END IF;

  v_blocked := false;
  BEGIN
    UPDATE public.pairing_requests SET status = 'approved', sealed_payload = 'forged' WHERE id = 'req_1';
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'Expected joiner setting approved/sealed_payload to be rejected by trigger';
  END IF;
END
$$;

-- Inviter A cannot mutate `joiner_public_key`, but CAN set `sealed_payload` + `status = 'approved'` or `status = 'declined'`
SELECT set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

DO $$
DECLARE
  v_blocked BOOLEAN := false;
BEGIN
  BEGIN
    UPDATE public.pairing_requests SET joiner_public_key = 'mitm_pk' WHERE id = 'req_1';
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'Expected inviter mutating joiner_public_key to be rejected by trigger';
  END IF;
END
$$;

UPDATE public.pairing_requests
   SET sealed_payload = 'sealed_box_blob_base64',
       status = 'approved'
 WHERE id = 'req_1';

UPDATE public.pairing_requests
   SET sealed_payload = NULL,
       status = 'declined'
 WHERE id = 'req_2';

-- Joiner B can change `status` to `'done'` on `req_1`
SELECT set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);

UPDATE public.pairing_requests
   SET status = 'done'
 WHERE id = 'req_1';

-- ------------------------------------------------------------------------------
-- 5. Delete policy: only the joiner or the code's inviter, never anyone else
-- ------------------------------------------------------------------------------
SELECT set_config('request.jwt.claim.sub', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true);

DO $$
DECLARE
  v_deleted INTEGER;
BEGIN
  DELETE FROM public.pairing_requests WHERE id IN ('req_1', 'req_2', 'req_3');
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  IF v_deleted <> 0 THEN
    RAISE EXCEPTION 'Outsider C must not be able to delete any pairing_requests row (deleted %)', v_deleted;
  END IF;

  DELETE FROM public.pairing_codes WHERE code IN ('111111', '222222', '333333');
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  IF v_deleted <> 0 THEN
    RAISE EXCEPTION 'Outsider C must not be able to delete any pairing_codes row (deleted %)', v_deleted;
  END IF;
END
$$;

-- Joiner B can delete their own request `req_1`
SELECT set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
DO $$
DECLARE
  v_deleted INTEGER;
BEGIN
  DELETE FROM public.pairing_requests WHERE id = 'req_1';
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  IF v_deleted <> 1 THEN
    RAISE EXCEPTION 'Expected Joiner B to delete req_1, deleted %', v_deleted;
  END IF;
END
$$;

-- Inviter A can delete request `req_2` for their code
SELECT set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
DO $$
DECLARE
  v_deleted INTEGER;
BEGIN
  DELETE FROM public.pairing_requests WHERE id = 'req_2';
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  IF v_deleted <> 1 THEN
    RAISE EXCEPTION 'Expected Inviter A to delete req_2, deleted %', v_deleted;
  END IF;
END
$$;

-- ------------------------------------------------------------------------------
-- 6. Per-user request rate limit: at most 5 pairing requests per hour
--    (Joiner B already made 3 requests above; 2 more on code '222222' succeed,
--    and the 6th within the hour is rejected even after deleting earlier rows!)
-- ------------------------------------------------------------------------------
SELECT set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);

INSERT INTO public.pairing_requests (id, code, joiner_id, joiner_name, joiner_public_key, status)
VALUES
  ('req_5', '222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ancy', 'pk_base64_5', 'pending'),
  ('req_6', '222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ancy', 'pk_base64_6', 'pending');

DO $$
DECLARE
  v_blocked BOOLEAN := false;
BEGIN
  BEGIN
    INSERT INTO public.pairing_requests (id, code, joiner_id, joiner_name, joiner_public_key, status)
    VALUES ('req_7_sixth_in_hour', '222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ancy', 'pk_base64_7', 'pending');
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;

  IF NOT v_blocked THEN
    RAISE EXCEPTION 'Expected 6th pairing request within 1 hour by Joiner B to be rejected';
  END IF;
END
$$;

ROLLBACK;
\echo 'ALL SQL RLS, TRIGGER, AND RATE-LIMIT CHECKS PASSED'
