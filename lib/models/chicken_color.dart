import 'package:flutter/material.dart';

enum ChickenColor { red, blue, yellow, green }

extension ChickenColorX on ChickenColor {
  String get chickenAsset {
    switch (this) {
      case ChickenColor.red:
        return 'assets/red_chik.webp';
      case ChickenColor.blue:
        return 'assets/blue_chik.webp';
      case ChickenColor.yellow:
        return 'assets/yellow_chik.webp';
      case ChickenColor.green:
        return 'assets/green_cchik.webp';
    }
  }

  String get nestAsset {
    switch (this) {
      case ChickenColor.red:
        return 'assets/red_eggs.webp';
      case ChickenColor.blue:
        return 'assets/blue_eggs.webp';
      case ChickenColor.yellow:
        return 'assets/yellow_eggs.webp';
      case ChickenColor.green:
        return 'assets/green_eggs.webp';
    }
  }

  Color get accent {
    switch (this) {
      case ChickenColor.red:
        return const Color(0xFFE74C3C);
      case ChickenColor.blue:
        return const Color(0xFF3498DB);
      case ChickenColor.yellow:
        return const Color(0xFFF1C40F);
      case ChickenColor.green:
        return const Color(0xFF2ECC71);
    }
  }
}
