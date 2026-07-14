import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sudoku_game.dart';
import '../models/sudoku_generator.dart';
import '../widgets/sudoku_board.dart';

const _blue = Color(0xFF0B4CFF);
const _red = Color(0xFFE53935);
const _maxErrors = 3;

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
  bool _noteMode = false;
  bool _gameOver = false;
  int _errors = 0;
  Timer? _timer;
  Timer? _statusTimer;
  String _statusMsg = '';
  final List<_UndoEntry> _undoStack = [];
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  void _tap() => HapticFeedback.lightImpact();

  void _newGame() {
    _tap();
    _puzzle = SudokuGenerator().generate(clues: 30);
    _isSolved = false;
    _hasGivenUp = false;
    _noteMode = false;
    _gameOver = false;
    _errors = 0;
    _paused = false;
    _undoStack.clear();
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

  void _togglePause() {
    _tap();
    setState(() => _paused = !_paused);
  }

  String _formatTime(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  void _onCellChanged(int r, int c, int oldVal, int newVal) {
    if (_paused || _gameOver) return;
    _undoStack.add(_UndoEntry(r, c, oldVal));
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    if (newVal != _puzzle.solution[r][c]) {
      _errors++;
      if (_errors >= _maxErrors) {
        _timer?.cancel();
        setState(() => _gameOver = true);
        return;
      }
      setState(() {});
    }
  }

  void _undo() {
    _tap();
    if (_undoStack.isEmpty || _paused || _gameOver) return;
    final entry = _undoStack.removeLast();
    setState(() => _puzzle.cells[entry.r][entry.c] = entry.oldVal);
  }

  void _checkCompletion() {
    _tap();
    if (_paused || _gameOver) return;
    if (_puzzle.isComplete() && _puzzle.isCorrect()) {
      _timer?.cancel();
      setState(() => _isSolved = true);
    } else {
      setState(() => _statusMsg = '还有错误，再检查一下吧');
      _statusTimer?.cancel();
      _statusTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _statusMsg = '');
      });
    }
  }

  void _autoSolve() {
    _tap();
    _timer?.cancel();
    _boardKey = GlobalKey();
    setState(() {
      _hasGivenUp = true;
      for (int r = 0; r < 9; r++)
        for (int c = 0; c < 9; c++)
          _puzzle.cells[r][c] = _puzzle.solution[r][c];
    });
  }

  void _restart() {
    _tap();
    _undoStack.clear();
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) {
        if (!_puzzle.given[r][c]) _puzzle.cells[r][c] = 0;
        _puzzle.notes[r][c].clear();
      }
    _errors = 0;
    _gameOver = false;
    _isSolved = false;
    _hasGivenUp = false;
    _seconds = 0;
    _startTimer();
    if (mounted) setState(() {});
  }

  void _erase() {
    _tap();
    if (_paused || _gameOver) return;
    _boardKey.currentState?.eraseSelected();
    setState(() {});
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.montserrat()),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  int _cluesRemaining() {
    int n = 0;
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++)
        if (_puzzle.cells[r][c] == 0) n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final infoStyle = GoogleFonts.montserrat(
      fontSize: 13, fontWeight: FontWeight.w500,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Icon(Icons.more_horiz, color: const Color(0xFF78909C), size: 24),
        ),
        leadingWidth: 40,
        title: Text('数独', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _paused || _gameOver ? null : () => setState(() => _noteMode = !_noteMode),
              child: Icon(
                _noteMode ? Icons.edit_note : Icons.edit_note_outlined,
                color: _noteMode ? _blue : const Color(0xFF78909C),
                size: 24,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(infoStyle),
      body: Stack(
        children: [
          Column(
          children: [
            const Divider(height: 1, thickness: 0.5),
            // 计数栏（大标题正下方）
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 14,
                      color: _errors >= _maxErrors ? _red : const Color(0xFF78909C)),
                  const SizedBox(width: 4),
                  Text('$_errors/$_maxErrors', style: GoogleFonts.montserrat(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: _errors >= _maxErrors ? _red : const Color(0xFF455A64),
                  )),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: _gameOver ? null : _togglePause,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _paused ? Icons.play_arrow : Icons.pause,
                          size: 14,
                          color: _gameOver ? Colors.grey[350]! : _blue,
                        ),
                        const SizedBox(width: 3),
                        Text(_formatTime(_seconds), style: GoogleFonts.montserrat(
                          fontSize: 12, fontWeight: FontWeight.w500,
                          color: _gameOver ? Colors.grey[350]! : const Color(0xFF455A64),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Text('${_cluesRemaining()} 空', style: GoogleFonts.montserrat(
                    fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF455A64),
                  )),
                ],
              ),
            ),

            // 棋盘（固定正方形，可滚动防溢出）
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    final size = constraints.maxWidth;
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: size,
                            height: size,
                            child: SudokuBoard(
                              key: _boardKey,
                              puzzle: _puzzle,
                              noteMode: _noteMode,
                              readOnly: _paused || _gameOver,
                              onCellChanged: _onCellChanged,
                              onRefresh: () => setState(() {}),
                              onRequestInput: () {
                                _textFocus.requestFocus();
                                SystemChannels.textInput.invokeMethod('TextInput.show');
                              },
                            ),
                          ),
                          Container(
                            height: 28,
                            alignment: Alignment.center,
                            child: _buildStatus(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
          // 隐藏输入框
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SizedBox(
              height: 0.1,
              child: TextField(
                controller: _textController,
                focusNode: _textFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                showCursor: false,
                enableInteractiveSelection: false,
                style: const TextStyle(fontSize: 0.1, color: Colors.transparent),
                decoration: const InputDecoration(border: InputBorder.none),
                onChanged: (v) {
                  final digits = v.replaceAll(RegExp(r'[^1-9]'), '');
                  if (digits.isNotEmpty) {
                    final n = int.parse(digits.substring(digits.length - 1));
                    _boardKey.currentState?.fillNumber(n);
                  }
                  _textController.clear();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatus() {
    final style = GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500);
    if (_gameOver) {
      return Text('错误 $_errors 次，游戏结束，用时 ${_formatTime(_seconds)}', style: style.copyWith(color: _red));
    }
    if (_isSolved) {
      return Text('解答正确！用时 ${_formatTime(_seconds)}', style: style.copyWith(color: Colors.green));
    }
    if (_hasGivenUp) {
      return Text('已查看答案', style: style.copyWith(color: Colors.orange));
    }
    if (_paused) {
      return Text('已暂停', style: style.copyWith(color: const Color(0xFF455A64)));
    }
    if (_statusMsg.isNotEmpty) {
      return Text(_statusMsg, style: style.copyWith(color: const Color(0xFF455A64)));
    }
    return const SizedBox.shrink();
  }

  Widget _buildBottomBar(TextStyle s) {
    final disabled = _paused || _gameOver;
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _textBtn('新局', _newGame, s),
                  _textBtn('完成', (disabled || _isSolved || _hasGivenUp) ? null : _checkCompletion, s, fill: true),
                  _textBtn('求解', (disabled || _isSolved || _hasGivenUp) ? null : _autoSolve, s),
                ]),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _iconTextBtn(Icons.undo, '撤销', disabled ? null : (_undoStack.isEmpty ? null : _undo), s),
                  _iconTextBtn(Icons.replay, '重置', _restart, s),
                  _iconTextBtn(Icons.backspace, '擦除', disabled ? null : _erase, s),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _textBtn(String label, VoidCallback? onTap, TextStyle s, {bool fill = false}) {
    final isDisabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 88, height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDisabled ? Colors.grey[100]! : fill ? _blue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, style: s.copyWith(
            fontSize: 15,
            fontWeight: fill ? FontWeight.w600 : FontWeight.w500,
            color: isDisabled ? Colors.grey[350]! : fill ? Colors.white : const Color(0xFF455A64),
          )),
        ),
      ),
    );
  }

  Widget _iconTextBtn(IconData icon, String label, VoidCallback? onTap, TextStyle s) {
    final isDisabled = onTap == null;
    final color = isDisabled ? Colors.grey[350]! : const Color(0xFF455A64);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 88, height: 44,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 4),
              Text(label, style: s.copyWith(fontSize: 13, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UndoEntry {
  final int r, c, oldVal;
  _UndoEntry(this.r, this.c, this.oldVal);
}
