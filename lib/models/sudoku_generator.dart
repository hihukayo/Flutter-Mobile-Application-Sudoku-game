import 'dart:math';
import 'sudoku_game.dart';

class SudokuGenerator {
  final Random _rng;
  SudokuGenerator([int? seed]) : _rng = Random(seed);

  SudokuPuzzle generate({int clues = 30}) {
    final puzzle = SudokuPuzzle();
    _fillGrid(puzzle.solution);
    // 复制答案到题目
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++)
        puzzle.cells[r][c] = puzzle.solution[r][c];
    // 移除数字
    _removeCells(puzzle, clues);
    // 标记题目格
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++)
        puzzle.given[r][c] = puzzle.cells[r][c] != 0;
    return puzzle;
  }

  bool _fillGrid(List<List<int>> grid) {
    final empty = _findEmpty(grid);
    if (empty == null) return true;
    final (r, c) = empty;
    final nums = [1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle(_rng);
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
    for (int i = 0; i < 9; i++) {
      if (grid[r][i] == n) return false;
      if (grid[i][c] == n) return false;
    }
    final br = r - r % 3, bc = c - c % 3;
    for (int i = br; i < br + 3; i++)
      for (int j = bc; j < bc + 3; j++)
        if (grid[i][j] == n) return false;
    return true;
  }

  (int, int)? _findEmpty(List<List<int>> grid) {
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++)
        if (grid[r][c] == 0) return (r, c);
    return null;
  }

  void _removeCells(SudokuPuzzle puzzle, int clues) {
    final all = <int>[];
    for (int i = 0; i < 81; i++) all.add(i);
    all.shuffle(_rng);
    int target = 81 - clues;
    for (final pos in all) {
      if (target <= 0) break;
      final r = pos ~/ 9, c = pos % 9;
      final saved = puzzle.cells[r][c];
      puzzle.cells[r][c] = 0;
      // 验证唯一解
      if (_countSolutions(puzzle.clone(), 2) != 1) {
        puzzle.cells[r][c] = saved; // 多解，放回去
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
      for (int n = 1; n <= 9; n++) {
        if (_isValid(grid, r, c, n)) {
          grid[r][c] = n;
          solve(grid);
          grid[r][c] = 0;
          if (count >= limit) return;
        }
      }
    }
    final grid = List.generate(9, (r) => List<int>.from(puzzle.cells[r]));
    solve(grid);
    return count;
  }
}
