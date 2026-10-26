-- ==============================================================================
-- Cove Approved-Code Invites Migration (17-invite-and-keys.md §1, §4)
--
-- Creates keyless `public.pairing_codes` and `public.pairing_requests` with RLS.
-- The home key never reaches the server readable: `pairing_codes` has no payload
-- column, and `pairing_requests.sealed_payload` holds only an anonymous sealed box
-- (`crypto_box_seal`) encrypted to the joiner's ephemeral public key after the
-- inviter verifies the two SAS words and taps "Let them in".
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

-- Authenticated users can read pairing codes to look up a code or manage their own codes.
CREATE POLICY "Authenticated users can read pairing codes"
  ON public.pairing_codes
  FOR SELECT
  TO authenticated
  USING (true);

-- Inviters can update status on their own pairing codes (e.g. marking 'approved').
CREATE POLICY "Inviters can update their own pairing codes"
  ON public.pairing_codes
  FOR UPDATE
  TO authenticated
  USING (inviter_id = auth.uid())
  WITH CHECK (inviter_id = auth.uid());

-- Inviters can delete their own pairing codes, and anyone can clean up expired codes.
CREATE POLICY "Users can delete own or expired pairing codes"
  ON public.pairing_codes
  FOR DELETE
  TO authenticated
  USING (inviter_id = auth.uid() OR expires_at < now());

-- 3. `pairing_requests` table (holds joiner's public key and sealed box).
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

-- Helper function to enforce at most 3 requests per code and an open, unexpired code.
CREATE OR REPLACE FUNCTION public.can_insert_pairing_request(target_code TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
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
  ) < 3;
$$;

-- Joiner (B) inserts its own pending request for an open, unexpired code (< 3 requests).
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

-- Inviter (A) updates requests for its own codes (approving with sealed_payload or declining);
-- Joiner (B) updates its own request (marking 'done').
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

-- Inviter or joiner can delete done/declined requests for cleanup.
CREATE POLICY "Inviter and joiner can delete finished pairing requests"
  ON public.pairing_requests
  FOR DELETE
  TO authenticated
  USING (
    joiner_id = auth.uid()
    OR status IN ('done', 'declined')
    OR EXISTS (
      SELECT 1
      FROM public.pairing_codes pc
      WHERE pc.code = pairing_requests.code
        AND pc.inviter_id = auth.uid()
    )
  );
