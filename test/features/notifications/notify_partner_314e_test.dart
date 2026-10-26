import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:cove/features/notifications/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class _CapturedRequest {
  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String body;

  const _CapturedRequest({
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
  });
}

class _CapturingHttpClient extends http.BaseClient {
  final List<_CapturedRequest> requests = <_CapturedRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    final bodyStr = utf8.decode(bytes);
    requests.add(
      _CapturedRequest(
        method: request.method,
        url: request.url,
        headers: Map<String, String>.from(request.headers),
        body: bodyStr,
      ),
    );
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode('[]')),
      201,
      request: request,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}

/// Resolves the `node` binary so tests can execute `supabase/functions/notify-partner/index.ts`.
String _resolveNodeBinary() {
  const candidates = <String>[
    '/Users/saba/.local/bin/node',
    '/opt/homebrew/bin/node',
    '/usr/local/bin/node',
    'node',
  ];
  for (final candidate in candidates) {
    if (candidate == 'node' || File(candidate).existsSync()) {
      return candidate;
    }
  }
  return 'node';
}

/// Resolves `aapt2` from the Android SDK build-tools so tests can inspect
/// the compiled release APK resource table.
String? _resolveAapt2Binary() {
  final sdkRoots = <String>[
    '/opt/homebrew/share/android-commandlinetools/build-tools',
    if (Platform.environment['ANDROID_HOME'] != null)
      '${Platform.environment['ANDROID_HOME']}/build-tools',
    if (Platform.environment['ANDROID_SDK_ROOT'] != null)
      '${Platform.environment['ANDROID_SDK_ROOT']}/build-tools',
    if (Platform.environment['HOME'] != null)
      '${Platform.environment['HOME']}/Library/Android/sdk/build-tools',
  ];

  for (final root in sdkRoots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    final versions = dir.listSync().whereType<Directory>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final v in versions) {
      final bin = File('${v.path}/aapt2');
      if (bin.existsSync()) {
        return bin.path;
      }
    }
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixedNow = DateTime.utc(2026, 11, 5, 14, 0, 0);

  group('Task 3.14e — App registerDeviceToken platform string', () {
    test(
        'on Android, defaultPlatformString is android:data-v1 and registerDeviceToken upserts platform: android:data-v1',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await withClock(Clock.fixed(fixedNow), () async {
          final httpClient = _CapturingHttpClient();
          final supabase = SupabaseClient(
            'https://cove-test.supabase.co',
            'test-anon-key',
            httpClient: httpClient,
          );
          final service = NotificationService(
            supabaseClient: supabase,
            getCurrentUserId: () => 'user-saba',
          );
          addTearDown(service.dispose);

          expect(service.defaultPlatformString(), 'android:data-v1');
          expect(
            NotificationService.androidDataV1Platform,
            'android:data-v1',
          );

          final ok = await service.registerDeviceToken('fcm-token-pixel-9');
          expect(ok, isTrue);

          final upsertReq = httpClient.requests.singleWhere(
            (r) => r.url.path.endsWith('/rest/v1/user_devices'),
          );
          expect(upsertReq.method, 'POST');
          expect(upsertReq.url.queryParameters['on_conflict'], 'fcm_token');
          expect(
            upsertReq.headers['prefer'] ?? upsertReq.headers['Prefer'],
            contains('resolution=merge-duplicates'),
          );

          final decoded = jsonDecode(upsertReq.body);
          final row = decoded is List
              ? Map<String, dynamic>.from(decoded.single as Map)
              : Map<String, dynamic>.from(decoded as Map);

          expect(row['user_id'], 'user-saba');
          expect(row['fcm_token'], 'fcm-token-pixel-9');
          expect(row['platform'], 'android:data-v1');
          expect(row['last_seen_at'], fixedNow.toIso8601String());
        });
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test(
        'on iOS and macOS, defaultPlatformString returns ios and macos respectively',
        () {
      final service = NotificationService();
      addTearDown(service.dispose);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        expect(service.defaultPlatformString(), 'ios');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        expect(service.defaultPlatformString(), 'macos');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test(
      'if local notifications fail to initialise (e.g. invalid_icon), logs loudly and registers the device as plain android instead of android:data-v1',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final originalDebugPrint = debugPrint;
        final logs = <String>[];
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) logs.add(message);
        };
        try {
          await withClock(Clock.fixed(fixedNow), () async {
            final httpClient = _CapturingHttpClient();
            final supabase = SupabaseClient(
              'https://cove-test.supabase.co',
              'test-anon-key',
              httpClient: httpClient,
            );
            final service = NotificationService(
              supabaseClient: supabase,
              getCurrentUserId: () => 'user-saba',
              localNotificationsInitializer: () async {
                throw PlatformException(
                  code: 'invalid_icon',
                  message:
                      'The resource @drawable/ic_stat_cove could not be found.',
                );
              },
            );
            addTearDown(service.dispose);

            await service.initializeLocalNotifications();
            expect(service.localNotificationsInitialized, isFalse);
            expect(service.localNotificationsInitFailed, isTrue);
            expect(service.defaultPlatformString(), 'android');
            expect(
              logs.any(
                (l) =>
                    l.contains(
                      'ERROR: Local notifications initialization failed',
                    ) &&
                    l.contains('invalid_icon'),
              ),
              isTrue,
            );

            final ok = await service.registerDeviceToken('fcm-token-fold');
            expect(ok, isTrue);

            final upsertReq = httpClient.requests.singleWhere(
              (r) => r.url.path.endsWith('/rest/v1/user_devices'),
            );
            final decoded = jsonDecode(upsertReq.body);
            final row = decoded is List
                ? Map<String, dynamic>.from(decoded.single as Map)
                : Map<String, dynamic>.from(decoded as Map);

            expect(row['user_id'], 'user-saba');
            expect(row['fcm_token'], 'fcm-token-fold');
            expect(row['platform'], 'android');
          });
        } finally {
          debugPrint = originalDebugPrint;
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    test(
      'release APK keeps @drawable/ic_stat_cove when checked with aapt2',
      () async {
        final keepXml = File('android/app/src/main/res/raw/keep.xml');
        expect(keepXml.existsSync(), isTrue);
        expect(
          await keepXml.readAsString(),
          contains('@drawable/ic_stat_cove'),
        );

        final aapt2 = _resolveAapt2Binary();
        expect(
          aapt2,
          isNotNull,
          reason: 'aapt2 must be available in Android SDK build-tools',
        );

        final buildResult = await Process.run(
          'flutter',
          <String>['build', 'apk', '--release'],
        );
        expect(
          buildResult.exitCode,
          0,
          reason:
              'flutter build apk --release failed:\n${buildResult.stdout}\n${buildResult.stderr}',
        );

        final apkFile = File('build/app/outputs/flutter-apk/app-release.apk');
        expect(apkFile.existsSync(), isTrue);

        final dumpResult = await Process.run(
          aapt2!,
          <String>['dump', 'resources', apkFile.path],
        );
        expect(
          dumpResult.exitCode,
          0,
          reason: 'aapt2 dump resources failed:\n${dumpResult.stderr}',
        );
        final dumpOutput = dumpResult.stdout as String;
        expect(dumpOutput, contains('drawable/ic_stat_cove'));
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });

  group('Task 3.14e — notify-partner branching & 42c300a legacy parity', () {
    test(
        'android:data-v1 device gets data-only message; android device gets legacy message identical to 42c300a; silent filter applies to both',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('cove_314e_ts_');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final indexTsFile = File('supabase/functions/notify-partner/index.ts');
      expect(indexTsFile.existsSync(), isTrue);
      final currentSource = await indexTsFile.readAsString();

      // Also read 42c300a's version of notify-partner from git so we compare
      // against the exact historical 42c300a implementation.
      final gitShowResult = await Process.run(
        'git',
        <String>['show', '42c300a:supabase/functions/notify-partner/index.ts'],
      );
      expect(gitShowResult.exitCode, 0, reason: '${gitShowResult.stderr}');
      final source42c300a = gitShowResult.stdout as String;

      // Replace the two Deno remote https:// imports with local stub modules so
      // Node's native TypeScript runner can import and execute both files directly.
      final stubsFile = File('${tempDir.path}/deno_stubs.mjs');
      await stubsFile.writeAsString('''
export let registeredHandler = null;
export function serve(handler) {
  registeredHandler = handler;
}
export let mockSupabaseFactory = null;
export function setMockSupabaseFactory(fn) {
  mockSupabaseFactory = fn;
}
export function createClient(url, key) {
  if (mockSupabaseFactory) {
    return mockSupabaseFactory(url, key);
  }
  throw new Error("mockSupabaseFactory not configured");
}
''');

      String rewriteImports(String tsSource) {
        return tsSource
            .replaceAll(
              'import { serve } from "https://deno.land/std@0.177.0/http/server.ts";',
              'import { serve } from "./deno_stubs.mjs";',
            )
            .replaceAll(
              'import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";',
              'import { createClient } from "./deno_stubs.mjs";',
            );
      }

      final currentModuleFile = File('${tempDir.path}/current_notify.ts');
      await currentModuleFile.writeAsString(rewriteImports(currentSource));

      // Extract resolveNotificationContent and legacy message construction from 42c300a
      final legacy42c300aFile = File('${tempDir.path}/legacy_42c300a.ts');
      await legacy42c300aFile.writeAsString('''
${rewriteImports(source42c300a)}
export function build42c300aMessage(token: string, record: HomeEventRecord, actorName: string, homeName?: string) {
  const content = resolveNotificationContent(record.event_type, actorName, homeName);
  const collapseKey = `\${record.home_id}_\${content.module}`;
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
''');

      final resultFile = File('${tempDir.path}/result.json');
      final runnerFile = File('${tempDir.path}/runner.mts');
      await runnerFile.writeAsString('''
import { writeFileSync } from "node:fs";
import {
  registeredHandler,
  setMockSupabaseFactory,
} from "./deno_stubs.mjs";

// Provide Deno.env shim before importing the function modules
const envMap = new Map<string, string>();
(globalThis as any).Deno = {
  env: {
    get: (k: string) => envMap.get(k),
  },
};

const legacyMod = await import("./legacy_42c300a.ts");
const currentMod = await import("./current_notify.ts");
const handler = registeredHandler;

const sampleEventTypes = [
  "list_item_added",
  "list_item_toggled",
  "list_item_deleted",
  "list_created",
  "expense_logged",
  "subscription_added",
  "subscription_cancelled",
  "habit_created",
  "habit_checkin_toggled",
  "calendar_event_added",
  "calendar_event_updated",
  "calendar_event_deleted",
  "member_joined",
];

const unitComparisons: any[] = [];
for (const eventType of sampleEventTypes) {
  const record = {
    id: `ev_\${eventType}`,
    home_id: "home-indiranagar",
    actor_id: "user-ancy",
    event_type: eventType,
    created_at: "2026-11-05T14:00:00Z",
  };
  const dataV1Msg = currentMod.buildMessageForDevice(
    { fcm_token: "token-data-v1", platform: "android:data-v1" },
    record,
    "Ancy",
    "Indiranagar"
  );
  const androidLegacyMsg = currentMod.buildMessageForDevice(
    { fcm_token: "token-legacy-android", platform: "android" },
    record,
    "Ancy",
    "Indiranagar"
  );
  const expected42c300aMsg = legacyMod.build42c300aMessage(
    "token-legacy-android",
    record,
    "Ancy",
    "Indiranagar"
  );
  unitComparisons.push({
    eventType,
    dataV1Msg,
    androidLegacyMsg,
    expected42c300aMsg,
  });
}

// Now test the full HTTP serve() handler end-to-end with mixed devices
// (one android:data-v1 phone and one legacy 'android' phone) and with silent events.
setMockSupabaseFactory(() => ({
  from: (table: string) => {
    if (table === "home_members") {
      return {
        select: () => ({
          eq: () => ({
            neq: async () => ({
              data: [{ user_id: "user-saba" }],
              error: null,
            }),
          }),
        }),
      };
    }
    if (table === "user_devices") {
      return {
        select: () => ({
          in: async () => ({
            data: [
              { fcm_token: "tok-phone-new", platform: "android:data-v1" },
              { fcm_token: "tok-phone-old", platform: "android" },
            ],
            error: null,
          }),
        }),
      };
    }
    if (table === "homes") {
      return {
        select: () => ({
          eq: () => ({
            single: async () => ({
              data: { name: "Indiranagar" },
              error: null,
            }),
          }),
        }),
      };
    }
    throw new Error("Unexpected table: " + table);
  },
  auth: {
    admin: {
      getUserById: async () => ({
        data: {
          user: {
            user_metadata: { display_name: "Ancy" },
          },
        },
      }),
    },
  },
}));

// Case 1: Active event (expense_logged) -> simulated mode returns both messages
const activeReq = new Request("https://example.com/notify-partner", {
  method: "POST",
  body: JSON.stringify({
    type: "INSERT",
    table: "home_events",
    schema: "public",
    record: {
      id: "ev-http-1",
      home_id: "home-indiranagar",
      actor_id: "user-ancy",
      event_type: "expense_logged",
      created_at: "2026-11-05T14:00:00Z",
    },
  }),
});
const activeResp = await handler(activeReq);
const activeJson = await activeResp.json();

// Case 2: Silent events (§3) -> ignored before any device gets notified
const silentEventsToCheck = [
  "expense_updated",
  "expense_deleted",
  "list_item_updated",
  "list_renamed",
  "list_archived",
  "list_deleted",
  "list_reordered",
  "list_completed_cleared",
  "habit_checkin_acknowledged",
  "habit_updated",
  "habit_deleted",
  "subscription_updated",
  "subscription_restarted",
  "subscription_reactivated",
  "subscription_deleted",
  "member_profile_updated",
  "home_updated",
  "routine_created",
  "routine_block_added",
  "roadmap_item_added",
  "checkin_reminder_updated",
];

const silentResults: Record<string, any> = {};
for (const evType of silentEventsToCheck) {
  const req = new Request("https://example.com/notify-partner", {
    method: "POST",
    body: JSON.stringify({
      type: "INSERT",
      table: "home_events",
      schema: "public",
      record: {
        id: `ev_silent_\${evType}`,
        home_id: "home-indiranagar",
        actor_id: "user-ancy",
        event_type: evType,
        created_at: "2026-11-05T14:00:00Z",
      },
    }),
  });
  const resp = await handler(req);
  silentResults[evType] = await resp.json();
}

writeFileSync("./result.json", JSON.stringify({
  unitComparisons,
  activeJson,
  silentResults,
}));
''');

      final nodeBin = _resolveNodeBinary();
      final proc = await Process.run(
        nodeBin,
        <String>[runnerFile.path],
        workingDirectory: tempDir.path,
      );
      expect(
        proc.exitCode,
        0,
        reason: 'Node runner failed:\nSTDOUT: ${proc.stdout}\nSTDERR: ${proc.stderr}',
      );

      final output =
          jsonDecode(await resultFile.readAsString()) as Map<String, dynamic>;
      final unitComparisons = output['unitComparisons'] as List<dynamic>;
      expect(unitComparisons, isNotEmpty);

      for (final item in unitComparisons) {
        final map = item as Map<String, dynamic>;
        final eventType = map['eventType'] as String;
        final dataV1Msg =
            (map['dataV1Msg'] as Map<String, dynamic>)['message']
                as Map<String, dynamic>;
        final androidLegacyMsg = map['androidLegacyMsg'] as Map<String, dynamic>;
        final expected42c300aMsg =
            map['expected42c300aMsg'] as Map<String, dynamic>;

        // 1. android:data-v1 device gets data-only message:
        //    - no notification block
        //    - no title or body anywhere in the message
        //    - data: home_id, event_id, event_type, module
        //    - android priority HIGH, no collapse_key
        expect(
          dataV1Msg.containsKey('notification'),
          isFalse,
          reason: '$eventType data-v1 must have no notification block',
        );
        expect(
          dataV1Msg.containsKey('apns'),
          isFalse,
          reason: '$eventType data-v1 must have no apns alert block',
        );
        final dataBlock = dataV1Msg['data'] as Map<String, dynamic>;
        expect(
          dataBlock.keys.toSet(),
          equals(<String>{'home_id', 'event_id', 'event_type', 'module'}),
          reason: '$eventType data-v1 data keys must be strictly home_id, event_id, event_type, module',
        );
        expect(dataBlock['home_id'], 'home-indiranagar');
        expect(dataBlock['event_id'], 'ev_$eventType');
        expect(dataBlock['event_type'], eventType);
        expect(dataV1Msg['android'], equals(<String, dynamic>{'priority': 'HIGH'}));
        final serializedDataV1 = jsonEncode(dataV1Msg);
        expect(serializedDataV1, isNot(contains('"title"')));
        expect(serializedDataV1, isNot(contains('"body"')));
        expect(serializedDataV1, isNot(contains('collapse_key')));

        // 2. 'android' device gets the legacy message, identical to 42c300a's:
        expect(
          androidLegacyMsg,
          equals(expected42c300aMsg),
          reason:
              '$eventType legacy message for platform="android" must be identical to 42c300a',
        );
      }

      // 3. Verify full HTTP handler dispatches data-only to tok-phone-new
      //    (android:data-v1) and legacy 42c300a message to tok-phone-old (android).
      final activeJson = output['activeJson'] as Map<String, dynamic>;
      expect(activeJson['status'], 'simulated');
      expect(activeJson['recipientCount'], 2);
      final messages = activeJson['messages'] as List<dynamic>;
      expect(messages, hasLength(2));

      final msgNewPhone =
          (messages[0] as Map<String, dynamic>)['message'] as Map<String, dynamic>;
      final msgOldPhone =
          (messages[1] as Map<String, dynamic>)['message'] as Map<String, dynamic>;

      expect(msgNewPhone['token'], 'tok-phone-new');
      expect(msgNewPhone.containsKey('notification'), isFalse);
      expect(
        msgNewPhone['data'],
        equals(<String, dynamic>{
          'home_id': 'home-indiranagar',
          'event_id': 'ev-http-1',
          'event_type': 'expense_logged',
          'module': 'expenses',
        }),
      );
      expect(msgNewPhone['android'], equals(<String, dynamic>{'priority': 'HIGH'}));

      expect(msgOldPhone['token'], 'tok-phone-old');
      expect(
        msgOldPhone['notification'],
        equals(<String, dynamic>{
          'title': 'Ancy • Expenses',
          'body': 'Ancy logged a new expenditure in Indiranagar',
        }),
      );
      expect(
        (msgOldPhone['android'] as Map<String, dynamic>)['collapse_key'],
        'home-indiranagar_expenses',
      );

      // 4. Verify server-side silent filter applies to both (ignores silent events).
      final silentResults = output['silentResults'] as Map<String, dynamic>;
      for (final entry in silentResults.entries) {
        final body = entry.value as Map<String, dynamic>;
        expect(
          body['message'],
          contains("Silent sync event '${entry.key}' ignored"),
        );
      }
    });
  });
}
