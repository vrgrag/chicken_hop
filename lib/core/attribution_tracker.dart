import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../setup/app_facade.dart';
import '../setup/tracker_secrets.dart';
import 'agent_client.dart';

// ─────────────────────────────────────────────────────────────────────
// ATTRIBUTION TRACKER — AppsFlyer SDK orchestration + GCD retry
// ─────────────────────────────────────────────────────────────────────
// Lifecycle:
//   1. `launch()` wires every SDK callback then triggers `initSdk()`.
//   2. `awaitFirstTouch()` resolves with the install conversion data.
//      If AppsFlyer reports "Organic" (a known SDK first-callback bug),
//      we wait a short window and call GCD directly to overwrite.
//   3. `awaitDeepLink()` resolves with the optional UDL payload.
//   4. `composeVerdictBody()` merges every attribution source plus
//      device-side identifiers into the POST body the verdict endpoint
//      needs. AppsFlyer fields are forwarded verbatim — the back end
//      relies on the full set.
// ─────────────────────────────────────────────────────────────────────

class AttributionTracker {
  AppsflyerSdk? _sdk;

  Map<String, dynamic> _install = const <String, dynamic>{};
  Map<String, dynamic> _deepLink = const <String, dynamic>{};
  Map<String, dynamic> _appOpen = const <String, dynamic>{};

  final Completer<Map<String, dynamic>> _installCompleter = Completer();
  final Completer<void> _deepLinkCompleter = Completer();

  bool _booted = false;

  Future<void> launch() async {
    if (_booted) return;
    _booted = true;

    final key = AppFacade.trackerDevKey;
    debugPrint('[AttributionTracker] launch — key=${key.isEmpty ? "EMPTY" : "${key.substring(0, 4)}..."}');
    if (key.isEmpty) {
      // No tracker key configured — surface empty attribution and exit.
      debugPrint('[AttributionTracker] dev key empty — skipping SDK init');
      _completeInstall(const <String, dynamic>{});
      _completeDeepLink();
      return;
    }

    debugPrint('[AttributionTracker] initialising AppsflyerSdk (appId="${AppFacade.trackerAppId}")');
    final options = AppsFlyerOptions(
      afDevKey: key,
      appId: AppFacade.trackerAppId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );
    _sdk = AppsflyerSdk(options);

    _sdk!.onInstallConversionData((dynamic data) async {
      final payload = _flatten(data);
      debugPrint('[AttributionTracker] onInstallConversionData: $payload');
      if ((payload['af_status']?.toString() ?? '') == 'Organic') {
        debugPrint('[AttributionTracker] Organic detected — waiting ${AppFacade.organicRetryDelaySeconds}s then GCD');
        await Future.delayed(
          const Duration(seconds: AppFacade.organicRetryDelaySeconds),
        );
        final fresh = await _gcdRefresh();
        debugPrint('[AttributionTracker] GCD result: $fresh');
        _install = fresh ?? payload;
      } else {
        _install = payload;
      }
      _completeInstall(_install);
    });

    _sdk!.onAppOpenAttribution((dynamic data) {
      _appOpen = _flatten(data);
      debugPrint('[AttributionTracker] onAppOpenAttribution: $_appOpen');
    });

    _sdk!.onDeepLinking((DeepLinkResult result) {
      debugPrint('[AttributionTracker] onDeepLinking status=${result.status}');
      try {
        final dl = result.deepLink;
        if (dl != null) {
          final ce = dl.clickEvent;
          if (ce.isNotEmpty) {
            _deepLink = Map<String, dynamic>.from(ce);
            debugPrint('[AttributionTracker] deepLink clickEvent: $_deepLink');
          }
        }
      } catch (e) {
        debugPrint('[AttributionTracker] deepLink parse error: $e');
      }
      _completeDeepLink();
    });

    debugPrint('[AttributionTracker] calling initSdk...');
    await _sdk!.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );
    debugPrint('[AttributionTracker] initSdk done');
  }

  Future<Map<String, dynamic>> awaitFirstTouch({
    Duration max = const Duration(seconds: 30),
  }) {
    debugPrint('[AttributionTracker] awaitFirstTouch (max=${max.inSeconds}s)...');
    return _installCompleter.future.timeout(
      max,
      onTimeout: () {
        debugPrint('[AttributionTracker] awaitFirstTouch TIMED OUT');
        return const <String, dynamic>{};
      },
    );
  }

  Future<void> awaitDeepLink({
    Duration max = const Duration(seconds: 5),
  }) async {
    debugPrint('[AttributionTracker] awaitDeepLink (max=${max.inSeconds}s)...');
    await _deepLinkCompleter.future
        .timeout(max, onTimeout: () {
          debugPrint('[AttributionTracker] awaitDeepLink timed out (ok)');
        });
  }

  Future<String?> deviceUid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> composeVerdictBody({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};

    // Only forward install data that represents real attribution.
    // If AF returned {status: failure, ...} the payload is noise — skip it
    // so the config endpoint only receives clean attribution fields.
    final isAfFailure = _install['status'] == 'failure' ||
        _install['status'] == 'failure_v2' ||
        (_install.containsKey('status') && _install['af_status'] == null);
    if (_install.isNotEmpty && !isAfFailure) {
      body.addAll(_install);
      debugPrint('[AttributionTracker] composeBody: AF install data added'
          ' (af_status=${_install['af_status']})');
    } else if (_install.isNotEmpty) {
      debugPrint('[AttributionTracker] composeBody: AF install SKIPPED'
          ' (status=${_install['status']}) — sending clean body');
    }

    _deepLink.forEach((k, v) => body.putIfAbsent(k, () => v));
    _appOpen.forEach((k, v) => body.putIfAbsent(k, () => v));

    final uid = await deviceUid();
    body['af_id'] = uid ?? '';
    body['bundle_id'] = AppFacade.bundleSlug;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = AppFacade.storeSlug;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final fbProj = AppFacade.firebaseSender;
    if (fbProj.isNotEmpty) {
      body['firebase_project_id'] = fbProj;
    }

    if (kDebugMode) {
      debugPrint('[AttributionTracker] body=${jsonEncode(body)}');
    }
    return body;
  }

  // ── helpers ──────────────────────────────────────────────────────

  void _completeInstall(Map<String, dynamic> data) {
    if (!_installCompleter.isCompleted) {
      _installCompleter.complete(data);
    }
  }

  void _completeDeepLink() {
    if (!_deepLinkCompleter.isCompleted) {
      _deepLinkCompleter.complete();
    }
  }

  Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is Map) {
      final mapped = Map<String, dynamic>.from(raw);
      final nested = mapped['payload'];
      if (nested is Map) {
        return Map<String, dynamic>.from(nested);
      }
      return mapped;
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> _gcdRefresh() async {
    final uid = await deviceUid();
    if (uid == null || uid.isEmpty) return null;
    final key = AppFacade.trackerDevKey;
    if (key.isEmpty) return null;

    final appId = Platform.isIOS
        ? (AppFacade.trackerAppId.isNotEmpty
            ? AppFacade.trackerAppId
            : AppFacade.bundleSlug)
        : AppFacade.bundleSlug;
    final url = resolveGcdUrl(appId: appId, deviceId: uid);
    if (url.isEmpty) return null;

    try {
      final reply = await agent
          .get(Uri.parse(url), headers: {'authorization': 'Bearer $key'})
          .timeout(const Duration(seconds: 10));
      if (reply.statusCode == 200) {
        final parsed = jsonDecode(reply.body);
        if (parsed is Map) {
          return Map<String, dynamic>.from(parsed);
        }
      }
    } catch (_) {}
    return null;
  }
}
