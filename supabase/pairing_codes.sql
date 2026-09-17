-- ==============================================================================
-- Cove Ephemeral Pairing Codes Table
-- Run in Supabase SQL Editor if you wish to use a dedicated table for 6-digit pairing:
-- https://supabase.com/dashboard/project/dklecfmiccevnkhxnwmo/sql/new
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.pairing_codes (
  code TEXT PRIMARY KEY,
  home_id TEXT NOT NULL REFERENCES public.homes(id) ON DELETE CASCADE,
  payload TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL
);

-- Enable RLS
ALTER TABLE public.pairing_codes ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to insert pairing codes
CREATE POLICY "Authenticated users can create pairing codes"
  ON public.pairing_codes FOR INSERT TO authenticated WITH CHECK (true);

-- Allow authenticated users to select pairing codes
CREATE POLICY "Authenticated users can lookup pairing codes"
  ON public.pairing_codes FOR SELECT TO authenticated USING (true);

-- Allow authenticated users to delete pairing codes (upon redemption)
CREATE POLICY "Authenticated users can delete redeemed pairing codes"
  ON public.pairing_codes FOR DELETE TO authenticated USING (true);
