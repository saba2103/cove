// ==============================================================================
// Cove Supabase Edge Function: notify-partner
// Triggered on INSERT to public.home_events.
// Looks up the OTHER home member(s), finds their registered device token(s),
// and sends an FCM v1 message tailored to what each device can handle:
// - platform === "android:data-v1": data-only message (the phone decrypts the
//   event, writes the Quiet Ledger copy, batches list changes, and renders the
//   local notification).
// - every other platform ("android", "ios", etc.): the legacy notification
//   message exactly as 42c300a sent (notification block, title, body, and
//   collapse key).
// ==============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

export const DATA_V1_PLATFORM = "android:data-v1";

export interface HomeEventRecord {
  id: string;
  home_id: string;
  actor_id: string;
  event_type: string;
  created_at: string;
}

export interface WebhookPayload {
  type: "INSERT";
  table: "home_events";
  record: HomeEventRecord;
  schema: "public";
}

export interface UserDeviceRow {
  fcm_token: string;
  platform?: string | null;
}

// Server-side silent filter matching design/specs/15-notifications.md §3
// wherever event_type alone decides. Applies to both android:data-v1 and
// legacy devices. Events whose notification eligibility depends on decrypted
// content or open batch state (list_item_toggled, list_item_deleted,
// habit_checkin_toggled, calendar_event_updated) pass through.
export const SILENT_SYNC_EVENTS = new Set([
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

export function isSilentEventType(eventType: string): boolean {
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

// Module and enriched notification text mapping (restored verbatim from 42c300a)
export function resolveNotificationContent(
  eventType: string,
  actorName: string,
  homeName?: string
): { module: string; title: string; body: string } {
  const homeContext = homeName ? ` in ${homeName}` : "";
  switch (eventType) {
    // Shared Lists
    case "list_item_added":
      return { module: "lists", title: `${actorName} • Shared Lists`, body: `${actorName} added an item to your shared lists${homeContext}` };
    case "list_item_toggled":
      return { module: "lists", title: `${actorName} • Shared Lists`, body: `${actorName} updated a list item${homeContext}` };
    case "list_item_deleted":
      return { module: "lists", title: `${actorName} • Shared Lists`, body: `${actorName} removed a list item${homeContext}` };
    case "list_created":
      return { module: "lists", title: `${actorName} • Shared Lists`, body: `${actorName} created a new shared list${homeContext}` };
    case "list_completed_cleared":
      return { module: "lists", title: `${actorName} • Shared Lists`, body: `${actorName} cleared completed list items${homeContext}` };

    // Expenses
    case "expense_logged":
      return { module: "expenses", title: `${actorName} • Expenses`, body: `${actorName} logged a new expenditure${homeContext}` };
    case "expense_updated":
      return { module: "expenses", title: `${actorName} • Expenses`, body: `${actorName} updated an expense${homeContext}` };
    case "expense_deleted":
      return { module: "expenses", title: `${actorName} • Expenses`, body: `${actorName} removed an expense${homeContext}` };

    // Subscriptions
    case "subscription_added":
      return { module: "subscriptions", title: `${actorName} • Commitments`, body: `${actorName} added a new recurring commitment${homeContext}` };
    case "subscription_updated":
      return { module: "subscriptions", title: `${actorName} • Commitments`, body: `${actorName} updated a commitment${homeContext}` };
    case "subscription_cancelled":
      return { module: "subscriptions", title: `${actorName} • Commitments`, body: `${actorName} paused or deactivated a commitment${homeContext}` };
    case "subscription_reactivated":
      return { module: "subscriptions", title: `${actorName} • Commitments`, body: `${actorName} reactivated a commitment${homeContext}` };

    // Habits
    case "habit_created":
      return { module: "habits", title: `${actorName} • Habits`, body: `${actorName} created a new daily rhythm${homeContext}` };
    case "habit_checkin_toggled":
      return { module: "habits", title: `${actorName} • Habits`, body: `${actorName} completed a daily habit check-in! 🔥` };
    case "habit_checkin_acknowledged":
      return { module: "habits", title: `${actorName} • Habits`, body: `${actorName} cheered for your habit check-in! 🙌` };
    case "habit_deleted":
      return { module: "habits", title: `${actorName} • Habits`, body: `${actorName} removed a rhythm${homeContext}` };

    // Shared Calendar
    case "calendar_event_added":
      return { module: "calendar", title: `${actorName} • Calendar`, body: `${actorName} scheduled a new event on your shared calendar${homeContext}` };
    case "calendar_event_updated":
      return { module: "calendar", title: `${actorName} • Calendar`, body: `${actorName} updated an event on the shared calendar` };
    case "calendar_event_deleted":
      return { module: "calendar", title: `${actorName} • Calendar`, body: `${actorName} removed an event from the calendar` };

    // Home / Members
    case "member_joined":
      return { module: "home", title: "Cove • Home", body: `${actorName} joined ${homeName || "your Home"}!` };
    case "home_created":
      return { module: "home", title: "Cove • Home", body: `${actorName} created ${homeName || "a new Home"}` };

    default:
      return { module: "activity", title: `${actorName} • Activity`, body: `${actorName} updated household activity${homeContext}` };
  }
}

// Maps event_type to its module identifier for the data-only FCM payload.
export function resolveModule(eventType: string): string {
  if (eventType === "expense_added") {
    return "expenses";
  }
  return resolveNotificationContent(eventType, "Partner").module;
}

// Builds the data-only FCM v1 message for android:data-v1 devices (3.14d/e).
export function buildDataOnlyMessage(
  token: string,
  record: HomeEventRecord
) {
  return {
    message: {
      token,
      data: {
        home_id: record.home_id,
        event_id: record.id,
        event_type: record.event_type,
        module: resolveModule(record.event_type),
      },
      android: {
        priority: "HIGH",
      },
    },
  };
}

// Builds the legacy FCM v1 message exactly as 42c300a did.
export function buildLegacyMessage(
  token: string,
  record: HomeEventRecord,
  actorName: string,
  homeName?: string
) {
  const content = resolveNotificationContent(record.event_type, actorName, homeName);
  const collapseKey = `${record.home_id}_${content.module}`;
  return {
    message: {
      token,
      notification: {
        title: content.title,
        body: content.body,
      },
      data: {
        home_id: record.home_id,
        module: content.module,
        event_type: record.event_type,
        event_id: record.id,
        actor_name: actorName,
        title: content.title,
        body: content.body,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        collapse_key: collapseKey,
        priority: "HIGH",
        notification: {
          tag: collapseKey,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        headers: {
          "apns-collapse-id": collapseKey,
          "apns-push-type": "alert",
          "apns-priority": "10",
        },
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    },
  };
}

// Selects the data-only vs legacy FCM v1 message based on device.platform.
export function buildMessageForDevice(
  device: UserDeviceRow,
  record: HomeEventRecord,
  actorName: string,
  homeName?: string
) {
  if (device.platform === DATA_V1_PLATFORM) {
    return buildDataOnlyMessage(device.fcm_token, record);
  }
  return buildLegacyMessage(device.fcm_token, record, actorName, homeName);
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

    // 3. Look up actor's display name and home name when needed for legacy devices
    let actorName = "Partner";
    let homeName: string | undefined;
    const hasLegacyDevice = devices.some(
      (d: UserDeviceRow) => d.platform !== DATA_V1_PLATFORM
    );

    if (hasLegacyDevice) {
      try {
        const { data: actorUser } = await supabase.auth.admin.getUserById(record.actor_id);
        if (actorUser && actorUser.user) {
          const meta = actorUser.user.user_metadata || {};
          actorName =
            meta.display_name ||
            meta.full_name ||
            meta.name ||
            actorUser.user.email?.split("@")[0] ||
            "Partner";
        }
      } catch (_) {}

      try {
        const { data: home } = await supabase
          .from("homes")
          .select("name")
          .eq("id", record.home_id)
          .single();
        if (home && home.name) {
          homeName = home.name;
        }
      } catch (_) {}
    }

    // 4. Send via Firebase Cloud Messaging v1
    const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID");
    const firebaseClientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
    const firebasePrivateKey = Deno.env.get("FIREBASE_PRIVATE_KEY");

    if (!firebaseProjectId || !firebaseClientEmail || !firebasePrivateKey) {
      const simulatedMessages = devices.map((device: UserDeviceRow) =>
        buildMessageForDevice(device, record, actorName, homeName)
      );
      console.log("[notify-partner] Firebase credentials not configured. Notification payloads:", {
        recipientCount: devices.length,
        messages: simulatedMessages,
      });

      return new Response(
        JSON.stringify({
          status: "simulated",
          message: "Firebase credentials not configured in Supabase secrets. Payloads logged.",
          recipientCount: devices.length,
          messages: simulatedMessages,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Obtain access token
    const accessToken = await getGoogleAccessToken(
      firebaseClientEmail,
      firebasePrivateKey.replace(/\\n/g, "\n")
    );

    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`;
    const sendResults = [];

    for (const device of devices as UserDeviceRow[]) {
      const message = buildMessageForDevice(device, record, actorName, homeName);

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
