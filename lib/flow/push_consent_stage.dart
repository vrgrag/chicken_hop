import 'package:flutter/material.dart';

import '../core/alert_dispatcher.dart';
import '../core/local_vault.dart';
import '../core/net_sensor.dart';
import '../setup/app_facade.dart';
import 'portal_stage.dart' deferred as portal_module;

// ─────────────────────────────────────────────────────────────────────
// PUSH CONSENT STAGE — Accept / Skip promo before the portal opens
// ─────────────────────────────────────────────────────────────────────
// Uses the project's branded background:
//   portrait  → assets/notifaction_vertical.webp
//   landscape → assets/notification_horizontal.webp
//
// Accept → triggers the OS dialog via AlertDispatcher.askPermission(),
// then routes to the portal regardless of outcome (we re-snooze for
// 3 days if the user declined, and we flag os-blocked so this stage
// never reappears for OS-denied users).
//
// Skip → snooze for 3 days, route to the portal.
// ─────────────────────────────────────────────────────────────────────

class PushConsentStage extends StatefulWidget {
  final LocalVault vault;
  final AlertDispatcher alerts;
  final NetSensor sensor;
  final String portalUrl;

  const PushConsentStage({
    super.key,
    required this.vault,
    required this.alerts,
    required this.sensor,
    required this.portalUrl,
  });

  @override
  State<PushConsentStage> createState() => _PushConsentStageState();
}

class _PushConsentStageState extends State<PushConsentStage> {
  bool _busy = false;

  Future<void> _onAcceptTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    final granted = await widget.alerts.askPermission();
    if (!mounted) return;
    if (!granted) {
      final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
          AppFacade.pushPromoSnoozeSeconds;
      await widget.vault.writePushSnoozeUntil(until);
    }
    if (!mounted) return;
    _enterPortal();
  }

  Future<void> _onSkipTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        AppFacade.pushPromoSnoozeSeconds;
    await widget.vault.writePushSnoozeUntil(until);
    if (!mounted) return;
    _enterPortal();
  }

  Future<void> _enterPortal() async {
    await portal_module.loadLibrary();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => portal_module.PortalStage(
          landingUrl: widget.portalUrl,
          vault: widget.vault,
          alerts: widget.alerts,
          sensor: widget.sensor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8FD16F),
      body: LayoutBuilder(
        builder: (ctx, c) {
          final portrait = c.maxHeight >= c.maxWidth;
          final bg = portrait
              ? 'assets/notifaction_vertical.webp'
              : 'assets/notifaction_horizontal.webp';
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                bg,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFF8FD16F)),
              ),
              if (portrait)
                Positioned(
                  left: c.maxWidth * 0.08,
                  right: c.maxWidth * 0.08,
                  bottom: c.maxHeight * 0.07,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AcceptPill(onTap: _onAcceptTap, compact: false),
                      const SizedBox(height: 18),
                      _SkipLabel(onTap: _onSkipTap, compact: false),
                    ],
                  ),
                )
              else
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: c.maxHeight * 0.06,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: c.maxWidth * 0.34,
                        child: _AcceptPill(
                          onTap: _onAcceptTap,
                          compact: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SkipLabel(onTap: _onSkipTap, compact: true),
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

class _AcceptPill extends StatefulWidget {
  final VoidCallback onTap;
  final bool compact;
  const _AcceptPill({required this.onTap, required this.compact});

  @override
  State<_AcceptPill> createState() => _AcceptPillState();
}

class _AcceptPillState extends State<_AcceptPill>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _glow,
        builder: (_, __) {
          final glowVal = 0.35 + 0.4 * _glow.value;
          return AnimatedScale(
            scale: _down ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 80),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: widget.compact ? 12 : 18,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _down
                      ? const [
                          Color(0xFFE6A800),
                          Color(0xFFCC8800),
                        ]
                      : const [
                          Color(0xFFFFD86B),
                          Color(0xFFFFC93C),
                          Color(0xFFFF8C00),
                        ],
                  stops: _down ? null : const [0.0, 0.55, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(50),
                border:
                    Border.all(color: const Color(0xFF5B3A1B), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF8C00)
                        .withValues(alpha: _down ? 0.2 : glowVal),
                    blurRadius: _down ? 8 : 14 + glowVal * 18,
                    spreadRadius: _down ? 0 : glowVal * 4,
                    offset: const Offset(0, 4),
                  ),
                  const BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'Accept',
                  style: TextStyle(
                    color: const Color(0xFF5B3A1B),
                    fontSize: widget.compact ? 16 : 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SkipLabel extends StatefulWidget {
  final VoidCallback onTap;
  final bool compact;
  const _SkipLabel({required this.onTap, required this.compact});

  @override
  State<_SkipLabel> createState() => _SkipLabelState();
}

class _SkipLabelState extends State<_SkipLabel> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedOpacity(
        opacity: _down ? 0.5 : 0.92,
        duration: const Duration(milliseconds: 80),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: widget.compact ? 4 : 8),
          child: Center(
            child: Text(
              'Skip',
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.compact ? 16 : 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                shadows: const [
                  Shadow(
                    color: Color(0xAA000000),
                    offset: Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
