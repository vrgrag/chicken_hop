import 'dart:async';

import 'package:flutter/material.dart';

import '../data/levels.dart';
import '../models/chicken_color.dart';
import '../models/level.dart';
import '../services/progress_service.dart';

class GameScreen extends StatefulWidget {
  final int levelIndex;
  const GameScreen({super.key, required this.levelIndex});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  late LevelData _level;
  final _progress = ProgressService();

  /// Chicken color at each grid position. null means empty.
  late List<List<ChickenColor?>> _board;

  /// Selected chicken cell coordinates (row, col) or null.
  (int, int)? _selected;

  int _moves = 0;
  bool _won = false;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _level = kLevels[widget.levelIndex - 1];
    _resetBoard();
  }

  void _resetBoard() {
    _board = List.generate(
      _level.rows,
      (r) => List<ChickenColor?>.filled(_level.cols, null),
    );
    for (final spawn in _level.chickens) {
      _board[spawn.row][spawn.col] = spawn.color;
    }
    _selected = null;
    _moves = 0;
    _won = false;
    _animating = false;
  }

  bool _isAdjacent(int r1, int c1, int r2, int c2) {
    final dr = (r1 - r2).abs();
    final dc = (c1 - c2).abs();
    return (dr == 1 && dc == 0) || (dr == 0 && dc == 1);
  }

  void _onCellTap(int r, int c) {
    if (_won || _animating) return;
    final chickenHere = _board[r][c];
    final cell = _level.grid[r][c];

    if (cell.type == CellType.obstacle) {
      setState(() => _selected = null);
      return;
    }

    if (_selected == null) {
      if (chickenHere != null) {
        setState(() => _selected = (r, c));
      }
      return;
    }

    final (sr, sc) = _selected!;

    if (sr == r && sc == c) {
      setState(() => _selected = null);
      return;
    }

    if (!_isAdjacent(sr, sc, r, c)) {
      if (chickenHere != null) {
        setState(() => _selected = (r, c));
      } else {
        setState(() => _selected = null);
      }
      return;
    }

    setState(() {
      final moving = _board[sr][sc];
      _board[r][c] = moving;
      _board[sr][sc] = chickenHere;
      _selected = null;
      _moves++;
    });

    _checkWin();
  }

  void _checkWin() {
    for (var r = 0; r < _level.rows; r++) {
      for (var c = 0; c < _level.cols; c++) {
        final chicken = _board[r][c];
        if (chicken == null) continue;
        final nestColor = _level.grid[r][c].nestColor;
        if (nestColor != chicken) return;
      }
    }
    int needed = 0;
    for (var r = 0; r < _level.rows; r++) {
      for (var c = 0; c < _level.cols; c++) {
        if (_level.grid[r][c].nestColor != null) needed++;
      }
    }
    int placed = 0;
    for (var r = 0; r < _level.rows; r++) {
      for (var c = 0; c < _level.cols; c++) {
        if (_board[r][c] != null &&
            _level.grid[r][c].nestColor == _board[r][c]) {
          placed++;
        }
      }
    }
    if (placed < needed) return;
    _onWin();
  }

  int _calcStars() {
    if (_moves <= _level.parMoves) return 3;
    if (_moves <= _level.parMoves + 3) return 2;
    return 1;
  }

  Future<void> _onWin() async {
    _won = true;
    final stars = _calcStars();
    await _progress.setStars(_level.index, stars);
    await _progress.unlockNext(_level.index, kLevels.length);
    if (!mounted) return;
    Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _showWinDialog(stars);
    });
  }

  void _showWinDialog(int stars) {
    final hasNext = _level.index < kLevels.length;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE9B5),
            border: Border.all(color: const Color(0xFF5B3A1B), width: 4),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'LEVEL COMPLETE!',
                style: TextStyle(
                  color: Color(0xFF5B3A1B),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final filled = i < stars;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      filled ? Icons.star : Icons.star_border,
                      color: filled
                          ? const Color(0xFFFF8C00)
                          : const Color(0xFF5B3A1B),
                      size: 50,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),
              Text(
                'Moves: $_moves  (Par: ${_level.parMoves})',
                style: const TextStyle(
                  color: Color(0xFF5B3A1B),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _DialogBtn(
                    icon: Icons.home,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                  ),
                  _DialogBtn(
                    icon: Icons.refresh,
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(_resetBoard);
                    },
                  ),
                  if (hasNext)
                    _DialogBtn(
                      icon: Icons.arrow_forward,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) =>
                                GameScreen(levelIndex: _level.index + 1),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
          Container(color: const Color(0x44000000)),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  level: _level.index,
                  moves: _moves,
                  par: _level.parMoves,
                  onBack: () => Navigator.of(context).pop(),
                  onReset: () => setState(_resetBoard),
                ),
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxW = constraints.maxWidth - 24;
                        final maxH = constraints.maxHeight - 24;
                        final cellW = maxW / _level.cols;
                        final cellH = maxH / _level.rows;
                        final cell = cellW < cellH ? cellW : cellH;
                        final boardW = cell * _level.cols;
                        final boardH = cell * _level.rows;
                        return Container(
                          width: boardW + 16,
                          height: boardH + 16,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5B3A1B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFFFC93C),
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 10,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: boardW,
                            height: boardH,
                            child: _Board(
                              level: _level,
                              board: _board,
                              cellSize: cell,
                              selected: _selected,
                              onTap: _onCellTap,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Tap a chicken, then tap a neighbor to swap or hop.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 4,
                          color: Color(0x88000000),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int level;
  final int moves;
  final int par;
  final VoidCallback onBack;
  final VoidCallback onReset;

  const _TopBar({
    required this.level,
    required this.moves,
    required this.par,
    required this.onBack,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          _CircleIcon(icon: Icons.arrow_back, onTap: onBack),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF5B3A1B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFFC93C),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LEVEL $level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    'Moves: $moves / Par $par',
                    style: const TextStyle(
                      color: Color(0xFFFFE9B5),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CircleIcon(icon: Icons.refresh, onTap: onReset),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIcon({required this.icon, required this.onTap});

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

class _Board extends StatelessWidget {
  final LevelData level;
  final List<List<ChickenColor?>> board;
  final double cellSize;
  final (int, int)? selected;
  final void Function(int row, int col) onTap;

  const _Board({
    required this.level,
    required this.board,
    required this.cellSize,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (var r = 0; r < level.rows; r++)
          for (var c = 0; c < level.cols; c++)
            Positioned(
              left: c * cellSize,
              top: r * cellSize,
              width: cellSize,
              height: cellSize,
              child: _Cell(
                row: r,
                col: c,
                cell: level.grid[r][c],
                onTap: () => onTap(r, c),
              ),
            ),
        for (var r = 0; r < level.rows; r++)
          for (var c = 0; c < level.cols; c++)
            if (board[r][c] != null)
              AnimatedPositioned(
                key: ValueKey('chicken_${board[r][c]}_$r$c'),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                left: c * cellSize,
                top: r * cellSize,
                width: cellSize,
                height: cellSize,
                child: IgnorePointer(
                  ignoring: true,
                  child: _Chicken(
                    color: board[r][c]!,
                    selected: selected != null &&
                        selected!.$1 == r &&
                        selected!.$2 == c,
                  ),
                ),
              ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final int row;
  final int col;
  final CellData cell;
  final VoidCallback onTap;

  const _Cell({
    required this.row,
    required this.col,
    required this.cell,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = (row + col).isEven;
    final tileAsset =
        isDark ? 'assets/dark_gras.webp' : 'assets/ligth_gras.webp';
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.all(1.0),
            child: Image.asset(tileAsset, fit: BoxFit.cover),
          ),
          if (cell.type == CellType.obstacle)
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF3A2510),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: const Color(0xFF1F1408), width: 2),
                ),
              ),
            ),
          if (cell.type == CellType.nest)
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Image.asset(
                cell.nestColor!.nestAsset,
                fit: BoxFit.contain,
              ),
            ),
        ],
      ),
    );
  }
}

class _Chicken extends StatelessWidget {
  final ChickenColor color;
  final bool selected;
  const _Chicken({required this.color, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.accent.withValues(alpha: 0.85),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 4,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: Image.asset(color.chickenAsset, fit: BoxFit.contain),
      ),
    );
  }
}

class _DialogBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _DialogBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF5B3A1B),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFC93C), width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
