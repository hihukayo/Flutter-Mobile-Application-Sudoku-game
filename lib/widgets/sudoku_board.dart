import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:google_fonts/google_fonts.dart';
import '../models/sudoku_game.dart';
import '../services/app_theme.dart';

/// 笼子标签颜色：与笼子线条同色系但更鲜艳，自动适配深浅色模式（参考安卓）
Color vividCageColor(
  Color cageColor, {
  double satBoost = 0.15,
  double lightBoost = 0.04,
  double darkBoost = 0.03,
  double maxSat = 0.45,
}) {
  final r = cageColor.r, g = cageColor.g, b = cageColor.b;
  final max = [r, g, b].reduce((a, b) => a > b ? a : b);
  final min = [r, g, b].reduce((a, b) => a < b ? a : b);
  final l = (max + min) / 2;
  var hue = 0.0;
  var sat = 0.0;
  if (max != min) {
    final d = max - min;
    sat = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    hue = (max == r)
        ? ((g - b) / d + (g < b ? 6 : 0)) / 6
        : (max == g)
            ? ((b - r) / d + 2) / 6
            : ((r - g) / d + 4) / 6;
  }
  final sat2 = (sat + satBoost).clamp(0.0, maxSat).toDouble();
  final l2 = l > 0.5
      ? (l + lightBoost).clamp(0.0, 0.8).toDouble()
      : (l + darkBoost).clamp(0.0, 0.5).toDouble();
  return HSLColor.fromAHSL(1, hue * 360, sat2, l2).toColor();
}

/// 笼子标签颜色入口：与笼子边框同色系但略鲜艳（浅色/深色自动适配），不偏离笼子颜色
Color cageLabelColor(BuildContext context) {
  return vividCageColor(context.colors.textSecondary);
}
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
        if (widget.puzzle.isKiller) {
          if (widget.puzzle.isConflictAt(r, c, n)) {
            // 违反笼子约束：整个笼子的格子一起标红
            _errors = widget.puzzle.conflictCells();
          } else {
            _errors.remove('$r,$c');
          }
        } else {
          _errors.remove('$r,$c');
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
    final colors = context.colors;
    final textStyle = const TextStyle();
    final fontSize = _gs == 9 ? 22.0 : 14.0;
    final noteSize = _gs == 9 ? 13.0 : 9.0;
    final isKiller = widget.puzzle.isKiller;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.boardBorder, width: 2.5),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.hardEdge,
      child: isKiller ? _buildKillerGrid(textStyle, fontSize, noteSize, isKiller)
                      : _buildRegularGrid(textStyle, fontSize, noteSize),
    );
  }

  Widget _buildRegularGrid(TextStyle textStyle, double fontSize, double noteSize, {bool uniformThin = false}) {
    final colors = context.colors;
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
          textColor = colors.textPrimary;
          fontWeight = FontWeight.w700;
        } else if (val == 0) {
          textColor = null;
          fontWeight = FontWeight.normal;
        } else if (isError) {
          textColor = kRed;
          fontWeight = FontWeight.w600;
        } else {
          textColor = colors.userInput;
          fontWeight = FontWeight.w600;
        }

        final display = val != 0 ? SudokuPuzzle.displayValue(val) : '';
        // 高亮/选中区域内的细格线加深（参考安卓：四边统一、跳过粗宫线），避免被高亮底色吞掉
        final hlLine = Color.lerp(colors.boardLine, colors.textSecondary, 0.2)!;
        bool cellHl(int rr, int cc) {
          final sr = _selectedRow, sc = _selectedCol;
          if (sr == null || sc == null) return false;
          if (rr == sr && cc == sc) return true;
          return rr == sr || cc == sc ||
              (rr ~/ _bs == sr ~/ _bs && cc ~/ _bs == sc ~/ _bs);
        }
        final rightHl = cellHl(r, c) || (c < _gs - 1 && cellHl(r, c + 1));
        final bottomHl = cellHl(r, c) || (r < _gs - 1 && cellHl(r + 1, c));

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onCellTap(r, c),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? colors.selectedBg
                   : isHighlighted ? colors.highlightBg
                   : colors.boardBg,
              border: Border(
                right: c == _gs - 1
                    ? BorderSide.none
                    : BorderSide(
                        color: (!uniformThin && (c + 1) % _bs == 0) ? colors.boardBorder : (rightHl ? hlLine : colors.boardLine),
                        width: (!uniformThin && (c + 1) % _bs == 0) ? 2 : 0.5,
                      ),
                bottom: r == _gs - 1
                    ? BorderSide.none
                    : BorderSide(
                        color: (!uniformThin && (r + 1) % _bs == 0) ? colors.boardBorder : (bottomHl ? hlLine : colors.boardLine),
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
    final colors = context.colors;
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
                lineColor: colors.boardBorder,
                badColor: kRed,
                labelColor: cageLabelColor(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotes(int r, int c, TextStyle ts, double fontSize) {
    final colors = context.colors;
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
            color: colors.noteText,
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
  final Color lineColor;
  final Color badColor;
  final Color labelColor;

  _CagePainter({required this.puzzle, this.invalidCages = const {}, this.lineColor = kDarkSlate, this.badColor = kRed, this.labelColor = kDarkSlate});

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

    // 先画正常笼子，再画错误笼子（红色最后绘制，确保整圈边框完整变红，不被相邻笼子覆盖）
    for (final isBad in [false, true]) {
      for (int ci = 0; ci < puzzle.cages!.length; ci++) {
        if (invalidCages.contains(ci) != isBad) continue;
        final paint = Paint()
          ..color = isBad ? badColor : lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

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
          // 错误笼子贴棋盘外圈：外圈边框对应线段也标红
          if (isBad) {
            if (r == 0) canvas.drawLine(Offset(x, y), Offset(x + cellSize, y), paint);
            if (r == gs - 1) {
              canvas.drawLine(Offset(x, y + cellSize), Offset(x + cellSize, y + cellSize), paint);
            }
            if (c == 0) canvas.drawLine(Offset(x, y), Offset(x, y + cellSize), paint);
            if (c == gs - 1) {
              canvas.drawLine(Offset(x + cellSize, y), Offset(x + cellSize, y + cellSize), paint);
            }
          }
        }
      }
    }    // 笼子标签：运算符用矢量绘制（+ 与 ÷ 一目了然），结果用文本
    for (final cage in puzzle.cages!) {
      int botR = -1, botC = -1;
      for (final idx in cage.cellIndices) {
        final r = idx ~/ gs, c = idx % gs;
        if (r > botR || (r == botR && c > botC)) { botR = r; botC = c; }
      }
      _paintCageLabel(
        canvas,
        cellRight: botC * cellSize + cellSize,
        cellBottom: botR * cellSize + cellSize,
        label: cage.labelText,
        color: labelColor,
      );
    }
  }


  /// 绘制笼子标签：运算符（+ - × ÷）用矢量绘制，避免小字号下加号与除号难区分
  void _paintCageLabel(
    Canvas canvas, {
    required double cellRight,
    required double cellBottom,
    required String label,
    required Color color,
  }) {
    final op = label.isNotEmpty ? label[0] : '+';
    final numText = label.length > 1 ? label.substring(1) : '';
    final opSize = 7.5;
    final gap = 2.0;
    final half = 2.8;
    final diag = half * 0.7071;
    final strokeW = 1.2;
    final tp = TextPainter(
      text: TextSpan(
        text: numText,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rightMargin = 4.0;
    final rightX = cellRight - rightMargin;
    final topY = cellBottom - 11;
    final totalW = opSize + gap + tp.width;
    final numX = rightX - totalW + opSize + gap;
    tp.paint(canvas, Offset(numX, topY));
    final centerY = topY + tp.height / 2;
    final opCenter = Offset(rightX - totalW + opSize / 2, centerY - 0.7);
    final p = Paint()
      ..color = color
      ..strokeWidth = strokeW;
    switch (op) {
      case '-':
        canvas.drawLine(
          opCenter + Offset(-half, 0),
          opCenter + Offset(half, 0),
          p,
        );
      case '×':
        canvas.drawLine(
          opCenter + Offset(-diag, -diag),
          opCenter + Offset(diag, diag),
          p,
        );
        canvas.drawLine(
          opCenter + Offset(-diag, diag),
          opCenter + Offset(diag, -diag),
          p,
        );
      case '÷':
        // 除号：横杠更长、圆点更大，与加号明显区分（参考安卓），且不压住中心数字
        final divCenter = Offset(opCenter.dx, centerY);
        canvas.drawLine(
          divCenter + Offset(-3.7, 0),
          divCenter + Offset(3.7, 0),
          p,
        );
        canvas.drawCircle(divCenter + Offset(0, -2.5), 0.8, p);
        canvas.drawCircle(divCenter + Offset(0, 2.5), 0.8, p);
      default: // '+'
        canvas.drawLine(
          opCenter + Offset(-half, 0),
          opCenter + Offset(half, 0),
          p,
        );
        canvas.drawLine(
          opCenter + Offset(0, -half),
          opCenter + Offset(0, half),
          p,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _CagePainter oldDelegate) =>
      oldDelegate.invalidCages != invalidCages;
}
