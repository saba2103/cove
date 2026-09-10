-- ==============================================================================
-- Cove Backend Schema: Blind-Relay Event-Sourcing Substrate
-- Single source of truth for all Home synchronization and zero-knowledge relays.
-- ==============================================================================

-- 1. Homes Table
-- Represents a shared household between partners (supports multi-home substrate).
CREATE TABLE IF NOT EXISTS public.homes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  icon TEXT, -- Token identifier for generated mark or storage path
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);

-- 2. Home Memberships Table
-- Connects users to homes. No uniqueness constraint tying a user to a single home.
CREATE TABLE IF NOT EXISTS public.home_members (
  home_id UUID NOT NULL REFERENCES public.homes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (home_id, user_id)
);

-- 3. Home Events Table (The Blind Relay)
-- The ONLY place household feature data lives server-side.
-- Supabase never inspects encrypted_payload; it acts as a blind mailbox.
CREATE TABLE IF NOT EXISTS public.home_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  home_id UUID NOT NULL REFERENCES public.homes(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL, -- e.g. "list_item_added", "expense_logged", "habit_checkin"
  encrypted_payload TEXT NOT NULL, -- Base64 client-side ciphertext (libsodium SecretBox)
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Event Deliveries Table
-- Powers the two-tick delivery status indicator (1 tick = saved locally, 2 ticks = delivered).
-- Written by a partner's device as an acknowledgment of receipt.
CREATE TABLE IF NOT EXISTS public.event_deliveries (
  event_id UUID NOT NULL REFERENCES public.home_events(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  delivered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (event_id, member_id)
);

-- Indexes for lightning-fast ordered replay and delivery checks
CREATE INDEX IF NOT EXISTS idx_home_members_user_id ON public.home_members(user_id);
CREATE INDEX IF NOT EXISTS idx_home_events_home_created ON public.home_events(home_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_home_events_actor ON public.home_events(actor_id);
CREATE INDEX IF NOT EXISTS idx_event_deliveries_member ON public.event_deliveries(member_id);

-- ==============================================================================
-- Row-Level Security (RLS) Policies
-- Users can strictly read and write data in homes they belong to.
-- ==============================================================================

ALTER TABLE public.homes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.home_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.home_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_deliveries ENABLE ROW LEVEL SECURITY;

-- Helper function: checks if current authenticated user belongs to a given home
CREATE OR REPLACE FUNCTION public.is_home_member(home_id_param UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.home_members
    WHERE home_id = home_id_param
      AND user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- --- HOMES POLICIES ---
-- Any authenticated user can create a home
CREATE POLICY "Authenticated users can create homes"
  ON public.homes
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = created_by);

-- Users can select homes they are members of
CREATE POLICY "Members can view their homes"
  ON public.homes
  FOR SELECT
  TO authenticated
  USING (public.is_home_member(id) OR created_by = auth.uid());

-- Home creator can update home details
CREATE POLICY "Home creator can update home details"
  ON public.homes
  FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

-- --- HOME MEMBERS POLICIES ---
-- Members can view who else belongs to their home
CREATE POLICY "Members can view home memberships"
  ON public.home_members
  FOR SELECT
  TO authenticated
  USING (public.is_home_member(home_id));

-- Home creator can insert initial membership; invited users can join
CREATE POLICY "Users can insert membership into home"
  ON public.home_members
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- --- HOME EVENTS POLICIES ---
-- Members can select events for homes they belong to
CREATE POLICY "Members can select events in their homes"
  ON public.home_events
  FOR SELECT
  TO authenticated
  USING (public.is_home_member(home_id));

-- Members can insert events into their homes (must be the actor)
CREATE POLICY "Members can insert events in their homes"
  ON public.home_events
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_home_member(home_id)
    AND actor_id = auth.uid()
  );

-- Events are append-only: no updates or deletes permitted
-- (Tombstone / deletion is modeled as a new deletion event)

-- --- EVENT DELIVERIES POLICIES ---
-- Members can view delivery receipts for events in their homes
CREATE POLICY "Members can view event deliveries"
  ON public.event_deliveries
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.home_events e
      WHERE e.id = event_deliveries.event_id
        AND public.is_home_member(e.home_id)
    )
  );

-- Users can confirm receipt for their own member_id
CREATE POLICY "Users can record own event delivery"
  ON public.event_deliveries
  FOR INSERT
  TO authenticated
  WITH CHECK (
    member_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.home_events e
      WHERE e.id = event_deliveries.event_id
        AND public.is_home_member(e.home_id)
    )
  );

-- ==============================================================================
-- Realtime Replication Configuration
-- Enables low-latency websocket push for partner events & delivery receipts
-- ==============================================================================

-- Add tables to supabase_realtime publication
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
