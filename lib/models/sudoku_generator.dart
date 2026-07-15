import 'dart:math';
import 'sudoku_game.dart';

class SudokuGenerator {
  final int boardSize;
  final Random _rng;
  int get gridSize => boardSize * boardSize;

  SudokuGenerator({this.boardSize = 3, int? seed})
      : _rng = Random(seed);

  SudokuPuzzle generate({int clues = 30}) {
    final puzzle = SudokuPuzzle(boardSize: boardSize);
    _fillGrid(puzzle.solution);
    for (int r = 0; r < gridSize; r++)
      for (int c = 0; c < gridSize; c++)
        puzzle.cells[r][c] = puzzle.solution[r][c];
    _removeCells(puzzle, clues);
    for (int r = 0; r < gridSize; r++)
      for (int c = 0; c < gridSize; c++)
        puzzle.given[r][c] = puzzle.cells[r][c] != 0;
    return puzzle;
  }

  /// 难度对应的笼子大小概率 [2格, 3格, 4格, 5格]
  List<int> _cageProbs(String difficulty) {
    switch (difficulty) {
      case '入门': return [60, 35, 5, 0];  // 无5格，4格极少
      case '困难': return [30, 30, 20, 20];
      default: return [40, 35, 15, 10]; // 中等
    }
  }

  /// 生成杀手数独
  SudokuPuzzle generateKiller({String difficulty = '中等'}) {
    assert(boardSize == 3, '杀手数独仅支持 3×3');
    const maxAttempts = 50;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final puzzle = SudokuPuzzle(boardSize: boardSize);
      _fillGrid(puzzle.solution);

      if (_generateCages(puzzle, difficulty)) {
        puzzle.killerDifficulty = difficulty;
        // 清空所有格子（杀手数独不给任何数字）
        for (int r = 0; r < gridSize; r++)
          for (int c = 0; c < gridSize; c++) {
            puzzle.cells[r][c] = 0;
            puzzle.given[r][c] = false;
          }
        return puzzle;
      }
    }
    // 保底：返回一个简单难度生成的谜题
    return generateKiller(difficulty: '入门');
  }

  /// 快速生成笼子划分（迭代 + 异形支持，超时则重试）
  bool _generateCages(SudokuPuzzle puzzle, String difficulty) {
    final gs = gridSize;
    final total = gs * gs;
    final probs = _cageProbs(difficulty);
    final dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];

    for (int attempt = 0; attempt < 30; attempt++) {
      final assigned = List.filled(total, -1);
      final cages = <List<int>>[];
      int count4 = 0; // 4格笼子计数（入门难度限制2~3个）

      for (int i = 0; i < total; i++) {
        if (assigned[i] != -1) continue;
        final size = _pickSize(assigned, probs, difficulty, count4);
        if (size < 0) break; // 剩余格子数不合适，重试
        if (size == 4) count4++;

        final cage = <int>[i];
        assigned[i] = cages.length;
        bool ok = true;

        // 从笼子任意边界扩展（支持 L 型等异形）
        while (cage.length < size) {
          final candidates = <int>{};
          for (final idx in cage) {
            final r = idx ~/ gs, c = idx % gs;
            for (final d in dirs) {
              final nr = r + d.$1, nc = c + d.$2;
              if (nr < 0 || nr >= gs || nc < 0 || nc >= gs) continue;
              final nIdx = nr * gs + nc;
              if (assigned[nIdx] == -1) candidates.add(nIdx);
            }
          }
          if (candidates.isEmpty) { ok = false; break; }
          final chosen = candidates.elementAt(_rng.nextInt(candidates.length));
          cage.add(chosen);
          assigned[chosen] = cages.length;
        }

        if (!ok) break;
        cages.add(cage);
      }

      // 检查全部格已分配
      if (assigned.every((a) => a != -1)) {
        // 计算和值写入 puzzle
        puzzle.cages = cages.map((c) {
          int sum = 0;
          for (final idx in c) sum += puzzle.solution[idx ~/ gs][idx % gs];
          return Cage(cellIndices: List.from(c), sum: sum);
        }).toList();
        return true;
      }
    }
    return false;
  }

  /// 根据概率选取笼子大小，-1 表示剩余格子无法组成有效笼子
  int _pickSize(List<int> assigned, List<int> probs, String difficulty, int count4) {
    final remaining = assigned.where((a) => a == -1).length;
    if (remaining < 2) return remaining;

    // 入门难度限制 4 格笼子不超过 3 个
    final max4 = difficulty == '入门' ? (count4 >= 3 ? 0 : 3) : 99;

    // 按概率选取大小
    for (int attempt = 0; attempt < 20; attempt++) {
      final roll = _rng.nextInt(100);
      int cum = 0;
      for (int sz = 2; sz <= 5; sz++) {
        cum += probs[sz - 2];
        if (roll < cum) {
          if (remaining < sz) break;
          if (sz == 4 && count4 >= max4) continue;
          if (sz == 5 && difficulty == '入门') continue;
          final rest = remaining - sz;
          if (rest == 0 || rest >= 2) return sz;
        }
      }
    }
    // fallback: 取能放下的最大尺寸
    for (final sz in [5, 4, 3, 2]) {
      if (remaining >= sz) {
        if (sz == 4 && count4 >= max4) continue;
        if (sz == 5 && difficulty == '入门') continue;
        final rest = remaining - sz;
        if (rest == 0 || rest >= 2) return sz;
      }
    }
    return -1;
  }

  /// 扩展笼子（支持 L 型、阶梯型等异形）
  bool _growCage(List<int> cage, List<int> assigned, int targetSize, int gs) {
    final dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];

    while (cage.length < targetSize) {
      // 收集笼子所有边界上的未分配邻居
      final candidates = <int>{};
      for (final idx in cage) {
        final r = idx ~/ gs, c = idx % gs;
        for (final d in dirs) {
          final nr = r + d.$1, nc = c + d.$2;
          if (nr < 0 || nr >= gs || nc < 0 || nc >= gs) continue;
          final nIdx = nr * gs + nc;
          if (assigned[nIdx] == -1) candidates.add(nIdx);
        }
      }

      if (candidates.isEmpty) return false;

      // 随机选一个候选（可能导致 L 型、T 型等异形）
      final chosen = candidates.elementAt(_rng.nextInt(candidates.length));
      cage.add(chosen);
      assigned[chosen] = assigned[cage[0]];
    }
    return true;
  }

  /// 检查剩余格子数能否组成有效笼子组合
  bool _canFormValidCages(int remaining, List<int> probs) {
    if (remaining == 0) return true;
    if (remaining == 1) return false; // 单格不成笼
    // 尝试用 2~5 的组合拼出剩余格子数
    for (int s = 5; s >= 2; s--) {
      if (remaining >= s && _canFormValidCages(remaining - s, probs)) {
        return true;
      }
    }
    return false;
  }

  /// 按概率生成有序笼子大小列表（从大到小）
  List<int> _weightedSizes(List<int> probs) {
    final result = <int>[];
    for (int size = 2; size <= 5; size++) {
      final weight = probs[size - 2];
      for (int i = 0; i < weight; i++) result.add(size);
    }
    result.shuffle(_rng);
    // 从大到小排序优先尝试（减少死局）
    result.sort((a, b) => b.compareTo(a));
    return result;
  }

  /// 验证杀手数独唯一解
  bool _hasUniqueKillerSolution(SudokuPuzzle puzzle) {
    int count = 0;
    final grid = List.generate(
        gridSize, (r) => List<int>.filled(gridSize, 0));
    // 预计算笼子查找表
    final cageLookup = List.filled(gridSize * gridSize, -1);
    if (puzzle.cages != null) {
      for (int i = 0; i < puzzle.cages!.length; i++) {
        for (final idx in puzzle.cages![i].cellIndices) {
          cageLookup[idx] = i;
        }
      }
    }

    void solve(List<List<int>> g) {
      if (count >= 2) return;
      int? mr, mc;
      for (int r = 0; r < gridSize && mr == null; r++)
        for (int c = 0; c < gridSize && mc == null; c++)
          if (g[r][c] == 0) { mr = r; mc = c; }
      if (mr == null) { count++; return; }
      final rr = mr!, cc = mc!; // 显式非空

      for (int n = 1; n <= gridSize; n++) {
        if (!_isValid(g, rr, cc, n)) continue;
        if (!_cageValid(g, rr, cc, n, puzzle.cages, cageLookup)) continue;
        g[rr][cc] = n;
        solve(g);
        g[rr][cc] = 0;
        if (count >= 2) return;
      }
    }

    // 用正确答案填充初始格（加速求解）
    for (int r = 0; r < gridSize; r++)
      for (int c = 0; c < gridSize; c++)
        grid[r][c] = puzzle.solution[r][c];

    // 清空格子让求解器重新推导
    for (int r = 0; r < gridSize; r++)
      for (int c = 0; c < gridSize; c++)
        grid[r][c] = 0;

    solve(grid);
    return count == 1;
  }

  /// 检查笼子和值约束
  bool _cageValid(List<List<int>> grid, int r, int c, int n,
      List<Cage>? cages, List<int> cageLookup) {
    if (cages == null) return true;
    final idx = r * gridSize + c;
    final ci = cageLookup[idx];
    if (ci < 0) return true;
    final cage = cages[ci];

    int sum = n;
    int empty = 0;
    for (final ci2 in cage.cellIndices) {
      if (ci2 == idx) continue;
      final vr = ci2 ~/ gridSize, vc = ci2 % gridSize;
      if (grid[vr][vc] == 0) empty++;
      else sum += grid[vr][vc];
    }
    if (sum > cage.sum) return false;
    if (sum + empty > cage.sum) return false;     // 最小填 1
    if (sum + empty * gridSize < cage.sum) return false; // 最大填 gridSize
    return true;
  }

  // --- 以下方法保持不变 ---

  bool _fillGrid(List<List<int>> grid) {
    final empty = _findEmpty(grid);
    if (empty == null) return true;
    final (r, c) = empty;
    final nums = List.generate(gridSize, (i) => i + 1)..shuffle(_rng);
    for (final n in nums) {
      if (_isValid(grid, r, c, n)) {
        grid[r][c] = n;
        if (_fillGrid(grid)) return true;
        grid[r][c] = 0;
      }
    }
    return false;
  }

  bool _isValid(List<List<int>> grid, int r, int c, int n) {
    for (int i = 0; i < gridSize; i++) {
      if (grid[r][i] == n) return false;
      if (grid[i][c] == n) return false;
    }
    final br = r - r % boardSize, bc = c - c % boardSize;
    for (int i = br; i < br + boardSize; i++)
      for (int j = bc; j < bc + boardSize; j++)
        if (grid[i][j] == n) return false;
    return true;
  }

  (int, int)? _findEmpty(List<List<int>> grid) {
    for (int r = 0; r < gridSize; r++)
      for (int c = 0; c < gridSize; c++)
        if (grid[r][c] == 0) return (r, c);
    return null;
  }

  void _removeCells(SudokuPuzzle puzzle, int clues) {
    final total = gridSize * gridSize;
    final all = <int>[];
    for (int i = 0; i < total; i++) all.add(i);
    all.shuffle(_rng);
    int target = total - clues;
    for (final pos in all) {
      if (target <= 0) break;
      final r = pos ~/ gridSize, c = pos % gridSize;
      final saved = puzzle.cells[r][c];
      puzzle.cells[r][c] = 0;
      if (boardSize == 3) {
        if (_countSolutions(puzzle.clone(), 2) != 1) {
          puzzle.cells[r][c] = saved;
        } else {
          target--;
        }
      } else {
        target--;
      }
    }
  }

  int _countSolutions(SudokuPuzzle puzzle, int limit) {
    int count = 0;
    void solve(List<List<int>> grid) {
      if (count >= limit) return;
      final empty = _findEmpty(grid);
      if (empty == null) { count++; return; }
      final (r, c) = empty;
      for (int n = 1; n <= gridSize; n++) {
        if (_isValid(grid, r, c, n)) {
          grid[r][c] = n;
          solve(grid);
          grid[r][c] = 0;
          if (count >= limit) return;
        }
      }
    }
    final grid = List.generate(
        gridSize, (r) => List<int>.from(puzzle.cells[r]));
    solve(grid);
    return count;
  }
}
