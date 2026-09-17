-- ==============================================================================
-- Cove Supabase Sync Fix Migration
-- Run this in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/dklecfmiccevnkhxnwmo/sql/new
-- ==============================================================================

-- 1. Grant usage on schema
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- 2. Drop all previous policies
DROP POLICY IF EXISTS "Authenticated users can create homes" ON public.homes;
DROP POLICY IF EXISTS "Members can view their homes" ON public.homes;
DROP POLICY IF EXISTS "Home creator can update home details" ON public.homes;
DROP POLICY IF EXISTS "Members can view home memberships" ON public.home_members;
DROP POLICY IF EXISTS "Users can insert membership into home" ON public.home_members;
DROP POLICY IF EXISTS "Members can select events in their homes" ON public.home_events;
DROP POLICY IF EXISTS "Members can insert events in their homes" ON public.home_events;
DROP POLICY IF EXISTS "Members can view event deliveries" ON public.event_deliveries;
DROP POLICY IF EXISTS "Users can record own event delivery" ON public.event_deliveries;
DROP POLICY IF EXISTS "Users can update own event delivery" ON public.event_deliveries;

-- 3. Upgrade column types from UUID to TEXT so both 36-char and 40-char IDs work seamlessly
ALTER TABLE public.event_deliveries DROP CONSTRAINT IF EXISTS event_deliveries_event_id_fkey;
ALTER TABLE public.home_events DROP CONSTRAINT IF EXISTS home_events_home_id_fkey;
ALTER TABLE public.home_members DROP CONSTRAINT IF EXISTS home_members_home_id_fkey;

ALTER TABLE public.homes ALTER COLUMN id TYPE TEXT;
ALTER TABLE public.home_members ALTER COLUMN home_id TYPE TEXT;
ALTER TABLE public.home_events ALTER COLUMN id TYPE TEXT;
ALTER TABLE public.home_events ALTER COLUMN home_id TYPE TEXT;
ALTER TABLE public.event_deliveries ALTER COLUMN event_id TYPE TEXT;

ALTER TABLE public.home_members ADD CONSTRAINT home_members_home_id_fkey FOREIGN KEY (home_id) REFERENCES public.homes(id) ON DELETE CASCADE;
ALTER TABLE public.home_events ADD CONSTRAINT home_events_home_id_fkey FOREIGN KEY (home_id) REFERENCES public.homes(id) ON DELETE CASCADE;
ALTER TABLE public.event_deliveries ADD CONSTRAINT event_deliveries_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.home_events(id) ON DELETE CASCADE;

-- 4. Create helper function for membership
CREATE OR REPLACE FUNCTION public.is_home_member(home_id_param TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.home_members
    WHERE home_id = home_id_param
      AND user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 5. Re-create robust blind-relay policies
ALTER TABLE public.homes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.home_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.home_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_deliveries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can create homes"
  ON public.homes FOR INSERT TO authenticated, anon WITH CHECK (true);

CREATE POLICY "Members can view their homes"
  ON public.homes FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Home creator can update home details"
  ON public.homes FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);

CREATE POLICY "Members can view home memberships"
  ON public.home_members FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Users can insert membership into home"
  ON public.home_members FOR INSERT TO authenticated, anon WITH CHECK (true);

CREATE POLICY "Members can select events in their homes"
  ON public.home_events FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Members can insert events in their homes"
  ON public.home_events FOR INSERT TO authenticated, anon WITH CHECK (true);

CREATE POLICY "Members can update events in their homes"
  ON public.home_events FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);

CREATE POLICY "Members can view event deliveries"
  ON public.event_deliveries FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Users can record own event delivery"
  ON public.event_deliveries FOR INSERT TO authenticated, anon WITH CHECK (true);

CREATE POLICY "Users can update own event delivery"
  ON public.event_deliveries FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);

-- 6. Explicit Grants for Data API
GRANT ALL ON TABLE public.homes TO authenticated, anon, service_role;
GRANT ALL ON TABLE public.home_members TO authenticated, anon, service_role;
GRANT ALL ON TABLE public.home_events TO authenticated, anon, service_role;
GRANT ALL ON TABLE public.event_deliveries TO authenticated, anon, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated, anon, service_role;

-- 7. Ensure realtime publication
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'home_events'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.home_events;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'event_deliveries'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.event_deliveries;
  END IF;
END $$;
