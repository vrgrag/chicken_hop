import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_root.dart';
import 'core/agent_client.dart';
import 'core/alert_dispatcher.dart';
import 'core/attribution_tracker.dart';
import 'core/local_vault.dart';
import 'core/net_sensor.dart';
import 'core/verdict_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase / AppCheck — wrapped because the placeholder config will
  // throw until real credentials are dropped in. The app must still
  // launch (local puzzle remains usable without Firebase).
  try {
    await Firebase.initializeApp();
    debugPrint('[main] Firebase.initializeApp OK');
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
    );
    debugPrint('[main] FirebaseAppCheck.activate OK'
        ' (provider: ${kDebugMode ? "debug" : "playIntegrity"})');
  } catch (e, st) {
    debugPrint('[main] Firebase init ERROR: $e\n$st');
  }

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF8FD16F),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await agent.prepare();
  debugPrint('[main] agent ready');

  final vault = LocalVault();
  await vault.warmUp();
  debugPrint('[main] vault warm — mode=${vault.readMode()}');

  final sensor = NetSensor();
  final tracker = AttributionTracker();
  final gateway = VerdictGateway(vault);
  final alerts = AlertDispatcher(vault);

  // Kick off Firebase Messaging in the background — it self-disables
  // when the project isn't fully configured.
  unawaited(alerts.bringOnline());
  debugPrint('[main] runApp →');

  runApp(ChickenHopApp(
    vault: vault,
    sensor: sensor,
    tracker: tracker,
    gateway: gateway,
    alerts: alerts,
  ));
}

void unawaited(Future<void> _) {}
