import 'package:flutter/material.dart';

import 'core/alert_dispatcher.dart';
import 'core/attribution_tracker.dart';
import 'core/local_vault.dart';
import 'core/net_sensor.dart';
import 'core/verdict_gateway.dart';
import 'flow/boot_gate.dart';

class ChickenHopApp extends StatelessWidget {
  final LocalVault vault;
  final NetSensor sensor;
  final AttributionTracker tracker;
  final VerdictGateway gateway;
  final AlertDispatcher alerts;

  const ChickenHopApp({
    super.key,
    required this.vault,
    required this.sensor,
    required this.tracker,
    required this.gateway,
    required this.alerts,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chicken Hop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC93C),
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
      home: BootGate(
        vault: vault,
        sensor: sensor,
        tracker: tracker,
        gateway: gateway,
        alerts: alerts,
      ),
    );
  }
}
