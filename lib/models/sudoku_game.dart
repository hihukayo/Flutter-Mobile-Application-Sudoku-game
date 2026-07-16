/// 杀手数独的虚线框（Cage）
class Cage {
  final List<int> cellIndices; // 格子在棋盘中的索引 (r * gridSize + c)
  final int sum;

  Cage({required this.cellIndices, required this.sum});

  bool contains(int r, int c, int gridSize) =>
      cellIndices.contains(r * gridSize + c);
}

class SudokuPuzzle {
  final int boardSize;    // 3 或 4
  final int gridSize;     // 9 或 16
  final List<List<int>> cells;       // 0=空, 1-9 或 1-16
  final List<List<bool>> given;      // true=题目给的（不可修改）
  final List<List<Set<int>>> notes;  // 笔记模式的小数字
  List<List<int>> solution;          // 完整答案
  List<Cage>? cages;                 // 杀手数独的虚线框，null 表示常规模式
  String killerDifficulty = '中等';   // 杀手数独难度
  List<int>? _cageLookup;            // 缓存：格子索引 → 笼子索引

  bool get isKiller => cages != null;
  List<int> get cageLookup {
    if (_cageLookup != null) return _cageLookup!;
    if (cages == null) return _cageLookup ??= [];
    final lookup = List.filled(gridSize * gridSize, -1);
    for (int i = 0; i < cages!.length; i++) {
      for (final idx in cages![i].cellIndices) {
        lookup[idx] = i;
      }
    }
    _cageLookup = lookup;
    return lookup;
  }

  SudokuPuzzle({this.boardSize = 3})
      : gridSize = boardSize * boardSize,
        cells = List.generate(
            boardSize * boardSize, (_) => List.filled(boardSize * boardSize, 0)),
        given = List.generate(
            boardSize * boardSize, (_) => List.filled(boardSize * boardSize, false)),
        notes = List.generate(
            boardSize * boardSize,
            (_) => List.generate(boardSize * boardSize, (_) => <int>{})),
        solution = List.generate(
            boardSize * boardSize, (_) => List.filled(boardSize * boardSize, 0));

  SudokuPuzzle clone() {
    final p = SudokuPuzzle(boardSize: boardSize);
    for (int r = 0; r < gridSize; r++)
      for (int c = 0; c < gridSize; c++) {
        p.cells[r][c] = cells[r][c];
        p.given[r][c] = given[r][c];
        p.notes[r][c] = Set<int>.from(notes[r][c]);
        p.solution[r][c] = solution[r][c];
      }
    if (cages != null) {
      p.cages = cages!.map((c) => Cage(
        cellIndices: List.from(c.cellIndices), sum: c.sum,
      )).toList();
    }
    return p;
  }

  void setNote(int r, int c, int n) {
    notes[r][c].clear();
    notes[r][c].add(n);
  }

  bool isComplete() {
    for (int r = 0; r < gridSize; r++)
      for (int c = 0; c < gridSize; c++) {
        if (cells[r][c] == 0) return false;
      }
    return true;
  }

  /// 检查在 (r,c) 填 n 是否导致冲突（行列宫重复 或 笼子和值超限）
  bool isConflictAt(int r, int c, int n) {
    // 行列宫重复
    for (int i = 0; i < gridSize; i++) {
      if (i != c && cells[r][i] == n) return true;
      if (i != r && cells[i][c] == n) return true;
    }
    final br = r - r % boardSize, bc = c - c % boardSize;
    for (int ir = br; ir < br + boardSize; ir++)
      for (int ic = bc; ic < bc + boardSize; ic++) {
        if ((ir != r || ic != c) && cells[ir][ic] == n) return true;
      }

    // 笼子和值超限
    if (cages != null) {
      final idx = r * gridSize + c;
      for (final cage in cages!) {
        if (!cage.cellIndices.contains(idx)) continue;
        int sum = n;
        for (final ci in cage.cellIndices) {
          if (ci == idx) continue;
          sum += cells[ci ~/ gridSize][ci % gridSize];
        }
        if (sum > cage.sum) return true;
      }
    }
    return false;
  }

  /// 找出所有冲突格子
  Set<String> conflictCells() {
    final result = <String>{};
    if (cages != null) {
      // 笼子和值超限的格子
      final bad = invalidCages();
      for (final ci in bad) {
        for (final idx in cages![ci].cellIndices) {
          result.add('${idx ~/ gridSize},${idx % gridSize}');
        }
      }
    }
    // 行列宫重复的格子
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (cells[r][c] == 0) continue;
        if (result.contains('$r,$c')) continue;
        if (isConflictAt(r, c, cells[r][c])) result.add('$r,$c');
      }
    }
    return result;
  }

  /// 找出当前填数超过和值的笼子索引
  Set<int> invalidCages() {
    if (cages == null) return {};
    final result = <int>{};
    for (int i = 0; i < cages!.length; i++) {
      int sum = 0;
      for (final idx in cages![i].cellIndices) {
        sum += cells[idx ~/ gridSize][idx % gridSize];
      }
      if (sum > cages![i].sum) result.add(i);
    }
    return result;
  }

  /// 验证行/列/宫唯一性
  bool hasDuplicates() {
    for (int r = 0; r < gridSize; r++) {
      final rowSet = <int>{};
      for (int c = 0; c < gridSize; c++) {
        if (cells[r][c] == 0) continue;
        if (!rowSet.add(cells[r][c])) return true;
      }
    }
    for (int c = 0; c < gridSize; c++) {
      final colSet = <int>{};
      for (int r = 0; r < gridSize; r++) {
        if (cells[r][c] == 0) continue;
        if (!colSet.add(cells[r][c])) return true;
      }
    }
    for (int br = 0; br < gridSize; br += boardSize) {
      for (int bc = 0; bc < gridSize; bc += boardSize) {
        final boxSet = <int>{};
        for (int r = br; r < br + boardSize; r++) {
          for (int c = bc; c < bc + boardSize; c++) {
            if (cells[r][c] == 0) continue;
            if (!boxSet.add(cells[r][c])) return true;
          }
        }
      }
    }
    return false;
  }

  bool isCorrect() {
    for (int r = 0; r < gridSize; r++)
      for (int c = 0; c < gridSize; c++) {
        if (cells[r][c] != solution[r][c]) return false;
      }
    return true;
  }

  /// 判断两个格子是否在同一笼子（杀手数独）
  bool sameCage(int r1, int c1, int r2, int c2) {
    if (cages == null) return false;
    final lookup = cageLookup;
    if (lookup.isEmpty) return false;
    final idx1 = r1 * gridSize + c1;
    final idx2 = r2 * gridSize + c2;
    if (idx1 >= lookup.length || idx2 >= lookup.length) return false;
    return lookup[idx1] >= 0 && lookup[idx1] == lookup[idx2];
  }

  /// 获取指定格子的笼子和值，null 表示不是笼子首格或无笼子
  (int sum, bool isFirst)? cageInfoAt(int r, int c) {
    if (cages == null) return null;
    final lookup = cageLookup;
    if (lookup.isEmpty) return null;
    final idx = r * gridSize + c;
    if (idx >= lookup.length) return null;
    final cageIdx = lookup[idx];
    if (cageIdx < 0) return null;
    final cage = cages![cageIdx];
    // 是笼子中行号最小、列号最大的格子则显示和值
    bool isFirst = true;
    for (final other in cage.cellIndices) {
      final or = other ~/ gridSize, oc = other % gridSize;
      if (or < r || (or == r && oc > c)) { isFirst = false; break; }
    }
    return (cage.sum, isFirst);
  }

  /// 将数值转换为显示字符：1-9 显示数字，10+ 显示 A-F
  static String displayValue(int val) {
    if (val >= 1 && val <= 9) return '$val';
    if (val >= 10 && val <= 16) return String.fromCharCode(0x41 + val - 10); // A-F
    return '';
  }
}
