import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────
// OFFLINE STAGE — branded "no connection" surface with Retry
// ─────────────────────────────────────────────────────────────────────
// Backgrounds: no_internet_vertical.webp / no_internet_horizontal.webp.
// Tapping Retry tears down this stage and pushes a fresh instance of
// whatever the caller wants to retry into (BootGate, PortalStage, ...).
// ─────────────────────────────────────────────────────────────────────

class OfflineStage extends StatefulWidget {
  final WidgetBuilder onRetryBuilder;

  const OfflineStage({super.key, required this.onRetryBuilder});

  @override
  State<OfflineStage> createState() => _OfflineStageState();
}

class _OfflineStageState extends State<OfflineStage>
    with SingleTickerProviderStateMixin {
  bool _retrying = false;
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      value: 1.0,
      lowerBound: 0.94,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Future<void> _onRetryTap() async {
    if (_retrying) return;
    await _press.animateTo(0.94, curve: Curves.easeOut);
    await _press.animateTo(1.0, curve: Curves.easeOut);
    if (!mounted) return;
    setState(() => _retrying = true);
    await Future.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.onRetryBuilder),
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
              ? 'assets/no_internet_vertical.webp'
              : 'assets/no_internet_gorizontal.webp';
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
                left: portrait ? c.maxWidth * 0.12 : 0,
                right: portrait ? c.maxWidth * 0.12 : 0,
                bottom: portrait ? c.maxHeight * 0.10 : c.maxHeight * 0.08,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!portrait)
                      SizedBox(width: c.maxWidth * 0.34, child: _retryButton())
                    else
                      _retryButton(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _retryButton() {
    return ScaleTransition(
      scale: _press,
      child: GestureDetector(
        onTap: _retrying ? null : _onRetryTap,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: _retrying
                ? null
                : const LinearGradient(
                    colors: [
                      Color(0xFFFFD86B),
                      Color(0xFFFFC93C),
                      Color(0xFFFF8C00),
                    ],
                    stops: [0.0, 0.55, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
            color: _retrying
                ? const Color(0xFFFFE38A).withValues(alpha: 0.45)
                : null,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF5B3A1B), width: 3),
            boxShadow: _retrying
                ? const []
                : const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
          ),
          child: Center(
            child: _retrying
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF5B3A1B),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Connecting...',
                        style: TextStyle(
                          color: Color(0xFF5B3A1B),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Retry',
                    style: TextStyle(
                      color: Color(0xFF5B3A1B),
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
