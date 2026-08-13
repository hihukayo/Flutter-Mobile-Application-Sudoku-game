import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:google_fonts/google_fonts.dart';
import '../models/sudoku_game.dart';

class SudokuBoard extends StatefulWidget {
  final SudokuPuzzle puzzle;
  final bool noteMode;
  final bool readOnly;
  final void Function(int r, int c, int oldVal, int newVal, Set<int> oldNotes)? onCellChanged;
  final void Function(int r, int c, Set<int> oldNotes, Set<int> newNotes)? onNoteChanged;
  final VoidCallback? onRefresh;
  final VoidCallback? onRequestInput;

  const SudokuBoard({
    super.key,
    required this.puzzle,
    this.noteMode = false,
    this.readOnly = false,
    this.onCellChanged,
    this.onNoteChanged,
    this.onRefresh,
    this.onRequestInput,
  });

  @override
  State<SudokuBoard> createState() => SudokuBoardState();
}

class SudokuBoardState extends State<SudokuBoard> {
  int? _selectedRow, _selectedCol;
  Set<String> _errors = {};

  int get _gs => widget.puzzle.gridSize;
  int get _bs => widget.puzzle.boardSize;

  /// 清除当前选中格（供物理键盘 Backspace/Delete 调用）
  void clearSelected() {
    if (_selectedRow == null || _selectedCol == null || widget.readOnly) return;
    final r = _selectedRow!, c = _selectedCol!;
    if (widget.puzzle.given[r][c]) return;
    final old = widget.puzzle.cells[r][c];
    final oldNotes = Set<int>.from(widget.puzzle.notes[r][c]);
    if (old == 0 && oldNotes.isEmpty) return;
    setState(() {
      widget.puzzle.cells[r][c] = 0;
      widget.puzzle.notes[r][c].clear();
      _errors.remove('$r,$c');
    });
    if (old != 0) widget.onCellChanged?.call(r, c, old, 0, oldNotes);
    widget.onRefresh?.call();
  }

  /// 从 puzzle 数据重新同步错误状态（供外部 undo/redo 调用）
  void syncErrors() {
    if (widget.puzzle.isKiller) {
      setState(() => _errors = widget.puzzle.conflictCells());
    } else {
      final newErrors = <String>{};
      for (int r = 0; r < widget.puzzle.gridSize; r++) {
        for (int c = 0; c < widget.puzzle.gridSize; c++) {
          final val = widget.puzzle.cells[r][c];
          if (val != 0 && val != widget.puzzle.solution[r][c]) {
            newErrors.add('$r,$c');
          }
        }
      }
      setState(() => _errors = newErrors);
    }
  }

  void fillNumber(int n) {
    if (_selectedRow == null || _selectedCol == null || widget.readOnly) return;
    final r = _selectedRow!, c = _selectedCol!;
    if (widget.puzzle.given[r][c]) return;

    if (widget.noteMode) {
      final oldNotes = Set<int>.from(widget.puzzle.notes[r][c]);
      setState(() {
        if (widget.puzzle.notes[r][c].contains(n)) {
          widget.puzzle.notes[r][c].remove(n);
        } else {
          widget.puzzle.setNote(r, c, n);
        }
      });
      final newNotes = Set<int>.from(widget.puzzle.notes[r][c]);
      widget.onNoteChanged?.call(r, c, oldNotes, newNotes);
    } else {
      final old = widget.puzzle.cells[r][c];
      final oldNotes = Set<int>.from(widget.puzzle.notes[r][c]);
      setState(() {
        widget.puzzle.cells[r][c] = n;
        widget.puzzle.notes[r][c].clear();
        _errors.remove('$r,$c');
        if (widget.puzzle.isKiller) {
          if (widget.puzzle.isConflictAt(r, c, n)) _errors.add('$r,$c');
        } else {
          if (n != widget.puzzle.solution[r][c]) _errors.add('$r,$c');
        }
      });
      widget.onCellChanged?.call(r, c, old, n, oldNotes);
    }
    widget.onRefresh?.call();
  }

  void _onCellTap(int r, int c) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedRow = r;
      _selectedCol = c;
    });
    if (!widget.readOnly) {
      widget.onRequestInput?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle();
    final fontSize = _gs == 9 ? 22.0 : 14.0;
    final noteSize = _gs == 9 ? 13.0 : 9.0;
    final isKiller = widget.puzzle.isKiller;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF455A64), width: 2.5),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.hardEdge,
      child: isKiller ? _buildKillerGrid(textStyle, fontSize, noteSize, isKiller)
                      : _buildRegularGrid(textStyle, fontSize, noteSize),
    );
  }

  Widget _buildRegularGrid(TextStyle textStyle, double fontSize, double noteSize, {bool uniformThin = false}) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _gs * _gs,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _gs, mainAxisSpacing: 0, crossAxisSpacing: 0,
      ),
      itemBuilder: (_, index) {
        final r = index ~/ _gs, c = index % _gs;
        final val = widget.puzzle.cells[r][c];
        final isGiven = widget.puzzle.given[r][c];
        final isSelected = _selectedRow == r && _selectedCol == c;
        final isError = _errors.contains('$r,$c');
        final inSameRow = _selectedRow == r;
        final inSameCol = _selectedCol == c;
        final inSameBox = _selectedRow != null && _selectedCol != null &&
            r ~/ _bs == _selectedRow! ~/ _bs && c ~/ _bs == _selectedCol! ~/ _bs;
        final isHighlighted = (inSameRow || inSameCol || inSameBox) && !isSelected;

        Color? textColor;
        FontWeight fontWeight;
        if (isGiven) {
          textColor = const Color(0xFF1A1A2E);
          fontWeight = FontWeight.w700;
        } else if (val == 0) {
          textColor = null;
          fontWeight = FontWeight.normal;
        } else if (isError) {
          textColor = Colors.red[600];
          fontWeight = FontWeight.w600;
        } else {
          textColor = Colors.green[700];
          fontWeight = FontWeight.w600;
        }

        final display = val != 0 ? SudokuPuzzle.displayValue(val) : '';

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onCellTap(r, c),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFBBDEFB)
                   : isHighlighted ? const Color(0xFFF0F4F8)
                   : Colors.white,
              border: Border(
                right: BorderSide(
                  color: (!uniformThin && (c + 1) % _bs == 0) ? const Color(0xFF455A64) : Colors.grey[300]!,
                  width: (!uniformThin && (c + 1) % _bs == 0) ? 2 : 0.5,
                ),
                bottom: BorderSide(
                  color: (!uniformThin && (r + 1) % _bs == 0) ? const Color(0xFF455A64) : Colors.grey[300]!,
                  width: (!uniformThin && (r + 1) % _bs == 0) ? 2 : 0.5,
                ),
              ),
            ),
            child: val != 0
                ? Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(display, style: textStyle.copyWith(
                        fontSize: fontSize, fontWeight: fontWeight, color: textColor,
                      )),
                    ),
                  )
                : widget.puzzle.notes[r][c].isNotEmpty
                    ? _buildNotes(r, c, textStyle, noteSize)
                    : null,
          ),
        );
      },
    );
  }

  Widget _buildKillerGrid(TextStyle textStyle, double fontSize, double noteSize, bool isKiller) {
    return Stack(
      children: [
        _buildRegularGrid(textStyle, fontSize, noteSize, uniformThin: true),
        // 笼子边框 + 标签（IgnorePointer 确保不拦截点击）
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _CagePainter(
                puzzle: widget.puzzle,
                invalidCages: widget.puzzle.invalidCages(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotes(int r, int c, TextStyle ts, double fontSize) {
    if (widget.puzzle.notes[r][c].isEmpty) return const SizedBox.shrink();
    final n = widget.puzzle.notes[r][c].first;
    return Padding(
      padding: EdgeInsets.all(_gs == 9 ? 3 : 2),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          n <= 9 ? '$n' : String.fromCharCode(0x41 + n - 10),
          style: ts.copyWith(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF0B4CFF),
          ),
        ),
      ),
    );
  }
}

// ---- 算数数独笼子边界 + 标签绘制器 ----
class _CagePainter extends CustomPainter {
  final SudokuPuzzle puzzle;
  final Set<int> invalidCages;

  _CagePainter({required this.puzzle, this.invalidCages = const {}});

  @override
  void paint(Canvas canvas, Size size) {
    final gs = puzzle.gridSize;
    final cellSize = size.width / gs;

    if (puzzle.cages == null) return;
    // 每格 → 笼子索引
    final cellCage = List.filled(gs * gs, -1);
    for (int i = 0; i < puzzle.cages!.length; i++) {
      for (final idx in puzzle.cages![i].cellIndices) {
        cellCage[idx] = i;
      }
    }

    // 逐笼绘制边界（红 = 约束被违反，深色 = 正常，与安卓端一致沿格线绘制）
    for (int ci = 0; ci < puzzle.cages!.length; ci++) {
      final isBad = invalidCages.contains(ci);
      final paint = Paint()
        ..color = isBad ? const Color(0xFFE53935) : const Color(0xFF455A64)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isBad ? 1.2 : 2.0;

      final cells = puzzle.cages![ci].cellIndices.toSet();
      for (final idx in cells) {
        final r = idx ~/ gs, c = idx % gs;
        final x = c * cellSize, y = r * cellSize;

        if (r > 0 && !cells.contains((r - 1) * gs + c)) {
          canvas.drawLine(Offset(x, y), Offset(x + cellSize, y), paint);
        }
        if (r < gs - 1 && !cells.contains((r + 1) * gs + c)) {
          canvas.drawLine(Offset(x, y + cellSize), Offset(x + cellSize, y + cellSize), paint);
        }
        if (c > 0 && !cells.contains(r * gs + (c - 1))) {
          canvas.drawLine(Offset(x, y), Offset(x, y + cellSize), paint);
        }
        if (c < gs - 1 && !cells.contains(r * gs + (c + 1))) {
          canvas.drawLine(Offset(x + cellSize, y), Offset(x + cellSize, y + cellSize), paint);
        }
      }
    }

    // 笼子标签：每个笼子显示 运算符+结果（如 +10、-2、×100、÷3）
    for (final cage in puzzle.cages!) {
      int botR = -1, botC = -1;
      for (final idx in cage.cellIndices) {
        final r = idx ~/ gs, c = idx % gs;
        if (r > botR || (r == botR && c > botC)) { botR = r; botC = c; }
      }
      final tp = TextPainter(
        text: TextSpan(
          text: cage.labelText,
          style: const TextStyle(
            color: Color(0xFF455A64), fontSize: 8, fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // 统一右内缩，避免与棋盘右边框重叠（与安卓端一致）
      tp.paint(canvas, Offset(botC * cellSize + cellSize - 2 - tp.width, botR * cellSize + cellSize - 9));
    }
  }

  @override
  bool shouldRepaint(covariant _CagePainter oldDelegate) =>
      oldDelegate.invalidCages != invalidCages;
}
