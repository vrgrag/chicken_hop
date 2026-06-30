import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../setup/app_facade.dart';
import 'agent_client.dart';
import 'local_vault.dart';

// ─────────────────────────────────────────────────────────────────────
// ALERT DISPATCHER — Firebase Messaging + local notification surface
// ─────────────────────────────────────────────────────────────────────
// URL handling rules (one-shot semantics):
//   * Cold-start tap  → `getInitialMessage()` returns the message.
//     Stash the URL in LocalVault. BootGate consumes it on next launch.
//   * Warm-resume tap → `onMessageOpenedApp` fires.
//     Invoke `onPortalRedirect` callback. Never persist.
//   * Foreground push → `onMessage` fires → we surface a local banner.
//     A tap on the banner re-invokes `onPortalRedirect`. Never persist.
// ─────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> _bgIsolateHandler(RemoteMessage _) async {
  // No work here — the OS will display the notification; tap routing
  // happens on the main isolate when the user opens the app.
}

class AlertDispatcher {
  final LocalVault _vault;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  FirebaseMessaging? _fcm;
  String? _token;
  bool _wired = false;

  void Function(String url)? onPortalRedirect;
  void Function(String token)? onTokenRotation;

  AlertDispatcher(this._vault);

  String? get token => _token;

  Future<void> bringOnline() async {
    if (_wired) return;
    try {
      await Firebase.initializeApp();
      _fcm = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(_bgIsolateHandler);

      await _initLocalLayer();

      _token = await _fcm!.getToken();
      _fcm!.onTokenRefresh.listen((next) {
        _token = next;
        onTokenRotation?.call(next);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final initial = await _fcm!.getInitialMessage();
      if (initial != null) await _onColdTap(initial);

      _wired = true;
    } catch (_) {
      // Firebase missing or misconfigured — push silently disabled.
    }
  }

  Future<bool> askPermission() async {
    if (_fcm == null) return false;
    final settings = await _fcm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    await _vault.writePushGranted(granted);

    // Important: if the OS dialog was outright denied, mark it so the
    // promo screen does not reappear and tap "Accept" for nothing.
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      await _vault.markPushOsBlocked();
    }
    return granted;
  }

  Future<void> _initLocalLayer() async {
    const android = AndroidInitializationSettings(
      'ic_chimney_spark', // monochrome flame, not the launcher
    );
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload);
          if (data is Map) {
            final url = data['url']?.toString();
            if (url != null && url.isNotEmpty) {
              onPortalRedirect?.call(url);
            }
          }
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          AppFacade.notificationChannelId,
          AppFacade.notificationChannelName,
          description: 'Chicken Hop push alerts',
          importance: Importance.high,
        ),
      );
    }
  }

  Future<void> _onForeground(RemoteMessage msg) async {
    final notice = msg.notification;
    if (notice == null) return;
    if (!Platform.isAndroid) return;

    final imageUrl = notice.android?.imageUrl;
    AndroidNotificationDetails? details;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      final bitmap = await _fetchImage(imageUrl);
      if (bitmap != null) {
        details = AndroidNotificationDetails(
          AppFacade.notificationChannelId,
          AppFacade.notificationChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_chimney_spark',
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bitmap),
            largeIcon: const DrawableResourceAndroidBitmap(
              'ic_launcher',
            ),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      AppFacade.notificationChannelId,
      AppFacade.notificationChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_chimney_spark',
    );

    final payload =
        msg.data.isNotEmpty ? jsonEncode(msg.data) : null;

    await _local.show(
      notice.hashCode,
      notice.title,
      notice.body,
      NotificationDetails(android: details),
      payload: payload,
    );
  }

  Future<void> _onColdTap(RemoteMessage msg) async {
    final url = msg.data['url']?.toString();
    if (url != null && url.isNotEmpty) {
      await _vault.stashColdPushUrl(url);
    }
  }

  void _onWarmTap(RemoteMessage msg) {
    final url = msg.data['url']?.toString();
    if (url != null && url.isNotEmpty) {
      onPortalRedirect?.call(url);
    }
  }

  Future<Uint8List?> _fetchImage(String url) async {
    try {
      final reply = await agent
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (reply.statusCode == 200) return reply.bodyBytes;
    } catch (_) {}
    return null;
  }
}
