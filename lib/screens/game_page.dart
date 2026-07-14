import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sudoku_game.dart';
import '../models/sudoku_generator.dart';
import '../widgets/sudoku_board.dart';

const _blue = Color(0xFF0B4CFF);

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late SudokuPuzzle _puzzle;
  GlobalKey<SudokuBoardState> _boardKey = GlobalKey();
  int _seconds = 0;
  bool _paused = false;
  bool _isSolved = false;
  bool _hasGivenUp = false;
  Timer? _timer;
  int? _selectedNumber;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _newGame() {
    _puzzle = SudokuGenerator().generate(clues: 30);
    _isSolved = false;
    _hasGivenUp = false;
    _selectedNumber = null;
    _boardKey = GlobalKey();
    _startTimer();
    if (mounted) setState(() {});
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = 0;
    _paused = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_paused) setState(() => _seconds++);
    });
  }

  String _formatTime(int s) {
    final h = (s ~/ 3600).toString().padLeft(2, '0');
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }

  void _checkCompletion() {
    if (_puzzle.isComplete() && _puzzle.isCorrect()) {
      _timer?.cancel();
      setState(() => _isSolved = true);
      _showMsg('恭喜你，解答正确！');
    } else {
      _showMsg('还有错误，再检查一下吧');
    }
  }

  void _autoSolve() {
    _timer?.cancel();
    setState(() {
      _hasGivenUp = true;
      for (int r = 0; r < 9; r++)
        for (int c = 0; c < 9; c++)
          _puzzle.cells[r][c] = _puzzle.solution[r][c];
    });
    _showMsg('已显示答案');
  }

  void _restart() {
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++)
        if (!_puzzle.given[r][c]) _puzzle.cells[r][c] = 0;
    _seconds = 0;
    _isSolved = false;
    _hasGivenUp = false;
    _startTimer();
    if (mounted) setState(() {});
  }

  void _erase() {
    final board = _boardKey.currentState;
    if (board != null) { board.eraseCell(); setState(() {}); }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('数独', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(children: [
        Text(_formatTime(_seconds),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w300, color: _blue, letterSpacing: 4)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SudokuBoard(
            key: _boardKey,
            puzzle: _puzzle,
            selectedNumber: _selectedNumber,
          ),
        ),
        const SizedBox(height: 8),
        // 数字按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (int n = 1; n <= 5; n++) _numBtn(n),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (int n = 6; n <= 9; n++) _numBtn(n),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
        // 操作按钮
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _iconBtn(Icons.refresh_rounded, '新游戏', _newGame),
          _iconBtn(Icons.replay_rounded, '重来', _restart),
          _iconBtn(Icons.undo_rounded, '擦除', _erase),
          _iconBtn(Icons.auto_fix_high_rounded, '求解',
              (_isSolved || _hasGivenUp) ? null : _autoSolve),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: 200, height: 40,
          child: ElevatedButton(
            onPressed: (_isSolved || _hasGivenUp) ? null : _checkCompletion,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSolved ? Colors.green : _blue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[400],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(
              _isSolved ? '已完成 ✓' : (_hasGivenUp ? '已放弃' : '完成'),
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _numBtn(int n) {
    final selected = _selectedNumber == n;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          final board = _boardKey.currentState;
          final newSelected = selected ? null : n;
          if (newSelected != null && board != null) {
            board.fillSelectedCell(n);
          }
          setState(() => _selectedNumber = newSelected);
        },
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: selected ? _blue : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? _blue : const Color(0xFFDDDDDD), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text('$n', style: TextStyle(
            fontSize: 18,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : const Color(0xFF455A64),
          )),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, String label, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 68,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDDDDDD)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: onTap == null ? Colors.grey[400] : const Color(0xFF455A64)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 10, color: onTap == null ? Colors.grey[400] : const Color(0xFF455A64))),
            ],
          ),
        ),
      ),
    );
  }
}
