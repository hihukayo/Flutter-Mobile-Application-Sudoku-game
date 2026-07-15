import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/sudoku_game.dart';
import '../models/sudoku_generator.dart';
import '../widgets/sudoku_board.dart';

const _clickChannel = MethodChannel('com.example.puzzle_game/click');
final AudioPlayer _webPlayer = AudioPlayer();
int _lastClickMs = 0; // 全局防抖时间戳

const _blue = Color(0xFF0B4CFF);
const _red = Color(0xFFE53935);

// ---- 难度参数（提示数范围） ----
const _range3x3 = {
  '极简': [17, 22],
  '困难': [23, 28],
  '中等': [29, 32],
  '简单': [33, 36],
};
const _diffs3x3 = ['极简', '困难', '中等', '简单'];
const _weights3x3 = [10, 25, 40, 25]; // 正态分布权重

const _range4x4 = {
  '困难': [70, 80],
  '中等': [92, 105],
  '简单': [110, 130],
};
const _diffs4x4 = ['困难', '中等', '简单'];
const _weights4x4 = [25, 50, 25];

// ---- 难度对应的显示颜色 ----
Color _diffColor(String diff) {
  switch (diff) {
    case '极简': return const Color(0xFFC62828);
    case '困难': return const Color(0xFFE65100);
    case '中等': return const Color(0xFF0B4CFF);
    case '简单': return const Color(0xFF2E7D32);
    default: return const Color(0xFF455A64);
  }
}

Color _diffKiller(String diff) {
  switch (diff) {
    case '入门': return const Color(0xFF2E7D32);
    case '困难': return const Color(0xFFC62828);
    default: return const Color(0xFF0B4CFF); // 中等
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final Random _rng = Random();
  late SudokuPuzzle _puzzle;
  GlobalKey<SudokuBoardState> _boardKey = GlobalKey();
  final GlobalKey _menuIconKey = GlobalKey();
  int _seconds = 0;
  bool _paused = false;
  bool _isSolved = false;
  bool _hasGivenUp = false;
  bool _noteMode = false;
  bool _gameOver = false;
  int _errors = 0;
  int _boardSize = 3;
  int _clueCount = 30;
  String _difficulty = '中等';
  final List<int> _lastClueCounts = <int>[];
  bool _generating = false;
  bool _isKiller = false;
  String _killerDifficulty = '中等';
  int get _maxErrors => _boardSize == 3 ? 3 : 6;
  Timer? _timer;
  Timer? _statusTimer;
  String _statusMsg = '';
  final List<_UndoEntry> _undoStack = [];
  final List<_UndoEntry> _redoStack = [];
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _webPlayer.setVolume(0.8);
    } else {
      _initAudioAssets();
    }
    _newGame();
  }

  /// 把音频文件从 asset 复制到应用私有目录（原生 MediaPlayer 可访问）
  Future<void> _initAudioAssets() async {
    try {
      final files = ['failed.mp3', 'Placement.mp3'];
      for (final name in files) {
        final data = await rootBundle.load('assets/audio/$name');
        await File('${Directory.systemTemp.path}/$name').writeAsBytes(data.buffer.asUint8List());
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statusTimer?.cancel();
    if (kIsWeb) _webPlayer.dispose();
    super.dispose();
  }

  void _tap() => HapticFeedback.lightImpact();

  /// 防抖：300ms 内禁止重复触发
  bool _debounce() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastClickMs < 300) return false;
    _lastClickMs = now;
    return true;
  }

  void _click() {
    if (kIsWeb) {
      _webPlayer.play(AssetSource('audio/click.wav'));
    } else {
      _clickChannel.invokeMethod('vibrate');
      _clickChannel.invokeMethod('tone_click');
    }
  }

  /// 填入/删除格子数字时播放的音效
  void _playPlacement() {
    if (kIsWeb) {
      _webPlayer.play(AssetSource('audio/Placement.mp3'));
    } else {
      _clickChannel.invokeMethod('play_placement', '${Directory.systemTemp.path}/Placement.mp3');
    }
  }

  void _success() {
    _tap();  // 轻触感
    if (kIsWeb) {
      _webPlayer.play(AssetSource('audio/success.wav'));
    } else {
      _clickChannel.invokeMethod('vibrate');
      _clickChannel.invokeMethod('tone_success');
    }
  }

  /// 按正态分布随机选取提示数个数，避免连续重复
  int _pickClueCount() {
    final is3 = _boardSize == 3;
    final diffs = is3 ? _diffs3x3 : _diffs4x4;
    final weights = is3 ? _weights3x3 : _weights4x4;
    final ranges = is3 ? _range3x3 : _range4x4;

    // 权重随机选难度
    final total = weights.fold(0, (a, b) => a + b);
    int roll = _rng.nextInt(total);
    String diff = diffs.first;
    for (int i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) { diff = diffs[i]; break; }
    }

    final range = ranges[diff]!;
    int clues = range[0] + _rng.nextInt(range[1] - range[0] + 1);

    // 避免与最近几局相同
    int tries = 0;
    while (_lastClueCounts.contains(clues) && tries < 30) {
      clues = range[0] + _rng.nextInt(range[1] - range[0] + 1);
      tries++;
    }

    _lastClueCounts.add(clues);
    if (_lastClueCounts.length > 3) _lastClueCounts.removeAt(0);

    _difficulty = diff;
    _clueCount = clues;
    return clues;
  }

  void _newGame({bool silent = false}) {
    if (_generating) return; // 生成中禁止重复点击
    if (silent) {
      _tap();
      _clickChannel.invokeMethod('vibrate');
    } else {
      if (!_debounce()) return;
      _click();
    }
    _generating = true;
    if (_isKiller) {
      // 杀手难度正态分布：入门25%、中等50%、困难25%
      final diffRoll = _rng.nextInt(100);
      _killerDifficulty = diffRoll < 25 ? '入门' : diffRoll < 75 ? '中等' : '困难';
      _puzzle = SudokuGenerator(boardSize: 3).generateKiller(difficulty: _killerDifficulty);
    } else {
      _pickClueCount();
      _puzzle = SudokuGenerator(boardSize: _boardSize).generate(clues: _clueCount);
    }
    _generating = false;
    _isSolved = false;
    _hasGivenUp = false;
    _noteMode = false;
    _gameOver = false;
    _errors = 0;
    _paused = false;
    _undoStack.clear();
    _redoStack.clear();
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
    _click();
    setState(() => _paused = !_paused);
  }

  String _formatTime(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  void _onCellChanged(int r, int c, int oldVal, int newVal, Set<int> oldNotes) {
    if (_paused || _gameOver) return;
    _playPlacement();
    _undoStack.add(_UndoEntry(
      r: r, c: c,
      oldVal: oldVal, oldNotes: Set<int>.from(oldNotes),
      newVal: newVal, newNotes: <int>{},
    ));
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
    // 常规：对照答案判错；杀手：检查冲突（重复/笼子和值超限）
    final bool isError = _isKiller
        ? (newVal != 0 && _puzzle.isConflictAt(r, c, newVal))
        : (newVal != 0 && newVal != _puzzle.solution[r][c]);
    if (isError) {
      _errors++;
      if (_errors >= _maxErrors) {
        _timer?.cancel();
        _textFocus.unfocus();
        if (!kIsWeb) { SystemChannels.textInput.invokeMethod('TextInput.hide'); }
        if (kIsWeb) {
          _webPlayer.play(AssetSource('audio/failed.mp3'));
        } else {
          _clickChannel.invokeMethod('play_failed', '${Directory.systemTemp.path}/failed.mp3');
        }
        setState(() {
          _paused = true;
          _gameOver = true;
        });
        return;
      }
      setState(() {});
    }
    // 填满所有格子时自动收起键盘
    if (newVal != 0 && _puzzle.isComplete()) {
      _textFocus.unfocus();
      if (!kIsWeb) { SystemChannels.textInput.invokeMethod('TextInput.hide'); }
    }
  }

  void _onNoteChanged(int r, int c, Set<int> oldNotes, Set<int> newNotes) {
    if (_paused || _gameOver) return;
    _undoStack.add(_UndoEntry(
      r: r, c: c,
      oldVal: 0, oldNotes: Set<int>.from(oldNotes),
      newVal: 0, newNotes: Set<int>.from(newNotes),
    ));
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    _click();
    if (_undoStack.isEmpty || _paused || _gameOver) return;
    final entry = _undoStack.removeLast();
    final currentVal = _puzzle.cells[entry.r][entry.c];
    final currentNotes = Set<int>.from(_puzzle.notes[entry.r][entry.c]);
    _redoStack.add(_UndoEntry(
      r: entry.r, c: entry.c,
      oldVal: currentVal, oldNotes: currentNotes,
      newVal: entry.oldVal, newNotes: Set<int>.from(entry.oldNotes),
    ));
    setState(() {
      _puzzle.cells[entry.r][entry.c] = entry.oldVal;
      _puzzle.notes[entry.r][entry.c] = Set<int>.from(entry.oldNotes);
    });
    _boardKey.currentState?.syncErrors();
  }

  void _redo() {
    _click();
    if (_redoStack.isEmpty || _paused || _gameOver) return;
    final entry = _redoStack.removeLast();
    final currentVal = _puzzle.cells[entry.r][entry.c];
    final currentNotes = Set<int>.from(_puzzle.notes[entry.r][entry.c]);
    _undoStack.add(_UndoEntry(
      r: entry.r, c: entry.c,
      oldVal: currentVal, oldNotes: currentNotes,
      newVal: entry.oldVal, newNotes: Set<int>.from(entry.oldNotes),
    ));
    setState(() {
      _puzzle.cells[entry.r][entry.c] = entry.oldVal;
      _puzzle.notes[entry.r][entry.c] = Set<int>.from(entry.oldNotes);
    });
    _boardKey.currentState?.syncErrors();
  }

  void _syncErrorState() {
    if (_isKiller) {
      int count = 0;
      for (int r = 0; r < _puzzle.gridSize; r++) {
        for (int c = 0; c < _puzzle.gridSize; c++) {
          final v = _puzzle.cells[r][c];
          if (v != 0 && _puzzle.isConflictAt(r, c, v)) count++;
        }
      }
      setState(() => _errors = count);
      _boardKey.currentState?.syncErrors();
      return;
    }
    int count = 0;
    for (int r = 0; r < _puzzle.gridSize; r++) {
      for (int c = 0; c < _puzzle.gridSize; c++) {
        final v = _puzzle.cells[r][c];
        if (v != 0 && v != _puzzle.solution[r][c]) count++;
      }
    }
    setState(() => _errors = count);
    _boardKey.currentState?.syncErrors();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (_paused || _gameOver) return KeyEventResult.ignored;

    // 数字键 1-9（主键盘和小键盘）
    int? n;
    if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) n = 1;
    else if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) n = 2;
    else if (event.logicalKey == LogicalKeyboardKey.digit3 || event.logicalKey == LogicalKeyboardKey.numpad3) n = 3;
    else if (event.logicalKey == LogicalKeyboardKey.digit4 || event.logicalKey == LogicalKeyboardKey.numpad4) n = 4;
    else if (event.logicalKey == LogicalKeyboardKey.digit5 || event.logicalKey == LogicalKeyboardKey.numpad5) n = 5;
    else if (event.logicalKey == LogicalKeyboardKey.digit6 || event.logicalKey == LogicalKeyboardKey.numpad6) n = 6;
    else if (event.logicalKey == LogicalKeyboardKey.digit7 || event.logicalKey == LogicalKeyboardKey.numpad7) n = 7;
    else if (event.logicalKey == LogicalKeyboardKey.digit8 || event.logicalKey == LogicalKeyboardKey.numpad8) n = 8;
    else if (event.logicalKey == LogicalKeyboardKey.digit9 || event.logicalKey == LogicalKeyboardKey.numpad9) n = 9;

    // 4×4 模式字母键 A-G（对应 10-16）
    if (n == null && _boardSize == 4) {
      if (event.logicalKey == LogicalKeyboardKey.keyA) n = 10;
      else if (event.logicalKey == LogicalKeyboardKey.keyB) n = 11;
      else if (event.logicalKey == LogicalKeyboardKey.keyC) n = 12;
      else if (event.logicalKey == LogicalKeyboardKey.keyD) n = 13;
      else if (event.logicalKey == LogicalKeyboardKey.keyE) n = 14;
      else if (event.logicalKey == LogicalKeyboardKey.keyF) n = 15;
      else if (event.logicalKey == LogicalKeyboardKey.keyG) n = 16;
    }

    if (n != null) {
      _tap();
      _boardKey.currentState?.fillNumber(n);
      setState(() {});
      return KeyEventResult.handled;
    }

    // 退格 / Delete 清除当前格
    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      _tap();
      _boardKey.currentState?.clearSelected();
      setState(() {});
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _checkCompletion() {
    _click();
    if (_paused || _gameOver) return;
    if (_puzzle.isComplete() && _puzzle.isCorrect()) {
      _timer?.cancel();
      _success();
      setState(() {
        _paused = true;
        _isSolved = true;
      });
    } else {
      setState(() => _statusMsg = '还有空格未填，请再检查一下吧');
      _statusTimer?.cancel();
      _statusTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _statusMsg = '');
      });
    }
  }

  void _autoSolve() {
    _click();
    _timer?.cancel();
    _boardKey = GlobalKey();
    final gs = _puzzle.gridSize;
    setState(() {
      _paused = true;
      _hasGivenUp = true;
      for (int r = 0; r < gs; r++)
        for (int c = 0; c < gs; c++)
          _puzzle.cells[r][c] = _puzzle.solution[r][c];
    });
    _syncErrorState();
  }

  void _restart() {
    _click();
    _undoStack.clear();
    _redoStack.clear();
    final gs = _puzzle.gridSize;
    for (int r = 0; r < gs; r++)
      for (int c = 0; c < gs; c++) {
        if (!_puzzle.given[r][c]) _puzzle.cells[r][c] = 0;
        _puzzle.notes[r][c].clear();
      }
    _errors = 0;
    _gameOver = false;
    _isSolved = false;
    _hasGivenUp = false;
    _seconds = 0;
    _startTimer();
    _boardKey.currentState?.syncErrors();
    if (mounted) setState(() {});
  }

  void _showModeMenu() {
    if (!_debounce()) return;
    _clickChannel.invokeMethod('vibrate');
    // 收起手机键盘，防止菜单关闭后键盘弹出
    _textFocus.unfocus();
    try { SystemChannels.textInput.invokeMethod('TextInput.hide'); } catch (_) {}

    final RenderBox? box = _menuIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;

    final bool is3Selected = !_isKiller && _boardSize == 3;
    final bool isKillerSelected = _isKiller;
    final bool is4Selected = _boardSize == 4;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        pos.dx,
        pos.dy + size.height,
        pos.dx + 140,
        pos.dy + size.height + 120,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem(
          value: '3×3-killer',
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('3×3 杀手', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 18),
              if (isKillerSelected) const Icon(Icons.check, size: 14, color: _blue),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: '3×3',
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('3×3 常规', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 18),
              if (is3Selected) const Icon(Icons.check, size: 14, color: _blue),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: '4×4',
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('4×4 常规', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 18),
              if (is4Selected) const Icon(Icons.check, size: 14, color: _blue),
            ],
          ),
        ),
      ],
    ).then((mode) {
      if (mode == null) return;
      final isKiller = mode == '3×3-killer';
      final newSize = mode == '4×4' ? 4 : 3;
      if (newSize != _boardSize || isKiller != _isKiller) {
        setState(() {
          _boardSize = newSize;
          _isKiller = isKiller;
        });
        _newGame(silent: true);
      }
    });
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle()),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  int _cluesRemaining() {
    final gs = _puzzle.gridSize;
    int n = 0;
    for (int r = 0; r < gs; r++)
      for (int c = 0; c < gs; c++)
        if (_puzzle.cells[r][c] == 0) n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final infoStyle = TextStyle(
      fontSize: 13, fontWeight: FontWeight.w500,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GestureDetector(
            key: _menuIconKey,
            onTap: () => _showModeMenu(),
            child: const Icon(Icons.more_horiz, color: Color(0xFF78909C), size: 24),
          ),
        ),
        leadingWidth: 40,
        title: Text('数独', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _paused || _gameOver ? null : () { _click(); setState(() => _noteMode = !_noteMode); },
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
      body: Focus(
        onKeyEvent: _onKeyEvent,
        child: Stack(
        children: [
          // 隐藏输入框放在最上层（确保可聚焦）
          Positioned(
            top: 0, left: 0, right: 0,
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: _textController,
                focusNode: _textFocus,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                showCursor: false,
                enableInteractiveSelection: false,
                style: const TextStyle(fontSize: 16, color: Colors.transparent),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) {
                  final clean = _boardSize == 3
                      ? v.replaceAll(RegExp(r'[^1-9]'), '')
                      : v.toUpperCase().replaceAll(RegExp(r'[^1-9A-G]'), '');
                  if (clean.isNotEmpty) {
                    final ch = clean.substring(clean.length - 1);
                    final n = ch.codeUnitAt(0);
                    final val = n >= 65 ? n - 65 + 10 : int.parse(ch);
                    _boardKey.currentState?.fillNumber(val);
                  }
                  _textController.clear();
                },
              ),
            ),
          ),
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
                  Text('$_errors/$_maxErrors', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: _errors >= _maxErrors ? _red : const Color(0xFF455A64),
                  )),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: (_gameOver || _hasGivenUp) ? null : _togglePause,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _paused ? Icons.play_arrow : Icons.pause,
                          size: 14,
                          color: (_gameOver || _hasGivenUp) ? Colors.grey[350]! : _blue,
                        ),
                        const SizedBox(width: 3),
                        Text(_formatTime(_seconds), style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500,
                          color: (_gameOver || _hasGivenUp) ? Colors.grey[350]! : const Color(0xFF455A64),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Text(_isKiller ? _killerDifficulty : '$_difficulty', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: _isKiller ? _diffKiller(_killerDifficulty) : _diffColor(_difficulty),
                  )),
                  const SizedBox(width: 4),
                  Text('${_cluesRemaining()}空', style: TextStyle(
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
                              onNoteChanged: _onNoteChanged,
                              onRefresh: () => setState(() {}),
                              onRequestInput: () {
                                _textFocus.requestFocus();
                                if (!kIsWeb) {
                                  SystemChannels.textInput.invokeMethod('TextInput.show');
                                }
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
        ],
      ),
      ),
    );
  }

  Widget _buildStatus() {
    final style = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
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
                  _iconTextBtn(Icons.redo, '重做', disabled ? null : (_redoStack.isEmpty ? null : _redo), s),
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
  final int r, c;
  final int oldVal;
  final Set<int> oldNotes;
  final int newVal;
  final Set<int> newNotes;

  _UndoEntry({
    required this.r,
    required this.c,
    required this.oldVal,
    required this.oldNotes,
    required this.newVal,
    required this.newNotes,
  });
}
