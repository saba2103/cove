// ==============================================================================
// Cove Supabase Edge Function: notify-partner
// Triggered on INSERT to public.home_events.
// Looks up the OTHER home member(s), finds their registered device token(s),
// and sends a data-only push message via Firebase Cloud Messaging (FCM v1).
// Zero-Knowledge: Only unencrypted metadata (home_id, event_id, event_type,
// module) is sent; the receiving phone decrypts the event, writes the Quiet
// Ledger copy, batches list changes, and renders the local notification.
// ==============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

interface HomeEventRecord {
  id: string;
  home_id: string;
  actor_id: string;
  event_type: string;
  created_at: string;
}

interface WebhookPayload {
  type: "INSERT";
  table: "home_events";
  record: HomeEventRecord;
  schema: "public";
}

// Server-side silent filter matching design/specs/15-notifications.md §3
// wherever event_type alone decides. Events whose notification eligibility
// depends on decrypted content or open batch state (e.g. list_item_toggled
// done vs not done, list_item_deleted riding along in an open batch,
// habit_checkin_toggled kept vs unchecked, calendar_event_updated date/time
// change) are forwarded to the phone, which decides after decrypting.
const SILENT_SYNC_EVENTS = new Set([
  // §3 Shared lists: item edited, list renamed/archived/deleted/reordered, completed cleared
  "list_item_updated",
  "list_item_edited",
  "list_renamed",
  "list_updated",
  "list_archived",
  "list_unarchived",
  "list_deleted",
  "list_reordered",
  "lists_reordered",
  "list_items_reordered",
  "list_completed_cleared",

  // §3 Expenses: expense changed or removed
  "expense_updated",
  "expense_deleted",

  // §3 Habits: habit cheered, edited or removed
  "habit_checkin_acknowledged",
  "habit_cheered",
  "habit_updated",
  "habit_edited",
  "habit_deleted",
  "habit_archived",
  "habits_reordered",

  // §3 Commitments: commitment changed, restarted or deleted
  "subscription_updated",
  "subscription_restarted",
  "subscription_reactivated",
  "subscription_deleted",

  // §3 Profile, name, avatar, currency, budget, anniversary or home setting changed
  "member_profile_updated",
  "profile_updated",
  "user_profile_updated",
  "avatar_updated",
  "avatar_changed",
  "name_updated",
  "display_name_updated",
  "home_currency_updated",
  "monthly_budget_updated",
  "monthly_budget_cleared",
  "budget_updated",
  "home_anniversary_updated",
  "anniversary_updated",
  "home_updated",
  "home_settings_updated",
  "home_created",
  "preferences_updated",
  "settings_updated",

  // §3 Routines, roadmap items and check-in reminder edits, in any form
  "routine_created",
  "routine_updated",
  "routine_deleted",
  "routine_block_added",
  "routine_block_updated",
  "routine_block_deleted",
  "routine_event_created",
  "routine_event_updated",
  "routine_event_deleted",
  "roadmap_item_added",
  "roadmap_item_updated",
  "roadmap_items_reordered",
  "roadmap_item_toggled",
  "roadmap_item_deleted",
  "checkin_reminder_added",
  "checkin_reminder_updated",
  "checkin_reminder_toggled",
  "checkin_reminder_deleted",
]);

function isSilentEventType(eventType: string): boolean {
  if (SILENT_SYNC_EVENTS.has(eventType)) {
    return true;
  }
  if (
    eventType.startsWith("routine_") ||
    eventType.startsWith("roadmap_") ||
    eventType.startsWith("checkin_reminder_") ||
    eventType.startsWith("check_in_reminder_")
  ) {
    return true;
  }
  return false;
}

// Maps event_type to its module identifier for the data-only FCM payload.
function resolveModule(eventType: string): string {
  switch (eventType) {
    // Shared Lists
    case "list_item_added":
    case "list_item_toggled":
    case "list_item_deleted":
    case "list_created":
      return "lists";

    // Expenses
    case "expense_logged":
    case "expense_added":
      return "expenses";

    // Commitments / Subscriptions
    case "subscription_added":
    case "subscription_cancelled":
      return "subscriptions";

    // Habits
    case "habit_created":
    case "habit_checkin_toggled":
      return "habits";

    // Shared Calendar
    case "calendar_event_added":
    case "calendar_event_updated":
    case "calendar_event_deleted":
      return "calendar";

    // Home / Members
    case "member_joined":
      return "home";

    default:
      return "activity";
  }
}

// Generate Google Cloud OAuth2 Access Token for FCM v1 API using service account credentials
async function getGoogleAccessToken(
  clientEmail: string,
  privateKeyPem: string
): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const claimSet = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const encoder = new TextEncoder();
  const encodedHeader = btoa(JSON.stringify(header)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const encodedClaim = btoa(JSON.stringify(claimSet)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const signInput = `${encodedHeader}.${encodedClaim}`;

  const pemContents = privateKeyPem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", cryptoKey, encoder.encode(signInput));
  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  const jwt = `${signInput}.${encodedSignature}`;

  const tokenResp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResp.json();
  if (!tokenResp.ok) {
    throw new Error(`Failed to obtain Google access token: ${JSON.stringify(tokenData)}`);
  }
  return tokenData.access_token;
}

serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const payload: WebhookPayload = await req.json();
    const { record } = payload;
    if (!record || !record.home_id || !record.actor_id || !record.event_type) {
      return new Response(JSON.stringify({ error: "Invalid record payload" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    if (isSilentEventType(record.event_type)) {
      return new Response(
        JSON.stringify({
          message: `Silent sync event '${record.event_type}' ignored for push notifications`,
        }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Find the other home member(s)
    const { data: members, error: memberErr } = await supabase
      .from("home_members")
      .select("user_id")
      .eq("home_id", record.home_id)
      .neq("user_id", record.actor_id);

    if (memberErr || !members || members.length === 0) {
      return new Response(JSON.stringify({ message: "No partner members to notify" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const partnerUserIds = members.map((m: { user_id: string }) => m.user_id);

    // 2. Lookup registered device tokens for partner(s)
    const { data: devices, error: deviceErr } = await supabase
      .from("user_devices")
      .select("fcm_token, platform")
      .in("user_id", partnerUserIds);

    if (deviceErr || !devices || devices.length === 0) {
      return new Response(JSON.stringify({ message: "No device tokens found for partners" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 3. Build the data-only payload (no notification block, no title/body, no collapse key)
    const module = resolveModule(record.event_type);
    const dataPayload = {
      home_id: record.home_id,
      event_id: record.id,
      event_type: record.event_type,
      module,
    };

    // 4. Send via Firebase Cloud Messaging v1
    const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID");
    const firebaseClientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
    const firebasePrivateKey = Deno.env.get("FIREBASE_PRIVATE_KEY");

    if (!firebaseProjectId || !firebaseClientEmail || !firebasePrivateKey) {
      console.log("[notify-partner] Firebase credentials not configured. Data-only payload:", {
        recipientCount: devices.length,
        data: dataPayload,
      });

      return new Response(
        JSON.stringify({
          status: "simulated",
          message: "Firebase credentials not configured in Supabase secrets. Data-only payload logged.",
          recipientCount: devices.length,
          data: dataPayload,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const accessToken = await getGoogleAccessToken(
      firebaseClientEmail,
      firebasePrivateKey.replace(/\\n/g, "\n")
    );

    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`;
    const sendResults = [];

    for (const device of devices) {
      const message = {
        message: {
          token: device.fcm_token,
          data: dataPayload,
          android: {
            priority: "HIGH",
          },
        },
      };

      const resp = await fetch(fcmEndpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(message),
      });

      const result = await resp.json();
      sendResults.push({ token: device.fcm_token, status: resp.status, result });
    }

    return new Response(JSON.stringify({ success: true, sent: sendResults.length }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("[notify-partner] Error:", error);
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
