import '../models/chicken_color.dart';
import '../models/level.dart';

/// Map legend (cells are separated by spaces):
///  .   empty grass
///  #   obstacle (impassable)
///  r/b/y/g  nest of that color
///  R/B/Y/G  chicken of that color (cell underneath is empty)
LevelData _build(int index, List<String> rows, int par) {
  final cols = rows.first.split(' ').length;
  final grid = <List<CellData>>[];
  final chickens = <ChickenSpawn>[];
  for (var r = 0; r < rows.length; r++) {
    final cells = rows[r].split(' ');
    assert(cells.length == cols, 'Level $index row $r has wrong width');
    final rowList = <CellData>[];
    for (var c = 0; c < cols; c++) {
      switch (cells[c]) {
        case '.':
          rowList.add(const CellData.empty());
          break;
        case '#':
          rowList.add(const CellData.obstacle());
          break;
        case 'r':
          rowList.add(const CellData.nest(ChickenColor.red));
          break;
        case 'b':
          rowList.add(const CellData.nest(ChickenColor.blue));
          break;
        case 'y':
          rowList.add(const CellData.nest(ChickenColor.yellow));
          break;
        case 'g':
          rowList.add(const CellData.nest(ChickenColor.green));
          break;
        case 'R':
          rowList.add(const CellData.empty());
          chickens.add(ChickenSpawn(r, c, ChickenColor.red));
          break;
        case 'B':
          rowList.add(const CellData.empty());
          chickens.add(ChickenSpawn(r, c, ChickenColor.blue));
          break;
        case 'Y':
          rowList.add(const CellData.empty());
          chickens.add(ChickenSpawn(r, c, ChickenColor.yellow));
          break;
        case 'G':
          rowList.add(const CellData.empty());
          chickens.add(ChickenSpawn(r, c, ChickenColor.green));
          break;
        default:
          throw StateError('Unknown cell "${cells[c]}" in level $index');
      }
    }
    grid.add(rowList);
  }
  return LevelData(
    index: index,
    rows: rows.length,
    cols: cols,
    grid: grid,
    chickens: chickens,
    parMoves: par,
  );
}

final List<LevelData> kLevels = [
  // ---- Tier 1 (1-8): 3x3 grid, gentle intro ----
  _build(1, [
    'R . r',
    '. . .',
    '. . .',
  ], 2),
  _build(2, [
    'R . .',
    '. . .',
    'r . .',
  ], 2),
  _build(3, [
    'R . .',
    '. . .',
    '. . r',
  ], 4),
  _build(4, [
    'R . r',
    '. . .',
    'B . b',
  ], 4),
  _build(5, [
    'R . b',
    '. . .',
    'B . r',
  ], 8),
  _build(6, [
    '. R .',
    '. . .',
    'b . r',
  ], 5),
  _build(7, [
    'R . . b',
    '. . . .',
    'r . . B',
  ], 6),
  _build(8, [
    'R . Y .',
    '. . . .',
    'r . . y',
  ], 7),

  // ---- Tier 2 (9-16): 4x4 grid, three chickens ----
  _build(9, [
    'R . . r',
    '. . . .',
    '. . . .',
    'B . . b',
  ], 6),
  _build(10, [
    'R . . b',
    '. . . .',
    '. . . .',
    'B . . r',
  ], 10),
  _build(11, [
    'R Y B .',
    '. . . .',
    '. . . .',
    'r y b .',
  ], 9),
  _build(12, [
    'R . . r',
    '. # # .',
    '. # # .',
    'B . . b',
  ], 6),
  _build(13, [
    '. R . .',
    '. . . y',
    'Y . . .',
    '. . r .',
  ], 10),
  _build(14, [
    'R . . G',
    '. # . .',
    '. . # .',
    'g . . r',
  ], 12),
  _build(15, [
    'R B . .',
    '. . # .',
    '. # . .',
    '. . b r',
  ], 10),
  _build(16, [
    'R . Y .',
    '. # . .',
    '. . # .',
    '. y . r',
  ], 12),

  // ---- Tier 3 (17-24): 5x4 grid, more obstacles ----
  _build(17, [
    'R . . b',
    '. . . .',
    '. # # .',
    '. . . .',
    'B . . r',
  ], 12),
  _build(18, [
    'R Y . .',
    '. . . .',
    '# . # .',
    '. . . .',
    '. . y r',
  ], 12),
  _build(19, [
    'R . . G',
    '. . . .',
    '. # # .',
    '. . . .',
    'g . . r',
  ], 14),
  _build(20, [
    '. R B .',
    '. . . .',
    '# . . #',
    '. . . .',
    '. b r .',
  ], 12),
  _build(21, [
    'R Y B G',
    '. . . .',
    '. # # .',
    '. . . .',
    'r y b g',
  ], 14),
  _build(22, [
    'R . . r',
    '. Y . .',
    '. # # .',
    '. . y .',
    'B . . b',
  ], 14),
  _build(23, [
    'R . # b',
    '. . . .',
    '# . . #',
    '. . . .',
    'B # . r',
  ], 16),
  _build(24, [
    '. R . G',
    'Y . . .',
    '# . # .',
    '. . . g',
    '. y r B',
  ], 18),

  // ---- Tier 4 (25-32): 5x5 grid, full color set, harder mazes ----
  _build(25, [
    'R . . . r',
    '. . . . .',
    '. . # . .',
    '. . . . .',
    'B . . . b',
  ], 12),
  _build(26, [
    'R . . . b',
    '. # . # .',
    '. . . . .',
    '. # . # .',
    'B . . . r',
  ], 16),
  _build(27, [
    'R Y B . .',
    '. . . . .',
    '. . # . .',
    '. . . . .',
    '. . r y b',
  ], 16),
  _build(28, [
    'R . G . r',
    '. . . . .',
    'Y # . # y',
    '. . . . .',
    'B . g . b',
  ], 20),
  _build(29, [
    '. R . B .',
    '. . . . .',
    '# . # . #',
    '. . . . .',
    '. b . r .',
  ], 18),
  _build(30, [
    'R Y . B G',
    '. . . . .',
    '# . # . #',
    '. . . . .',
    'g b . y r',
  ], 22),
  _build(31, [
    'R . . . r',
    '. . Y . .',
    '. # . # .',
    '. . y . .',
    'B . . . b',
  ], 20),
  _build(32, [
    'R B Y G .',
    '. . . . .',
    '# # . # #',
    '. . . . .',
    '. g y b r',
  ], 22),

  // ---- Tier 5 (33-40): 6x5 grid, maze-like puzzles ----
  _build(33, [
    'R . . . r',
    '. # # # .',
    '. . . . .',
    '. # # # .',
    '. . . . .',
    'B . . . b',
  ], 18),
  _build(34, [
    '. R B . .',
    '. . . . .',
    '# . # . #',
    '. . . . .',
    '. . . . .',
    '. b r . .',
  ], 20),
  _build(35, [
    'R . G . r',
    '. . . . .',
    '. # . # .',
    'Y . . . y',
    '. # . # .',
    'B . g . b',
  ], 24),
  _build(36, [
    'R Y . B G',
    '. . . . .',
    '# . # . #',
    '. . . . .',
    '# . # . #',
    'g b . y r',
  ], 26),
  _build(37, [
    '. R . B .',
    'Y . . . G',
    '# . # . #',
    '. . . . .',
    'g . # . y',
    '. b . r .',
  ], 26),
  _build(38, [
    'R . . . b',
    '. # . # .',
    '. . Y . .',
    'B . . . r',
    '. # . # .',
    '. . y . .',
  ], 28),
  _build(39, [
    'R B Y G .',
    '. . . . .',
    '# # . # #',
    '. . . . .',
    '# . . . #',
    '. r b y g',
  ], 28),
  _build(40, [
    'R . G . r',
    '. # . # .',
    'B . . . b',
    '. # . # .',
    'Y . . . y',
    '. . g . .',
  ], 30),
];
