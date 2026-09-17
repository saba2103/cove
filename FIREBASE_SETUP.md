# Cove Partner Notifications: Firebase & APNs Setup Guide

Cove uses **Firebase Cloud Messaging (FCM v1)** and **Apple Push Notification service (APNs)** strictly as a zero-knowledge transport. The backend only relays generic, unencrypted notifications (derived purely from the unencrypted `event_type`) with anti-spam collapse keys (`{home_id}_{module}`).

Follow this guide to configure your Firebase project, Google Cloud service account, APNs keys, and Supabase Edge Function secrets.

---

## 1. Firebase Project Setup

1. Go to the [Firebase Console](https://console.firebase.google.com/) and click **Add project**.
2. Name your project (e.g., `cove-app`) and follow the on-screen steps.
3. Once created, click **Project Overview (Gear Icon) > Project Settings**.
4. Note down your **Project ID** (e.g. `cove-app-12345`).

---

## 2. Register Client Apps

### Android Setup
1. In Firebase Project Settings, under **Your apps**, click the **Android** icon.
2. Enter your Android package name (from `android/app/build.gradle`: `com.cove.cove` or similar).
3. Download the generated `google-services.json`.
4. Place `google-services.json` inside `android/app/google-services.json`.

### iOS Setup
1. Under **Your apps**, click the **Apple / iOS** icon.
2. Enter your iOS Bundle ID (from `ios/Runner.xcodeproj`: e.g. `com.cove.cove`).
3. Download `GoogleService-Info.plist`.
4. Open the iOS project in Xcode and drag `GoogleService-Info.plist` into the `Runner` target.

---

## 3. APNs Auth Key for iOS (Apple Developer Portal)

To deliver push notifications to iOS devices via FCM:
1. Log in to your [Apple Developer Account](https://developer.apple.com/account/).
2. Navigate to **Certificates, Identifiers & Profiles > Keys**.
3. Click the **+** button to create a new key.
4. Name the key (e.g., `Cove Push Notification Key`) and check **Apple Push Notifications service (APNs)**.
5. Click **Continue** and **Register**.
6. Download the `.p8` key file (save this securely; Apple will only let you download it once).
7. Note your **Key ID** (10-character string) and your Apple **Team ID** (found in membership details).
8. Return to Firebase Console:
   - Go to **Project Settings > Cloud Messaging**.
   - Under **Apple app configuration**, find your iOS app.
   - Under **APNs Authentication Key**, click **Upload**.
   - Upload your `.p8` file, enter your **Key ID**, and enter your **Team ID**.

---

## 4. Google Cloud Service Account for Supabase Edge Functions

Supabase Edge Functions authenticate to FCM HTTP v1 using a Google Cloud Service Account:
1. In Firebase Console, navigate to **Project Settings > Service accounts**.
2. Click **Generate new private key**, then click **Generate key**.
3. A JSON file will download containing credentials:
   ```json
   {
     "project_id": "cove-app-12345",
     "client_email": "firebase-adminsdk-xxxxx@cove-app-12345.iam.gserviceaccount.com",
     "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC...\n-----END PRIVATE KEY-----\n"
   }
   ```

---

## 5. Configure Supabase Secrets

Set the credentials in your Supabase project so the `notify-partner` Edge Function can dispatch push notifications:

### Using Supabase CLI:
```bash
supabase secrets set \
  FIREBASE_PROJECT_ID="cove-app-12345" \
  FIREBASE_CLIENT_EMAIL="firebase-adminsdk-xxxxx@cove-app-12345.iam.gserviceaccount.com" \
  FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

### Or Using Supabase Dashboard:
1. Open your project on [supabase.com/dashboard](https://supabase.com/dashboard).
2. Go to **Edge Functions > Secrets**.
3. Add the three secrets:
   - `FIREBASE_PROJECT_ID`: Your project ID string.
   - `FIREBASE_CLIENT_EMAIL`: Your service account client email.
   - `FIREBASE_PRIVATE_KEY`: The full private key string (including `-----BEGIN PRIVATE KEY-----` and newlines).

---

## 6. Deploy Edge Function & Database Webhook

1. Deploy the `notify-partner` Edge Function:
   ```bash
   supabase functions deploy notify-partner
   ```
2. In Supabase Dashboard:
   - Go to **Database > Webhooks**.
   - Click **Create a new webhook**.
   - Name: `notify_partner_on_event`
   - Table: `public.home_events`
   - Events: `[X] INSERT`
   - Type: `Supabase Edge Functions`
   - Function: `notify-partner`
   - Save.

Or run `supabase/notify_trigger.sql` directly in your Supabase SQL Editor.

---

## 7. Zero-Knowledge Guarantees

- **No Content in Payloads**: The server never inspects `encrypted_payload`. All notification strings are generic editorial phrases based purely on `event_type`.
- **Anti-Spam Grouping**: Notifications are grouped by `${home_id}_${module}` so bursts of actions (e.g. 4 list checks in 30 seconds) collapse into a single calm update on both Android and iOS.
- **Local Control**: Even if a push arrives, the app's local per-module notification settings in Profile dictate whether a banner or sound is displayed. Silent background sync is always respected.
