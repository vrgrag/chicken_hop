import 'package:flutter/material.dart';

import '../widgets/wooden_button.dart';
import 'levels_screen.dart';
import 'web_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  static const _privacyUrl = 'https://chickennhop.com/privacy-policy.html';
  static const _supportUrl = 'https://chickennhop.com/support.html';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8FD16F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/main_screen.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF8FD16F)),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final logoW = constraints.maxWidth * 0.72;
                return Column(
                  children: [
                    const Spacer(flex: 2),
                    SizedBox(
                      width: logoW,
                      child: Image.asset(
                        'assets/logo.webp',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const Spacer(flex: 2),
                    WoodenButton(
                      label: 'PLAY',
                      width: constraints.maxWidth * 0.7,
                      height: 78,
                      fontSize: 30,
                      primary: true,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LevelsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    WoodenButton(
                      label: 'PRIVACY POLICY',
                      width: constraints.maxWidth * 0.7,
                      height: 58,
                      fontSize: 18,
                      primary: false,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const WebScreen(
                            title: 'Privacy Policy',
                            url: _privacyUrl,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    WoodenButton(
                      label: 'SUPPORT',
                      width: constraints.maxWidth * 0.7,
                      height: 58,
                      fontSize: 18,
                      primary: false,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const WebScreen(
                            title: 'Support',
                            url: _supportUrl,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(flex: 1),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
