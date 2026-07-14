class SudokuPuzzle {
  final int size = 9;
  final List<List<int>> cells;    // 0=空, 1-9=数字
  final List<List<bool>> given;   // true=题目给的（不可修改）
  List<List<int>> solution;       // 完整答案

  SudokuPuzzle()
      : cells = List.generate(9, (_) => List.filled(9, 0)),
        given = List.generate(9, (_) => List.filled(9, false)),
        solution = List.generate(9, (_) => List.filled(9, 0));

  SudokuPuzzle clone() {
    final p = SudokuPuzzle();
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) {
        p.cells[r][c] = cells[r][c];
        p.given[r][c] = given[r][c];
        p.solution[r][c] = solution[r][c];
      }
    return p;
  }

  bool isComplete() {
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++)
        if (cells[r][c] == 0) return false;
    return true;
  }

  bool isCorrect() {
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++)
        if (cells[r][c] != solution[r][c]) return false;
    return true;
  }
}
