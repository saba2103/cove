-- ==============================================================================
-- Cove Database Webhook / Trigger: Notify Partner
-- Fires after an INSERT on public.home_events to invoke the notify-partner Edge Function.
-- ==============================================================================

-- Option A: Using Supabase Database Webhooks (Recommended in Supabase Dashboard)
-- 1. Go to Database > Webhooks > Create a new webhook
-- 2. Name: "notify_partner_on_event"
-- 3. Table: "public.home_events"
-- 4. Events: "INSERT"
-- 5. Type: "Supabase Edge Functions"
-- 6. Function: "notify-partner"
-- 7. HTTP Headers: Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>

-- Option B: SQL Trigger via pg_net (Native Postgres HTTP extension in Supabase)
-- Ensure pg_net extension is enabled:
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.trigger_notify_partner()
RETURNS trigger AS $$
DECLARE
  project_url text;
  service_role_key text;
BEGIN
  -- Retrieve configuration (can be stored in app settings or vault)
  project_url := current_setting('app.settings.supabase_url', true);
  service_role_key := current_setting('app.settings.service_role_key', true);

  -- Only invoke if project_url is set
  IF project_url IS NOT NULL AND length(project_url) > 0 THEN
    PERFORM net.http_post(
      url := project_url || '/functions/v1/notify-partner',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || coalesce(service_role_key, '')
      ),
      body := jsonb_build_object(
        'type', TG_OP,
        'table', TG_TABLE_NAME,
        'schema', TG_TABLE_SCHEMA,
        'record', row_to_json(NEW)
      )
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger on public.home_events
DROP TRIGGER IF EXISTS on_home_event_insert_notify ON public.home_events;

CREATE TRIGGER on_home_event_insert_notify
  AFTER INSERT ON public.home_events
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_notify_partner();
