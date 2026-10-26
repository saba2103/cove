-- ==============================================================================
-- SQL Verification Suite for `20261026000000_approved_code_invites.sql`
--
-- Proven against the live `public` schema dump (`build/public_schema_dump.sql`)
-- from project `dklecfmiccevnkhxnwmo`.
--
-- How to run with a throwaway local PostgreSQL cluster:
--   pg_tmp_dir=$(mktemp -d)
--   /opt/homebrew/bin/initdb -D "$pg_tmp_dir" --no-locale -E UTF8
--   /opt/homebrew/bin/pg_ctl -D "$pg_tmp_dir" -l "$pg_tmp_dir/logfile" -o "-k $pg_tmp_dir -h ''" start
--   /opt/homebrew/bin/psql -h "$pg_tmp_dir" postgres -v ON_ERROR_STOP=1 -f build/public_schema_dump.sql
--   /opt/homebrew/bin/psql -h "$pg_tmp_dir" postgres -v ON_ERROR_STOP=1 -f supabase/migrations/20261026000000_approved_code_invites.sql
--   /opt/homebrew/bin/psql -h "$pg_tmp_dir" postgres -v ON_ERROR_STOP=1 -f supabase/tests/approved_code_invites_rls_test.sql
--   /opt/homebrew/bin/pg_ctl -D "$pg_tmp_dir" stop
--   rm -rf "$pg_tmp_dir"
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 0. Ensure minimal Supabase auth/public schema exists if run standalone, then
--    seed test users and homes and apply the migration.
-- ------------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS auth;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
END
$$;

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT USAGE ON SCHEMA auth TO anon, authenticated;

CREATE TABLE IF NOT EXISTS auth.users (
  id UUID PRIMARY KEY,
  raw_user_meta_data JSONB DEFAULT '{}'::JSONB
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
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  icon TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.home_members (
  home_id TEXT NOT NULL REFERENCES public.homes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  display_name TEXT,
  avatar_url TEXT,
  PRIMARY KEY (home_id, user_id)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.homes, public.home_members TO authenticated;

-- Seed 3 users: Inviter A, Joiner B, Outsider C
INSERT INTO auth.users (id, raw_user_meta_data) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '{"full_name": "Saba Meta", "name": "Saba Meta"}'::JSONB),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '{"full_name": "Ancy", "name": "Ancy"}'::JSONB),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '{"full_name": "Outsider", "name": "Outsider"}'::JSONB)
ON CONFLICT (id) DO UPDATE
  SET raw_user_meta_data = EXCLUDED.raw_user_meta_data;

INSERT INTO public.homes (id, name, description, created_by)
VALUES
  (
    'home_nest',
    'The Nest',
    'pairing:legacy_should_be_cleared',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  (
    'home_fallback_meta',
    'Villa Cove',
    NULL,
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  );

INSERT INTO public.home_members (home_id, user_id, display_name)
VALUES
  ('home_nest', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Saba'),
  ('home_fallback_meta', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL);

-- Apply migration (idempotent even if already applied before this test script)
\ir ../migrations/20261026000000_approved_code_invites.sql

-- ------------------------------------------------------------------------------
-- Check 1: Legacy `pairing:` description in `public.homes.description` cleared
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_desc TEXT;
BEGIN
  SELECT description INTO v_desc FROM public.homes WHERE id = 'home_nest';
  IF v_desc IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL [Check 1]: Expected legacy pairing: description to be cleared, got %', v_desc;
  END IF;
END
$$;
\echo 'PASS [Check 1]: Legacy pairing: description cleared on public.homes'

-- ------------------------------------------------------------------------------
-- Check 2: `public.pairing_codes` is keyless (no payload column) & RLS enabled
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_has_payload BOOLEAN;
  v_rls_codes BOOLEAN;
  v_rls_requests BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'pairing_codes'
      AND column_name = 'payload'
  ) INTO v_has_payload;

  IF v_has_payload THEN
    RAISE EXCEPTION 'FAIL [Check 2]: public.pairing_codes must not have a payload column';
  END IF;

  SELECT relrowsecurity INTO v_rls_codes
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relname = 'pairing_codes';

  SELECT relrowsecurity INTO v_rls_requests
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relname = 'pairing_requests';

  IF NOT (v_rls_codes AND v_rls_requests) THEN
    RAISE EXCEPTION 'FAIL [Check 2]: RLS must be enabled on pairing_codes and pairing_requests';
  END IF;
END
$$;
\echo 'PASS [Check 2]: public.pairing_codes is keyless and RLS is enabled on pairing tables'

-- ------------------------------------------------------------------------------
-- Check 3: `create_pairing_code` deletes the inviter's own expired codes first
--          and retries on a primary-key collision (up to 5 times)
-- ------------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

DO $$
DECLARE
  v_first_seed_code TEXT;
  v_second_seed_code TEXT;
  v_created_code TEXT;
  v_expired_exists BOOLEAN;
BEGIN
  -- Seed an expired code owned by Inviter A
  INSERT INTO public.pairing_codes (code, home_id, inviter_id, expires_at, status)
  VALUES ('999999', 'home_nest', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() - interval '5 minutes', 'open');

  -- Discover the first two codes generated by random() under setseed(0.42)
  PERFORM setseed(0.42);
  v_first_seed_code := lpad(floor(random() * 1000000)::int::text, 6, '0');
  v_second_seed_code := lpad(floor(random() * 1000000)::int::text, 6, '0');

  -- Pre-insert `v_first_seed_code` as an unexpired code so attempt #1 collides on PK!
  INSERT INTO public.pairing_codes (code, home_id, inviter_id, expires_at, status)
  VALUES (v_first_seed_code, 'home_nest', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() + interval '10 minutes', 'open');

  -- Reset PRNG seed so `create_pairing_code` hits `v_first_seed_code` first, collides,
  -- and retries to allocate `v_second_seed_code`.
  PERFORM setseed(0.42);
  v_created_code := public.create_pairing_code('home_nest');

  IF v_created_code <> v_second_seed_code THEN
    RAISE EXCEPTION 'FAIL [Check 3]: Expected create_pairing_code to retry on PK collision (%) and return %, got %',
      v_first_seed_code, v_second_seed_code, v_created_code;
  END IF;

  -- Verify Inviter A's expired code '999999' was deleted first
  SELECT EXISTS (
    SELECT 1 FROM public.pairing_codes WHERE code = '999999'
  ) INTO v_expired_exists;

  IF v_expired_exists THEN
    RAISE EXCEPTION 'FAIL [Check 3]: Expected create_pairing_code to delete inviter expired code 999999 first';
  END IF;

  -- Clean up the two codes from Check 3 before Check 4
  DELETE FROM public.pairing_codes WHERE code IN (v_first_seed_code, v_second_seed_code);
END
$$;
\echo 'PASS [Check 3]: create_pairing_code deletes inviter expired codes first and retries on PK collision'

-- ------------------------------------------------------------------------------
-- Check 4: Inviter A reads only their own codes; Joiner B cannot SELECT from
--          `pairing_codes` directly and must use `lookup_pairing_code(code)`,
--          which reads `home_members.display_name` (with `auth.users` fallback)
-- ------------------------------------------------------------------------------
INSERT INTO public.pairing_codes (code, home_id, inviter_id, expires_at, status)
VALUES
  ('111111', 'home_nest', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() + interval '10 minutes', 'open'),
  ('222222', 'home_fallback_meta', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() + interval '10 minutes', 'open'),
  ('333333', 'home_nest', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() - interval '1 minute', 'open');

DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT count(*) INTO v_count FROM public.pairing_codes;
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'FAIL [Check 4]: Expected Inviter A to read all 3 of their own codes, got %', v_count;
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
    RAISE EXCEPTION 'FAIL [Check 4]: Joiner B must not read pairing_codes directly, got % rows', v_count;
  END IF;

  -- Open code '111111' returns home_name + inviter_name from `home_members.display_name` ('Saba')
  SELECT l.home_name, l.inviter_name, l.status
    INTO v_home_name, v_inviter_name, v_status
    FROM public.lookup_pairing_code('111111') l;

  IF v_home_name <> 'The Nest' OR v_inviter_name <> 'Saba' OR v_status <> 'open' THEN
    RAISE EXCEPTION 'FAIL [Check 4]: Unexpected lookup_pairing_code(111111) result: %, %, %',
      v_home_name, v_inviter_name, v_status;
  END IF;

  -- Open code '222222' where `home_members.display_name` is NULL falls back to `auth.users.raw_user_meta_data` ('Saba Meta')
  SELECT l.home_name, l.inviter_name, l.status
    INTO v_home_name, v_inviter_name, v_status
    FROM public.lookup_pairing_code('222222') l;

  IF v_home_name <> 'Villa Cove' OR v_inviter_name <> 'Saba Meta' OR v_status <> 'open' THEN
    RAISE EXCEPTION 'FAIL [Check 4]: Unexpected lookup_pairing_code(222222) fallback result: %, %, %',
      v_home_name, v_inviter_name, v_status;
  END IF;

  -- Expired code '333333' returns 0 rows
  SELECT count(*) INTO v_count FROM public.lookup_pairing_code('333333');
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'FAIL [Check 4]: Expired code lookup must return 0 rows, got %', v_count;
  END IF;
END
$$;
\echo 'PASS [Check 4]: Inviter-only SELECT on pairing_codes; lookup_pairing_code reads home_members.display_name & auth.users fallback'

-- ------------------------------------------------------------------------------
-- Check 5: Failed lookup rate limit — 5 failed lookups per hour per user
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
      RAISE EXCEPTION 'FAIL [Check 5]: Expected 0 rows for invalid code';
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
    RAISE EXCEPTION 'FAIL [Check 5]: Expected 6th lookup after 5 failed lookups to be rate-limited';
  END IF;
END
$$;
\echo 'PASS [Check 5]: lookup_pairing_code rate-limits user after 5 failed lookups per hour'

-- ------------------------------------------------------------------------------
-- Check 6: Per-code request cap — at most 3 requests per code
-- ------------------------------------------------------------------------------
SELECT set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);

INSERT INTO public.pairing_requests (id, code, joiner_id, joiner_name, joiner_public_key, status)
VALUES
  ('req_1', '111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ancy', 'pk_base64_1', 'pending'),
  ('req_2', '111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ancy', 'pk_base64_2', 'pending'),
  ('req_3', '111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ancy', 'pk_base64_3', 'pending');

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
    RAISE EXCEPTION 'FAIL [Check 6]: Expected 4th request on the same code to be rejected';
  END IF;
END
$$;
\echo 'PASS [Check 6]: Per-code cap of 3 pairing_requests enforced by RLS WITH CHECK'

-- ------------------------------------------------------------------------------
-- Check 7: Immutability trigger — `code`, `joiner_id`, and `joiner_public_key`
--          cannot be mutated after insert by either joiner or inviter
-- ------------------------------------------------------------------------------
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
    RAISE EXCEPTION 'FAIL [Check 7]: Expected joiner_public_key mutation by joiner to be rejected';
  END IF;

  v_blocked := false;
  BEGIN
    UPDATE public.pairing_requests SET code = '222222' WHERE id = 'req_1';
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'FAIL [Check 7]: Expected code mutation by joiner to be rejected';
  END IF;

  v_blocked := false;
  BEGIN
    UPDATE public.pairing_requests SET joiner_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' WHERE id = 'req_1';
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'FAIL [Check 7]: Expected joiner_id mutation by joiner to be rejected';
  END IF;
END
$$;

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
    RAISE EXCEPTION 'FAIL [Check 7]: Expected joiner_public_key mutation by inviter to be rejected';
  END IF;
END
$$;
\echo 'PASS [Check 7]: Trigger makes code, joiner_id, and joiner_public_key immutable after insert'

-- ------------------------------------------------------------------------------
-- Check 8: Role update transitions — joiner may only set `status = 'done'`;
--          only inviter may set `sealed_payload`, `'approved'`, or `'declined'`
-- ------------------------------------------------------------------------------
SELECT set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);

DO $$
DECLARE
  v_blocked BOOLEAN := false;
BEGIN
  BEGIN
    UPDATE public.pairing_requests SET status = 'approved', sealed_payload = 'forged' WHERE id = 'req_1';
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'FAIL [Check 8]: Expected joiner setting approved/sealed_payload to be rejected';
  END IF;
END
$$;

-- Inviter A approves `req_1` with `sealed_payload` and declines `req_2`
SELECT set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

UPDATE public.pairing_requests
   SET sealed_payload = 'sealed_box_blob_base64',
       status = 'approved'
 WHERE id = 'req_1';

UPDATE public.pairing_requests
   SET sealed_payload = NULL,
       status = 'declined'
 WHERE id = 'req_2';

-- Joiner B marks `req_1` as `'done'`
SELECT set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);

UPDATE public.pairing_requests
   SET status = 'done'
 WHERE id = 'req_1';
\echo 'PASS [Check 8]: Only inviter can set sealed_payload/approved/declined; joiner can only set status = done'

-- ------------------------------------------------------------------------------
-- Check 9: Delete policy — only the joiner or the code's inviter, never anyone else
-- ------------------------------------------------------------------------------
SELECT set_config('request.jwt.claim.sub', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true);

DO $$
DECLARE
  v_deleted INTEGER;
BEGIN
  DELETE FROM public.pairing_requests WHERE id IN ('req_1', 'req_2', 'req_3');
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  IF v_deleted <> 0 THEN
    RAISE EXCEPTION 'FAIL [Check 9]: Outsider C must not delete any pairing_requests row (deleted %)', v_deleted;
  END IF;

  DELETE FROM public.pairing_codes WHERE code IN ('111111', '222222', '333333');
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  IF v_deleted <> 0 THEN
    RAISE EXCEPTION 'FAIL [Check 9]: Outsider C must not delete any pairing_codes row (deleted %)', v_deleted;
  END IF;
END
$$;

-- Joiner B deletes their own request `req_1`
SELECT set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
DO $$
DECLARE
  v_deleted INTEGER;
BEGIN
  DELETE FROM public.pairing_requests WHERE id = 'req_1';
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  IF v_deleted <> 1 THEN
    RAISE EXCEPTION 'FAIL [Check 9]: Expected Joiner B to delete req_1, deleted %', v_deleted;
  END IF;
END
$$;

-- Inviter A deletes request `req_2` for their code
SELECT set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
DO $$
DECLARE
  v_deleted INTEGER;
BEGIN
  DELETE FROM public.pairing_requests WHERE id = 'req_2';
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  IF v_deleted <> 1 THEN
    RAISE EXCEPTION 'FAIL [Check 9]: Expected Inviter A to delete req_2, deleted %', v_deleted;
  END IF;
END
$$;
\echo 'PASS [Check 9]: Delete policy restricts deletion strictly to joiner or code inviter'

-- ------------------------------------------------------------------------------
-- Check 10: Per-user request rate limit — at most 5 pairing requests per hour
--           (even after deleting earlier requests)
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
    RAISE EXCEPTION 'FAIL [Check 10]: Expected 6th pairing request within 1 hour by Joiner B to be rejected';
  END IF;
END
$$;
\echo 'PASS [Check 10]: Per-user rate limit of 5 pairing_requests per hour enforced even after row deletion'

ROLLBACK;
\echo 'ALL 10 SQL SCHEMA, RLS, TRIGGER, AND RATE-LIMIT CHECKS PASSED'
