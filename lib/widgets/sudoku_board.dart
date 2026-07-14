import 'package:flutter/material.dart';
import '../models/sudoku_game.dart';

class SudokuBoard extends StatefulWidget {
  final SudokuPuzzle puzzle;
  final int? selectedNumber;
  final ValueChanged<int>? onCellChanged;

  const SudokuBoard({
    super.key,
    required this.puzzle,
    this.selectedNumber,
    this.onCellChanged,
  });

  @override
  State<SudokuBoard> createState() => SudokuBoardState();
}

class SudokuBoardState extends State<SudokuBoard> {
  int? _selectedRow, _selectedCol;
  final Set<String> _errors = {};

  void clearSelection() {
    setState(() { _selectedRow = null; _selectedCol = null; });
  }

  void fillSelectedCell([int? number]) {
    if (_selectedRow == null || _selectedCol == null) return;
    final r = _selectedRow!, c = _selectedCol!;
    if (widget.puzzle.given[r][c]) return;
    final n = number ?? widget.selectedNumber ?? 0;
    if (n < 1 || n > 9) return;

    setState(() {
      widget.puzzle.cells[r][c] = n;
      _errors.remove('$r,$c');
      // 检查冲突
      if (!_isValidAt(r, c)) _errors.add('$r,$c');
    });
    widget.onCellChanged?.call(n);
  }

  void eraseCell() {
    if (_selectedRow == null || _selectedCol == null) return;
    final r = _selectedRow!, c = _selectedCol!;
    if (widget.puzzle.given[r][c]) return;
    setState(() {
      widget.puzzle.cells[r][c] = 0;
      _errors.remove('$r,$c');
    });
  }

  bool _isValidAt(int r, int c) {
    final n = widget.puzzle.cells[r][c];
    if (n == 0) return true;
    for (int i = 0; i < 9; i++) {
      if (i != c && widget.puzzle.cells[r][i] == n) return false;
      if (i != r && widget.puzzle.cells[i][c] == n) return false;
    }
    final br = r - r % 3, bc = c - c % 3;
    for (int i = br; i < br + 3; i++)
      for (int j = bc; j < bc + 3; j++)
        if ((i != r || j != c) && widget.puzzle.cells[i][j] == n) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF455A64), width: 2.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 81,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 9,
            mainAxisSpacing: 0,
            crossAxisSpacing: 0,
          ),
          itemBuilder: (_, index) {
            final r = index ~/ 9, c = index % 9;
            final val = widget.puzzle.cells[r][c];
            final isGiven = widget.puzzle.given[r][c];
            final isSelected = _selectedRow == r && _selectedCol == c;
            final isError = _errors.contains('$r,$c');
            final isSameNum = val != 0 && widget.selectedNumber == val;
            final isRelated = _selectedRow != null && _selectedCol != null &&
                (r == _selectedRow || c == _selectedCol ||
                 (r - r % 3 == _selectedRow! - _selectedRow! % 3 &&
                  c - c % 3 == _selectedCol! - _selectedCol! % 3));

            return GestureDetector(
              onTap: () => setState(() { _selectedRow = r; _selectedCol = c; }),
              child: Container(
                decoration: BoxDecoration(
                  color: isError ? Colors.red.withOpacity(0.15)
                       : isSelected ? const Color(0xFFBBDEFB)
                       : isSameNum ? const Color(0xFFE3F2FD)
                       : isRelated ? const Color(0xFFF5F5F5)
                       : Colors.white,
                  border: Border(
                    right: BorderSide(color: (c + 1) % 3 == 0 ? const Color(0xFF455A64) : Colors.grey[300]!, width: (c + 1) % 3 == 0 ? 2 : 0.5),
                    bottom: BorderSide(color: (r + 1) % 3 == 0 ? const Color(0xFF455A64) : Colors.grey[300]!, width: (r + 1) % 3 == 0 ? 2 : 0.5),
                  ),
                ),
                alignment: Alignment.center,
                child: val == 0 ? null : Text(
                  '$val',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: isGiven ? FontWeight.bold : FontWeight.normal,
                    color: isError ? Colors.red
                         : isGiven ? const Color(0xFF1A1A2E)
                         : const Color(0xFF0B4CFF),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
