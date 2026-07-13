import 'package:flutter/material.dart';
import '../models/masyu_game.dart';

class _EdgeKey {
  final bool isH;
  final int r, c;
  const _EdgeKey(this.isH, this.r, this.c);
  @override bool operator ==(Object o) => o is _EdgeKey && isH == o.isH && r == o.r && c == o.c;
  @override int get hashCode => Object.hash(isH, r, c);
}

class MasyuBoard extends StatefulWidget {
  final MasyuPuzzle puzzle;
  const MasyuBoard({super.key, required this.puzzle});
  @override State<MasyuBoard> createState() => _MasyuBoardState();
}

class _MasyuBoardState extends State<MasyuBoard> {
  double _spacing = 0, _offsetX = 0, _offsetY = 0;
  final List<List<int>> _dragPath = [];
  int _dragMode = 0; // 0=未知, 1=画线, -1=擦线
  final Set<_EdgeKey> _previewEdges = {};
  bool _loopComplete = false;
  Offset? _dragTail; // 鼠标当前位置（用于画"橡皮筋"尾巴）

  void _calcLayout(BoxConstraints c) {
    final p = widget.puzzle;
    final a = (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight) - 24;
    _spacing = a / (p.cols + 2);
    _offsetX = (c.maxWidth - _spacing * (p.cols + 2)) / 2;
    _offsetY = (c.maxHeight - _spacing * (p.rows + 2)) / 2;
  }

  // ===== dot 坐标系 (0..cols, 0..rows) =====

  /// 像素 → dot 坐标 (r, c)，范围 0..rows, 0..cols
  List<int>? _posToDot(Offset pos) {
    final bx = pos.dx - _offsetX, by = pos.dy - _offsetY;
    final c = ((bx - _spacing) / _spacing).round();
    final r = ((by - _spacing) / _spacing).round();
    if (c < 0 || c > widget.puzzle.cols || r < 0 || r > widget.puzzle.rows) return null;
    final dx = (bx - _spacing - c * _spacing).abs();
    final dy = (by - _spacing - r * _spacing).abs();
    if (dx > _spacing * 0.48 || dy > _spacing * 0.48) return null;
    return [r, c];
  }

  bool _dotsMatch(List<int> a, List<int> b) => a[0] == b[0] && a[1] == b[1];

  /// 相邻 dot 之间的边
  ///   右移 (r,c)→(r,c+1)：hEdges[r][c]
  ///   下移 (r,c)→(r+1,c)：vEdges[r][c]
  ///   左移 (r,c)→(r,c-1)：hEdges[r][c-1]
  ///   上移 (r,c)→(r-1,c)：vEdges[r-1][c]
  _EdgeKey? _edgeBetween(List<int> a, List<int> b) {
    final dr = b[0] - a[0], dc = b[1] - a[1];
    if (dr.abs() + dc.abs() != 1) return null;
    if (dr == 0) return _EdgeKey(true, a[0], dc > 0 ? a[1] : b[1]);
    return _EdgeKey(false, dr > 0 ? a[0] : b[0], a[1]);
  }

  /// 自动补全路径中间的 dot
  List<List<int>> _fill(List<int> a, List<int> b) {
    final r = <List<int>>[];
    final dr = b[0] - a[0], dc = b[1] - a[1];
    if (dr != 0 && dc != 0) return r;
    final sr = dr == 0 ? 0 : (dr > 0 ? 1 : -1);
    final sc = dc == 0 ? 0 : (dc > 0 ? 1 : -1);
    int rr = a[0] + sr, cc = a[1] + sc;
    while (rr != b[0] || cc != b[1]) { r.add([rr, cc]); rr += sr; cc += sc; }
    r.add([b[0], b[1]]);
    return r;
  }

  // ---- 边状态读写 ----

  bool _isLine(_EdgeKey k) {
    try {
      if (k.isH) return widget.puzzle.hEdges[k.r][k.c] == EdgeState.line;
      return widget.puzzle.vEdges[k.r][k.c] == EdgeState.line;
    } catch (_) { return false; }
  }

  void _setLine(_EdgeKey k, bool v) {
    try {
      if (k.isH) widget.puzzle.hEdges[k.r][k.c] = v ? EdgeState.line : EdgeState.none;
      else widget.puzzle.vEdges[k.r][k.c] = v ? EdgeState.line : EdgeState.none;
    } catch (_) {}
  }

  void _rebuildPreview() {
    _previewEdges.clear();
    for (int i = 0; i < _dragPath.length - 1; i++) {
      final e = _edgeBetween(_dragPath[i], _dragPath[i + 1]);
      if (e != null) _previewEdges.add(e);
    }
    if (_loopComplete && _dragPath.length >= 2) {
      final e = _edgeBetween(_dragPath.last, _dragPath[0]);
      if (e != null) _previewEdges.add(e);
    }
  }

  /// 单点切换：遍历四个方向找第一条存在的边
  void _toggleNearestEdge(List<int> dot) {
    const dirs = [
      [0, 1], [0, -1], [1, 0], [-1, 0],
    ];
    final rows = widget.puzzle.rows, cols = widget.puzzle.cols;
    for (final d in dirs) {
      final nr = dot[0] + d[0], nc = dot[1] + d[1];
      if (nc < 0 || nc > cols || nr < 0 || nr > rows) continue;
      final k = _edgeBetween(dot, [nr, nc]);
      if (k != null) { _setLine(k, !_isLine(k)); setState(() {}); return; }
    }
  }

  // ---- 事件处理 ----

  void _onDown(Offset pos) {
    final d = _posToDot(pos);
    if (d == null) return;
    _dragTail = null;
    _dragPath.clear(); _dragPath.add(d);
    _dragMode = 0; _previewEdges.clear(); _loopComplete = false; setState(() {});
  }

  void _onMove(Offset pos) {
    if (_dragPath.isEmpty) return;
    final dot = _posToDot(pos);
    if (dot == null) {
      // 鼠标在两个 dot 之间 → 通过位置估算方向，更新预览
      if (_dragPath.isNotEmpty && _dragMode == 0 && _dragPath.length >= 2) {
        // 已经检测过模式则不需再处理
      }
      return;
    }
    if (_dotsMatch(dot, _dragPath.last)) return;
    if (_loopComplete) _loopComplete = false;

    int dr = dot[0] - _dragPath.last[0], dc = dot[1] - _dragPath.last[1];
    if (dr != 0 && dc != 0) {
      // 斜向移动 → 取绝对值较大的方向（优先主导方向）
      if (dr.abs() > dc.abs()) dc = 0; else dr = 0;
      // 修正后的目标格
      final corrected = [_dragPath.last[0] + dr, _dragPath.last[1] + dc];
      if (corrected[0] < 0 || corrected[0] > widget.puzzle.rows || corrected[1] < 0 || corrected[1] > widget.puzzle.cols) return;
      // 检查修正后的格是否已在路径中
      for (int i = 0; i < _dragPath.length; i++) {
        if (_dotsMatch(_dragPath[i], corrected)) {
          if (i == 0 && _dragPath.length >= 3) {
            _loopComplete = true;
            _rebuildPreview(); setState(() {}); return;
          }
          _dragPath.removeRange(i + 1, _dragPath.length);
          _rebuildPreview(); setState(() {}); return;
        }
      }
      // 走自动补全
      for (final d in _fill(_dragPath.last, corrected)) {
        bool skip = false;
        for (int i = 0; i < _dragPath.length - 1; i++) {
          if (_dotsMatch(_dragPath[i], d)) {
            _dragPath.removeRange(i + 1, _dragPath.length);
            _dragPath.add(d);
            skip = true; break;
          }
        }
        if (skip) break;
        if (_dotsMatch(_dragPath.last, d)) continue;
        _dragPath.add(d);
      }
      _rebuildPreview(); setState(() {}); return;
    }

    // 检查回到旧 dot → 截断 or 闭环
    for (int i = 0; i < _dragPath.length - 1; i++) {
      if (_dotsMatch(_dragPath[i], dot)) {
        if (i == 0 && _dragPath.length >= 3) {
          _loopComplete = true;
          _rebuildPreview(); setState(() {}); return;
        }
        _dragPath.removeRange(i + 1, _dragPath.length);
        _rebuildPreview(); setState(() {}); return;
      }
    }

    // 自动补全
    for (final d in _fill(_dragPath.last, dot)) {
      for (int i = 0; i < _dragPath.length - 1; i++) {
        if (_dotsMatch(_dragPath[i], d)) {
          if (i == 0 && _dragPath.length >= 3) {
            _loopComplete = true;
            _rebuildPreview(); setState(() {}); return;
          }
          _dragPath.removeRange(i + 1, _dragPath.length);
          _dragPath.add(d);
          _rebuildPreview(); setState(() {}); return;
        }
      }
      if (_dotsMatch(_dragPath.last, d)) continue;
      _dragPath.add(d);
    }

    // 检测画线/擦线模式
    if (_dragMode == 0 && _dragPath.length >= 2) {
      final e = _edgeBetween(_dragPath[0], _dragPath[1]);
      if (e != null) _dragMode = _isLine(e) ? -1 : 1;
    }

    // 保存当前鼠标位置用于绘制"尾巴"
    if (_dragPath.isNotEmpty) {
      final last = _dragPath.last;
      final bx = pos.dx - _offsetX, by = pos.dy - _offsetY;
      final col = ((bx - _spacing) / _spacing).round();
      final row = ((by - _spacing) / _spacing).round();
      // 只在鼠标与最后dot同行或同列时才画尾巴
      if (row == last[0] || col == last[1]) {
        _dragTail = pos;
      } else {
        _dragTail = null;
      }
    }
    _rebuildPreview(); setState(() {});
  }

  void _onUp(Offset pos) {
    _dragTail = null;
    if (_dragPath.length == 1) {
      _toggleNearestEdge(_dragPath[0]);
    } else if (_dragMode != 0 && _previewEdges.isNotEmpty) {
      for (final e in _previewEdges) _setLine(e, _dragMode == 1);
    }
    _dragPath.clear(); _dragMode = 0; _previewEdges.clear(); _loopComplete = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      _calcLayout(c);
      return Listener(
        onPointerDown: (e) => _onDown(e.localPosition),
        onPointerMove: (e) => _onMove(e.localPosition),
        onPointerUp: (e) => _onUp(e.localPosition),
        onPointerCancel: (_) { _dragPath.clear(); _dragMode = 0; _previewEdges.clear(); setState(() {}); },
        child: CustomPaint(
          size: Size(c.maxWidth, c.maxHeight),
          painter: _MasyuPainter(puzzle: widget.puzzle, spacing: _spacing,
              offsetX: _offsetX, offsetY: _offsetY,
              preview: _previewEdges, drawMode: _dragMode,
              dragTail: _dragTail),
        ),
      );
    });
  }
}

// ============================================================================
//  绘制器 — dot-to-dot 连接，不超出灰色边框
// ============================================================================

class _MasyuPainter extends CustomPainter {
  final MasyuPuzzle puzzle;
  final double spacing, offsetX, offsetY;
  final Set<_EdgeKey> preview;
  final int drawMode;
  final Offset? dragTail; // 鼠标拖拽尾巴位置

  _MasyuPainter({required this.puzzle, required this.spacing,
    required this.offsetX, required this.offsetY,
    required this.preview, required this.drawMode,
    this.dragTail});

  /// dot(c, r) 坐标：c=0..cols, r=0..rows
  Offset _n(int c, int r) => Offset(offsetX + (c + 1) * spacing, offsetY + (r + 1) * spacing);

  int get rows => puzzle.rows;
  int get cols => puzzle.cols;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);
    _border(canvas);
    _dots(canvas);
    _pearls(canvas);
    _lines(canvas);
    _previewLines(canvas);
  }

  void _border(Canvas canvas) {
    final l = offsetX + spacing * 0.5, t = offsetY + spacing * 0.5;
    final r = offsetX + (cols + 1.5) * spacing, b = offsetY + (rows + 1.5) * spacing;
    canvas.drawRect(Rect.fromLTRB(l, t, r, b),
        Paint()..color = const Color(0xFFDDDDDD)..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _dots(Canvas canvas) {
    for (int r = 0; r <= rows; r++)
      for (int c = 0; c <= cols; c++)
        canvas.drawCircle(_n(c, r), 2, Paint()..color = const Color(0xFFBBBBBB));
  }

  /// hEdges[r][c] : dot(c,r) ↔ dot(c+1,r)   r=0..rows, c=0..cols-1
  /// vEdges[r][c] : dot(c,r) ↔ dot(c,r+1)   r=0..rows-1, c=0..cols
  void _lines(Canvas canvas) {
    final p = Paint()..color = const Color(0xFF000000)..strokeWidth = 3..strokeCap = StrokeCap.square;
    for (int r = 0; r <= rows; r++)
      for (int c = 0; c < cols; c++)
        if (puzzle.hEdges[r][c] == EdgeState.line) canvas.drawLine(_n(c, r), _n(c + 1, r), p);
    for (int r = 0; r < rows; r++)
      for (int c = 0; c <= cols; c++)
        if (puzzle.vEdges[r][c] == EdgeState.line) canvas.drawLine(_n(c, r), _n(c, r + 1), p);
  }

  void _previewLines(Canvas canvas) {
    if (preview.isEmpty && dragTail == null) return;
    final p = Paint()..color = const Color(0xFF000000)..strokeWidth = 3..strokeCap = StrokeCap.square;
    for (final e in preview) {
      if (e.isH) {
        if (e.c < 0 || e.c >= cols) continue;
        canvas.drawLine(_n(e.c, e.r), _n(e.c + 1, e.r), p);
      } else {
        if (e.r < 0 || e.r >= rows) continue;
        canvas.drawLine(_n(e.c, e.r), _n(e.c, e.r + 1), p);
      }
    }
    // 拖拽尾巴：从最后一个dot画到鼠标当前位置
    if (dragTail != null && preview.isNotEmpty) {
      // 找最后一个拖拽边的终点
      final lastEdge = preview.last;
      Offset endPt;
      if (lastEdge.isH) {
        endPt = _n(lastEdge.c + 1, lastEdge.r);
      } else {
        endPt = _n(lastEdge.c, lastEdge.r + 1);
      }
      // 限制尾巴方向为水平或垂直
      final dx = (dragTail!.dx - endPt.dx).abs();
      final dy = (dragTail!.dy - endPt.dy).abs();
      Offset tailEnd;
      if (dx > dy) {
        tailEnd = Offset(dragTail!.dx, endPt.dy);
      } else {
        tailEnd = Offset(endPt.dx, dragTail!.dy);
      }
      canvas.drawLine(endPt, tailEnd, p);
    }
  }

  void _pearls(Canvas canvas) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (puzzle.cells[r][c] == CellType.empty) continue;
        final center = _n(c, r);
        final radius = spacing * 0.35;
        if (puzzle.cells[r][c] == CellType.white) {
          canvas.drawCircle(center, radius, Paint()..color = Colors.white);
          canvas.drawCircle(center, radius, Paint()..color = Colors.black87..style = PaintingStyle.stroke..strokeWidth = 2.5);
        } else {
          canvas.drawCircle(center, radius, Paint()..color = Colors.black87);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MasyuPainter old) => true;
}
