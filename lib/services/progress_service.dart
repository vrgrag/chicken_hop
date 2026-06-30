import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  static const _kUnlockedKey = 'unlocked_levels';
  static const _kStarsPrefix = 'level_stars_';

  Future<int> getUnlocked() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kUnlockedKey) ?? 1;
  }

  Future<void> unlockNext(int currentLevel, int totalLevels) async {
    final p = await SharedPreferences.getInstance();
    final unlocked = p.getInt(_kUnlockedKey) ?? 1;
    final next = (currentLevel + 1).clamp(1, totalLevels);
    if (next > unlocked) {
      await p.setInt(_kUnlockedKey, next);
    }
  }

  Future<int> getStars(int level) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt('$_kStarsPrefix$level') ?? 0;
  }

  Future<void> setStars(int level, int stars) async {
    final p = await SharedPreferences.getInstance();
    final existing = p.getInt('$_kStarsPrefix$level') ?? 0;
    if (stars > existing) {
      await p.setInt('$_kStarsPrefix$level', stars);
    }
  }

  Future<Map<int, int>> getAllStars(int total) async {
    final p = await SharedPreferences.getInstance();
    final out = <int, int>{};
    for (var i = 1; i <= total; i++) {
      out[i] = p.getInt('$_kStarsPrefix$i') ?? 0;
    }
    return out;
  }
}
