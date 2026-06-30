import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'menu_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progressController;
  late final AnimationController _dotsController;
  Timer? _completeTimer;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _start();
  }

  Future<void> _start() async {
    await _progressController.animateTo(
      0.92,
      curve: Curves.easeInOut,
    );
    await Future.delayed(const Duration(milliseconds: 250));
    await _progressController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
    if (!mounted) return;
    _completeTimer = Timer(const Duration(milliseconds: 220), () async {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, __, ___) => const MenuScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _completeTimer?.cancel();
    _progressController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8FD16F),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isPortrait = constraints.maxHeight >= constraints.maxWidth;
          final bgAsset = isPortrait
              ? 'assets/horz_main.webp'
              : 'assets/goriz_main.webp';

          final shortest = constraints.maxWidth < constraints.maxHeight
              ? constraints.maxWidth
              : constraints.maxHeight;
          final longest = constraints.maxWidth > constraints.maxHeight
              ? constraints.maxWidth
              : constraints.maxHeight;

          final labelSize = isPortrait
              ? (shortest * 0.07).clamp(22.0, 34.0)
              : (shortest * 0.07).clamp(18.0, 26.0);

          final barHeight = isPortrait
              ? (shortest * 0.07).clamp(22.0, 32.0)
              : (shortest * 0.06).clamp(18.0, 26.0);

          final barWidth = isPortrait
              ? longest * 0.78
              : longest * 0.55;

          final bottomGap = isPortrait
              ? constraints.maxHeight * 0.08
              : constraints.maxHeight * 0.10;
          final labelGap = isPortrait ? 18.0 : 10.0;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                bgAsset,
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
                      controller: _dotsController,
                      fontSize: labelSize,
                    ),
                    SizedBox(height: labelGap),
                    SizedBox(
                      width: barWidth,
                      child: _ProgressBar(
                        controller: _progressController,
                        height: barHeight,
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
  final AnimationController controller;
  final double fontSize;
  const _LoadingLabel({required this.controller, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final phase = (controller.value * 4).floor() % 4;
        final dots = '.' * phase;
        return Text(
          'Loading$dots',
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
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

class _ProgressBar extends StatelessWidget {
  final AnimationController controller;
  final double height;
  const _ProgressBar({required this.controller, required this.height});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height * 0.6);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: const Color(0xFF5B3A1B), width: 3),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF3B2A14),
            Color(0xFF5B3A1B),
          ],
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
            animation: controller,
            builder: (context, _) {
              return Stack(
                children: [
                  Container(color: const Color(0xFF2A1C0A)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: controller.value,
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
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(height),
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
