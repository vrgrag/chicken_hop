import 'chicken_color.dart';

enum CellType { empty, obstacle, nest }

class CellData {
  final CellType type;
  final ChickenColor? nestColor;

  const CellData.empty()
      : type = CellType.empty,
        nestColor = null;

  const CellData.obstacle()
      : type = CellType.obstacle,
        nestColor = null;

  const CellData.nest(ChickenColor color)
      : type = CellType.nest,
        nestColor = color;
}

class ChickenSpawn {
  final int row;
  final int col;
  final ChickenColor color;

  const ChickenSpawn(this.row, this.col, this.color);
}

class LevelData {
  final int index;
  final int rows;
  final int cols;
  final List<List<CellData>> grid;
  final List<ChickenSpawn> chickens;
  final int parMoves;

  const LevelData({
    required this.index,
    required this.rows,
    required this.cols,
    required this.grid,
    required this.chickens,
    required this.parMoves,
  });
}
