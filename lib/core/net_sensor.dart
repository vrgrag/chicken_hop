import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../setup/app_facade.dart';

// ─────────────────────────────────────────────────────────────────────
// NET SENSOR — connectivity probe tuned for real-world links
// ─────────────────────────────────────────────────────────────────────
// `isLive()` returns true when there is at least one usable network
// interface AND a DNS lookup completes within the configured budget.
// `flow` exposes the raw connectivity stream for callers that want to
// react to interface drops.
//
// Why the long-ish DNS probe budget: VPN tunnels routinely add a few
// hundred ms of latency on the first lookup after the interface comes
// up. Treating those as "no internet" produces a spurious offline
// screen. Genuine no-internet still fails fast because the platform
// returns SocketException synchronously (no route).
// ─────────────────────────────────────────────────────────────────────

const Set<ConnectivityResult> _kReachable = <ConnectivityResult>{
  ConnectivityResult.wifi,
  ConnectivityResult.mobile,
  ConnectivityResult.ethernet,
  ConnectivityResult.vpn, // VPN counts — see pitfalls section 3
  ConnectivityResult.bluetooth,
  ConnectivityResult.other,
};

const List<String> _kProbeHosts = <String>[
  'www.cloudflare.com',
  'one.one.one.one',
  'www.gstatic.com',
];

class NetSensor {
  final Connectivity _probe = Connectivity();

  Stream<List<ConnectivityResult>> get flow => _probe.onConnectivityChanged;

  Future<bool> isLive() async {
    final results = await _probe.checkConnectivity();
    if (!results.any(_kReachable.contains)) return false;

    for (final host in _kProbeHosts) {
      try {
        final reply = await InternetAddress.lookup(host).timeout(
          Duration(seconds: AppFacade.dnsProbeTimeoutSeconds),
        );
        if (reply.isNotEmpty && reply.first.rawAddress.isNotEmpty) {
          return true;
        }
      } on SocketException {
        // No route — definitely offline, fail fast.
        return false;
      } catch (_) {
        // Timeout or other transient → try the next host.
        continue;
      }
    }
    return false;
  }
}
