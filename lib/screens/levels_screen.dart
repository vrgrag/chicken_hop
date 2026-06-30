import 'package:flutter/material.dart';

import '../data/levels.dart';
import '../services/progress_service.dart';
import 'game_screen.dart';

class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  final _progress = ProgressService();
  int _unlocked = 1;
  Map<int, int> _stars = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await _progress.getUnlocked();
    final s = await _progress.getAllStars(kLevels.length);
    if (!mounted) return;
    setState(() {
      _unlocked = u;
      _stars = s;
      _loaded = true;
    });
  }

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
          Container(color: const Color(0x33000000)),
          SafeArea(
            child: Column(
              children: [
                _Header(onBack: () => Navigator.of(context).pop()),
                Expanded(
                  child: !_loaded
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: kLevels.length,
                          itemBuilder: (context, i) {
                            final level = i + 1;
                            final isLocked = level > _unlocked;
                            final stars = _stars[level] ?? 0;
                            return _LevelTile(
                              level: level,
                              locked: isLocked,
                              stars: stars,
                              onTap: isLocked
                                  ? null
                                  : () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => GameScreen(
                                            levelIndex: level,
                                          ),
                                        ),
                                      );
                                      _load();
                                    },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _CircleButton(icon: Icons.arrow_back, onTap: onBack),
          const Spacer(),
          const Text(
            'SELECT LEVEL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              shadows: [
                Shadow(
                  offset: Offset(0, 2),
                  blurRadius: 4,
                  color: Color(0xAA000000),
                ),
              ],
            ),
          ),
          const Spacer(),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF5B3A1B),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFC93C), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int level;
  final bool locked;
  final int stars;
  final VoidCallback? onTap;

  const _LevelTile({
    required this.level,
    required this.locked,
    required this.stars,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: locked
              ? const Color(0xFF4D6E3A)
              : const Color(0xFFFFC93C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF5B3A1B),
            width: 3,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (locked)
              const Icon(Icons.lock, color: Colors.white, size: 28)
            else
              Text(
                '$level',
                style: const TextStyle(
                  color: Color(0xFF5B3A1B),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            const SizedBox(height: 4),
            if (!locked)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final filled = i < stars;
                  return Icon(
                    filled ? Icons.star : Icons.star_border,
                    size: 14,
                    color: filled
                        ? const Color(0xFFFF8C00)
                        : const Color(0xFF5B3A1B),
                  );
                }),
              )
            else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
