import 'package:flutter/material.dart';

class WoodenButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final double height;
  final double? width;
  final double fontSize;

  /// If true, uses the primary gold gradient (for PLAY).
  /// If false, uses the secondary brown style (for Privacy/Support).
  final bool primary;

  const WoodenButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 64,
    this.width,
    this.fontSize = 22,
    this.primary = true,
  });

  @override
  State<WoodenButton> createState() => _WoodenButtonState();
}

class _WoodenButtonState extends State<WoodenButton> {
  bool _down = false;

  static const _borderColor = Color(0xFF5B3A1B);
  static const _accentGold = Color(0xFFFFC93C);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.height * 0.45);
    final gradient = widget.primary
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFD86B),
              Color(0xFFFFC93C),
              Color(0xFFFF8C00),
            ],
            stops: [0.0, 0.55, 1.0],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF8B5A2B),
              Color(0xFF6B3F1B),
              Color(0xFF4A2A12),
            ],
            stops: [0.0, 0.55, 1.0],
          );
    final textColor = widget.primary ? _borderColor : Colors.white;
    final iconColor = widget.primary ? _borderColor : Colors.white;
    final highlightColor = widget.primary
        ? Colors.white.withValues(alpha: 0.55)
        : _accentGold.withValues(alpha: 0.35);

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: radius,
            border: Border.all(color: _borderColor, width: 3),
            boxShadow: _down
                ? const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 8,
                      offset: Offset(0, 5),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 10,
                right: 10,
                top: 6,
                child: Container(
                  height: widget.height * 0.22,
                  decoration: BoxDecoration(
                    color: highlightColor,
                    borderRadius: BorderRadius.circular(widget.height * 0.3),
                  ),
                ),
              ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon,
                          color: iconColor, size: widget.fontSize + 4),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        shadows: widget.primary
                            ? const [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 0,
                                  color: Color(0x55FFFFFF),
                                ),
                              ]
                            : const [
                                Shadow(
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                  color: Color(0xAA000000),
                                ),
                              ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
