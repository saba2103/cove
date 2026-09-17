// ==============================================================================
// Cove Supabase Edge Function: notify-partner
// Triggered on INSERT to public.home_events.
// Looks up the OTHER home member(s), finds their registered device token(s),
// and sends a generic push notification via Firebase Cloud Messaging (FCM v1).
// Zero-Knowledge: Only unencrypted event_type is used; no encrypted content is decrypted.
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

// Module and enriched notification text mapping
function resolveNotificationContent(
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

    // Skip silent sync events like profile, display name, avatar, and settings updates (no notifications)
    const SILENT_SYNC_EVENTS = new Set([
      "member_profile_updated",
      "profile_updated",
      "user_profile_updated",
      "avatar_updated",
      "avatar_changed",
      "name_updated",
      "display_name_updated",
      "home_currency_updated",
      "home_updated",
      "preferences_updated",
      "settings_updated",
    ]);

    if (SILENT_SYNC_EVENTS.has(record.event_type)) {
      return new Response(JSON.stringify({ message: `Silent sync event '${record.event_type}' ignored for push notifications` }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
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

    // Look up actor's display name
    let actorName = "Partner";
    try {
      const { data: actorUser } = await supabase.auth.admin.getUserById(record.actor_id);
      if (actorUser && actorUser.user) {
        const meta = actorUser.user.user_metadata || {};
        actorName = meta.display_name || meta.full_name || meta.name || actorUser.user.email?.split("@")[0] || "Partner";
      }
    } catch (_) {}

    // Look up home name
    let homeName: string | undefined;
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

    // 3. Resolve enriched notification message and collapse key
    const content = resolveNotificationContent(record.event_type, actorName, homeName);
    const collapseKey = `${record.home_id}_${content.module}`;

    // 4. Send via Firebase Cloud Messaging v1
    const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID");
    const firebaseClientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
    const firebasePrivateKey = Deno.env.get("FIREBASE_PRIVATE_KEY");

    if (!firebaseProjectId || !firebaseClientEmail || !firebasePrivateKey) {
      // Credentials not configured; log payload for verification as documented
      console.log("[notify-partner] Firebase credentials not configured. Notification payload:", {
        recipientCount: devices.length,
        collapseKey,
        actorName,
        homeName,
        title: content.title,
        body: content.body,
        data: {
          home_id: record.home_id,
          module: content.module,
          event_type: record.event_type,
          event_id: record.id,
          actor_name: actorName,
          title: content.title,
          body: content.body,
        },
      });

      return new Response(
        JSON.stringify({
          status: "simulated",
          message: "Firebase credentials not configured in Supabase secrets. Enriched payload logged.",
          collapseKey,
          recipientCount: devices.length,
          title: content.title,
          body: content.body,
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

    for (const device of devices) {
      const message = {
        message: {
          token: device.fcm_token,
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
