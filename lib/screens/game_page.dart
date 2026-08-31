import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/sudoku_game.dart';
import '../models/sudoku_generator.dart';
import '../widgets/sudoku_board.dart';
import '../services/api_service.dart';
import '../services/local_save_store.dart';
import '../services/app_theme.dart';
import '../services/window_util.dart';

const _clickChannel = MethodChannel('com.example.puzzle_game/click');
final AudioPlayer _webPlayer = AudioPlayer();
int _lastClickMs = 0; // 全局防抖时间戳

const _red = Color(0xFFE53935);

// ---- 难度参数（提示数范围） ----
const _diffs3x3 = ['极简', '困难', '中等', '简单'];
const _weights3x3 = [10, 25, 40, 25]; // 正态分布权重

const _diffs4x4 = ['困难', '中等', '简单'];
const _weights4x4 = [25, 50, 25];

// ---- 难度对应的显示颜色 ----
Color _diffColor(String diff) {
  switch (diff) {
    case '极简':
      return const Color(0xFFC62828);
    case '困难':
      return const Color(0xFFE65100);
    case '中等':
      return const Color(0xFF0B4CFF);
    case '简单':
      return const Color(0xFF2E7D32);
    default:
      return const Color(0xFF455A64);
  }
}

Color _diffKiller(String diff) {
  switch (diff) {
    case '入门':
      return const Color(0xFF2E7D32);
    case '困难':
      return const Color(0xFFC62828);
    default:
      return const Color(0xFF0B4CFF); // 中等
  }
}

class GamePage extends StatefulWidget {
  final String username;

  /// 会话级标记：续玩提示只在每次登录会话的首次进入时弹出一次，
  /// 切换界面（页面保活/重建）不再重复弹出；登录成功时由 HomePage 重置。
  static bool resumePromptShown = false;

  const GamePage({super.key, required this.username});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  final Random _rng = Random();
  SudokuPuzzle _puzzle = SudokuPuzzle(boardSize: 3); // 默认空盘，避免异步生成完成前首帧未初始化红屏
  GlobalKey<SudokuBoardState> _boardKey = GlobalKey();
  final GlobalKey _menuIconKey = GlobalKey();
  int _seconds = 0;
  bool _paused = false;
  bool _isSolved = false;
  bool _hasGivenUp = false;
  bool _noteMode = false;
  // 是否动过棋盘，防止未游玩的新盘覆盖旧存档
  bool _dirty = false;
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
  bool _loadingSave = false;
  bool _bgAutoSaved = false; // 后台自动保存成功后回到前台提示一次
  int _lastScore = 0;
  int _currentSeed = 0; // 当前局的种子：复制/输入可复现同一谜题
  String get _seedLabel => _currentSeed.toRadixString(36).toUpperCase();
  final List<_UndoEntry> _undoStack = [];
  final List<_UndoEntry> _redoStack = [];
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    setSoftInputMode('nothing');
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      _webPlayer.setVolume(0.8);
    } else {
      _initAudioAssets();
    }
    _newGame(silent: true, feedback: false); // 初次进入静音开新局
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkResume());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      // 被打断（通知栏/来电等）立即静默存档，中断式响应
      if (!_gameOver && !_isSolved && !_hasGivenUp && _dirty) _autoSave();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // 进入后台：先静默存档，再暂停计时；回到前台保持暂停，由用户手动继续
      if (!_gameOver && !_isSolved && !_hasGivenUp && _dirty) {
        _autoSave().then((ok) {
          if (ok && mounted) _bgAutoSaved = true;
        });
      }
      _hideKeyboard();
      if (mounted && !_paused) {
        setState(() => _paused = true);
      }
    } else if (state == AppLifecycleState.resumed) {
      // 回到前台：后台自动保存成功则提示一次
      if (_bgAutoSaved) {
        _bgAutoSaved = false;
        if (mounted && !_gameOver) _showStatus('已自动保存');
      }
    }
  }

  /// 进入游戏时检查是否有存档，提示续玩（每次登录会话仅首次进入时触发）
  Future<void> _checkResume() async {
    if (GamePage.resumePromptShown) return;
    GamePage.resumePromptShown = true;
    try {
      final res = await _fetchSave();
      if (!mounted || res == null || res['success'] != true) return;
      final savedAt = res['savedAt'] ?? '';

      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 300,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_download_rounded,
                    size: 44,
                    color: context.colors.primary,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '发现存档',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '您有一个存档\n($savedAt)\n是否继续上次的游戏？',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.textFaint,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: BorderSide(color: context.colors.divider),
                          ),
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            '新游戏',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: context.colors.primary,
                            foregroundColor: context.colors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('继续'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (go == true && mounted) {
        _restoreFromData(res);
      }
    } catch (e) {
      debugPrint('检查存档失败：$e');
    }
  }

  /// 把音频文件从 asset 复制到应用私有目录（原生 MediaPlayer 可访问）
  Future<void> _initAudioAssets() async {
    try {
      final files = [
        'failed.mp3',
        'Placement.mp3',
        'error.mp3',
        'gamewin.mp3',
        'gameover.mp3',
      ];
      for (final name in files) {
        final data = await rootBundle.load('assets/audio/$name');
        await File(
          '${Directory.systemTemp.path}/$name',
        ).writeAsBytes(data.buffer.asUint8List());
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    setSoftInputMode('resize');
    _timer?.cancel();
    _statusTimer?.cancel();
    if (kIsWeb) _webPlayer.dispose();
    if (!_gameOver && !_isSolved && !_hasGivenUp && _seconds > 3) _autoSave();
    super.dispose();
  }

  /// 退出时自动保存（静默，不阻塞退出）
  Future<bool> _autoSave() async {
    if (!_dirty) return false;
    try {
      final cagesJson = _puzzle.cages
          ?.map((c) => {'cellIndices': c.cellIndices, 'sum': c.sum, 'op': c.op})
          .toList();
      await ApiService.saveGame(
        username: widget.username,
        boardSize: _boardSize,
        cells: _puzzle.cells,
        notes: _puzzle.notes,
        solution: _puzzle.solution,
        given: _puzzle.given,
        seconds: _seconds,
        errors: _errors,
        isKiller: _isKiller,
        killerDifficulty: _killerDifficulty,
        cages: cagesJson,
        seed: _currentSeed,
      );
      return true;
    } catch (_) {
      return false;
    }
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
      _clickChannel.invokeMethod(
        'play_placement',
        '${Directory.systemTemp.path}/Placement.mp3',
      );
    }
  }

  /// 播放应用私有目录下的 mp3（原生 MediaPlayer）
  void _playMp3(String name) {
    if (kIsWeb) return;
    _clickChannel.invokeMethod('play_mp3', '${Directory.systemTemp.path}/$name');
  }

  /// 填入错误数字
  void _playError() {
    if (kIsWeb) {
      _webPlayer.play(AssetSource('audio/error.mp3'));
    } else {
      _playMp3('error.mp3');
    }
  }

  /// 完成胜利
  void _playWin() {
    if (kIsWeb) {
      _webPlayer.play(AssetSource('audio/gamewin.mp3'));
    } else {
      _playMp3('gamewin.mp3');
    }
  }

  /// 错误次数达上限（游戏结束）
  void _playGameOver() {
    if (kIsWeb) {
      _webPlayer.play(AssetSource('audio/gameover.mp3'));
    } else {
      _playMp3('gameover.mp3');
    }
  }

  /// 当前模式编号：0=3×3 经典，1=算数数独，2=4×4
  int _modeCode() {
    if (_isKiller) return 1;
    if (_boardSize == 4) return 2;
    return 0;
  }

  int _difficultyCode(String label) {
    switch (label) {
      case '入门':
        return 0;
      case '极简':
        return 1;
      case '简单':
        return 2;
      case '中等':
        return 3;
      default:
        return 4;
    }
  }

  String _difficultyLabel(int code) {
    switch (code) {
      case 0:
        return '入门';
      case 1:
        return '极简';
      case 2:
        return '简单';
      case 3:
        return '中等';
      default:
        return '困难';
    }
  }

  /// 各难度对应的提示数范围
  List<int> _clueRange(String diff) {
    switch (diff) {
      case '极简':
        return const [17, 22];
      case '简单':
        return _boardSize == 4 ? const [110, 130] : const [33, 36];
      case '困难':
        return _boardSize == 4 ? const [70, 80] : const [23, 28];
      default:
        return _boardSize == 4 ? const [92, 105] : const [29, 32];
    }
  }

  /// 随机挑选难度（经典模式），只决定难度标签，挖空数由种子推导
  String _pickDifficulty() {
    final is3 = _boardSize == 3;
    final diffs = is3 ? _diffs3x3 : _diffs4x4;
    final weights = is3 ? _weights3x3 : _weights4x4;
    final total = weights.fold(0, (a, b) => a + b);
    int roll = _rng.nextInt(total);
    String diff = diffs.first;
    for (int i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) {
        diff = diffs[i];
        break;
      }
    }
    _difficulty = diff;
    return diff;
  }

  /// 杀手难度随机：入门25%、中等50%、困难25%
  int _rollKillerDifficulty() {
    final diffRoll = _rng.nextInt(100);
    final d = diffRoll < 25
        ? '入门'
        : diffRoll < 75
        ? '中等'
        : '困难';
    _killerDifficulty = d;
    return _difficultyCode(d);
  }

  int _genSeq = 0;

  /// 隐藏游戏页软键盘（操作按键/暂停时收起，避免挡住操作区）
  void _hideKeyboard() {
    _textFocus.unfocus();
    if (!kIsWeb) {
      try {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      } catch (_) {}
    }
  }

  Future<void> _newGame({bool silent = false, bool feedback = true, int? seed}) async {
    if (_generating && !silent) return; // 生成中禁止重复点击；切模式可打断重来
    if (feedback) {
      if (silent) {
        _tap();
        _clickChannel.invokeMethod('vibrate');
      } else {
        if (!_debounce()) return;
        _click();
      }
    }
    _hideKeyboard();
    final mySeq = ++_genSeq;
    _generating = true;
    if (mounted) setState(() {});
    // 主线程先决定模式/难度，再切后台生成谜题，避免卡 UI 与连点堆积
    try {
      final int diffCode;
      if (seed != null) {
        // 种子内携带模式与难度：无论当前处于哪种模式，输入相同种子都能还原同一局
        diffCode = seed & 7;
        final mode = (seed >> 3) & 3;
        if (mode != _modeCode()) {
          _isKiller = mode == 1;
          _boardSize = mode == 2 ? 4 : 3;
        }
        final label = _difficultyLabel(diffCode);
        _difficulty = label;
        _killerDifficulty = label;
      } else {
        diffCode = _isKiller
            ? _rollKillerDifficulty()
            : _difficultyCode(_pickDifficulty());
      }
      final String newDiff = _isKiller ? _killerDifficulty : _difficulty;
      final int genBoardSize = _isKiller ? 3 : _boardSize;
      int puzzleSeed = seed != null ? seed >> 5 : _rng.nextInt(1 << 26);
      int clues = _clueCount;
      if (!_isKiller) {
        final range = _clueRange(newDiff);
        clues = range[0] + puzzleSeed % (range[1] - range[0] + 1);
        if (seed == null) {
          // 避免与最近几局相同
          int tries = 0;
          while (_lastClueCounts.contains(clues) && tries < 30) {
            puzzleSeed = _rng.nextInt(1 << 26);
            clues = range[0] + puzzleSeed % (range[1] - range[0] + 1);
            tries++;
          }
          _lastClueCounts.add(clues);
          if (_lastClueCounts.length > 3) _lastClueCounts.removeAt(0);
        }
        _clueCount = clues;
      }
      _currentSeed = (puzzleSeed << 5) | (_modeCode() << 3) | diffCode;

      // 后台 isolate 生成，避免卡 UI；期间“新局”按钮禁用，连点直接忽略
      SudokuPuzzle next;
      if (_isKiller) {
        next = await compute(generatePuzzleInIsolate, <String, Object>{
          'boardSize': 3,
          'killer': true,
          'difficulty': newDiff,
          'seed': puzzleSeed,
        });
      } else {
        next = await compute(generatePuzzleInIsolate, <String, Object>{
          'boardSize': genBoardSize,
          'killer': false,
          'clues': clues,
          'seed': puzzleSeed,
        });
      }
      if (!mounted || mySeq != _genSeq) return; // 已被更新的新局请求取代，丢弃旧结果
      _puzzle = next;
    } catch (e) {
      debugPrint('新局生成失败，使用保底谜题：$e');
      final gen = SudokuGenerator(boardSize: _isKiller ? 3 : _boardSize);
      final next = _isKiller
          ? gen.generateKiller(difficulty: '入门')
          : gen.generate(clues: 36);
      if (!mounted || mySeq != _genSeq) return;
      _puzzle = next;
    }
    _generating = false;
    if (!mounted) return;
    _isSolved = false;
    _hasGivenUp = false;
    _noteMode = false;
    _gameOver = false;
    _errors = 0;
    _dirty = false;
    _paused = false;
    _statusMsg = '';
    _lastScore = 0;
    _seconds = 0;
    _undoStack.clear();
    _redoStack.clear();
    _boardKey = GlobalKey();
    _startTimer();
    if (mounted) setState(() {});
  }

  void _startTimer() {
    _timer?.cancel();
    _paused = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_paused) setState(() => _seconds++);
    });
  }

  void _togglePause() {
    _click();
    _hideKeyboard();
    final becomingPaused = !_paused;
    setState(() => _paused = becomingPaused);
    if (becomingPaused && !_gameOver && !_isSolved && !_hasGivenUp && _dirty) {
      _saveGame(silent: true); // 暂停时玩过（动过棋盘）才静默自动存档，内容与手动存档一致（含计时）
    }
  }

  String _formatTime(int s) {
    final h = (s ~/ 3600).toString().padLeft(2, '0');
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }

  void _onCellChanged(int r, int c, int oldVal, int newVal, Set<int> oldNotes) {
    if (_paused || _gameOver) return;
    _dirty = true;
    _undoStack.add(
      _UndoEntry(
        r: r,
        c: c,
        oldVal: oldVal,
        oldNotes: Set<int>.from(oldNotes),
        newVal: newVal,
        newNotes: <int>{},
      ),
    );
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
        if (!kIsWeb) {
          SystemChannels.textInput.invokeMethod('TextInput.hide');
        }
        _playGameOver(); // 达上限只播失败音，不再叠加错误音
        _submitScore(won: false); // 提交失败记录
        _lastScore = _calculateScore();
        setState(() {
          _paused = true;
          _gameOver = true;
        });
        return;
      }
      _playError(); // 填错播错误音
      setState(() {});
    } else {
      _playPlacement(); // 填对/清除播落子音
    }
    // 填满所有格子时自动收起键盘
    if (newVal != 0 && _puzzle.isComplete()) {
      _textFocus.unfocus();
      if (!kIsWeb) {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      }
    }
  }

  void _onNoteChanged(int r, int c, Set<int> oldNotes, Set<int> newNotes) {
    if (_paused || _gameOver) return;
    _dirty = true;
    _undoStack.add(
      _UndoEntry(
        r: r,
        c: c,
        oldVal: 0,
        oldNotes: Set<int>.from(oldNotes),
        newVal: 0,
        newNotes: Set<int>.from(newNotes),
      ),
    );
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    _click();
    if (_undoStack.isEmpty || _paused || _gameOver) return;
    _dirty = true;
    final entry = _undoStack.removeLast();
    final currentVal = _puzzle.cells[entry.r][entry.c];
    final currentNotes = Set<int>.from(_puzzle.notes[entry.r][entry.c]);
    _redoStack.add(
      _UndoEntry(
        r: entry.r,
        c: entry.c,
        oldVal: currentVal,
        oldNotes: currentNotes,
        newVal: entry.oldVal,
        newNotes: Set<int>.from(entry.oldNotes),
      ),
    );
    setState(() {
      _puzzle.cells[entry.r][entry.c] = entry.oldVal;
      _puzzle.notes[entry.r][entry.c] = Set<int>.from(entry.oldNotes);
    });
    _boardKey.currentState?.syncErrors();
  }

  void _redo() {
    _click();
    if (_redoStack.isEmpty || _paused || _gameOver) return;
    _dirty = true;
    final entry = _redoStack.removeLast();
    final currentVal = _puzzle.cells[entry.r][entry.c];
    final currentNotes = Set<int>.from(_puzzle.notes[entry.r][entry.c]);
    _undoStack.add(
      _UndoEntry(
        r: entry.r,
        c: entry.c,
        oldVal: currentVal,
        oldNotes: currentNotes,
        newVal: entry.oldVal,
        newNotes: Set<int>.from(entry.oldNotes),
      ),
    );
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
    if (event is! KeyDownEvent && event is! KeyRepeatEvent)
      return KeyEventResult.ignored;
    if (_paused || _gameOver) return KeyEventResult.ignored;

    // 数字键 1-9（主键盘和小键盘）
    int? n;
    if (event.logicalKey == LogicalKeyboardKey.digit1 ||
        event.logicalKey == LogicalKeyboardKey.numpad1) {
      n = 1;
    } else if (event.logicalKey == LogicalKeyboardKey.digit2 ||
        event.logicalKey == LogicalKeyboardKey.numpad2) {
      n = 2;
    }
    // ignore: curly_braces_in_flow_control_structures
    else if (event.logicalKey == LogicalKeyboardKey.digit3 ||
        event.logicalKey == LogicalKeyboardKey.numpad3) {
      n = 3;
    } else if (event.logicalKey == LogicalKeyboardKey.digit4 ||
        event.logicalKey == LogicalKeyboardKey.numpad4) {
      n = 4;
    } else if (event.logicalKey == LogicalKeyboardKey.digit5 ||
        event.logicalKey == LogicalKeyboardKey.numpad5) {
      n = 5;
    } else if (event.logicalKey == LogicalKeyboardKey.digit6 ||
        event.logicalKey == LogicalKeyboardKey.numpad6) {
      n = 6;
    } else if (event.logicalKey == LogicalKeyboardKey.digit7 ||
        event.logicalKey == LogicalKeyboardKey.numpad7) {
      n = 7;
    } else if (event.logicalKey == LogicalKeyboardKey.digit8 ||
        event.logicalKey == LogicalKeyboardKey.numpad8) {
      n = 8;
    } else if (event.logicalKey == LogicalKeyboardKey.digit9 ||
        event.logicalKey == LogicalKeyboardKey.numpad9) {
      n = 9;
    }

    // 4×4 模式字母键 A-G（对应 10-16）
    if (n == null && _boardSize == 4) {
      if (event.logicalKey == LogicalKeyboardKey.keyA) {
        n = 10;
      } else if (event.logicalKey == LogicalKeyboardKey.keyB) {
        n = 11;
      } else if (event.logicalKey == LogicalKeyboardKey.keyC) {
        n = 12;
      } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
        n = 13;
      } else if (event.logicalKey == LogicalKeyboardKey.keyE) {
        n = 14;
      } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
        n = 15;
      } else if (event.logicalKey == LogicalKeyboardKey.keyG) {
        n = 16;
      }
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

  Future<void> _checkCompletion() async {
    _click();
    if (_paused || _gameOver) return;
    if (_puzzle.isComplete() && _puzzle.isCorrect()) {
      _timer?.cancel();
      // 本地立即结算，网络提交放后台，断网时也能马上播音效和显示结果
      _lastScore = _calculateScore();
      setState(() {
        _paused = true;
        _isSolved = true;
      });
      _playWin();
      _submitScore(won: true);
    } else {
      setState(() => _statusMsg = '还有空格未填，请再检查一下吧');
      _statusTimer?.cancel();
      _statusTimer = Timer(const Duration(seconds: 4), () {
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
      for (int r = 0; r < gs; r++) {
        for (int c = 0; c < gs; c++) {
          _puzzle.cells[r][c] = _puzzle.solution[r][c];
        }
      }
    });
    _syncErrorState();
  }

  void _restart() {
    _click();
    _undoStack.clear();
    _redoStack.clear();
    final gs = _puzzle.gridSize;
    for (int r = 0; r < gs; r++) {
      for (int c = 0; c < gs; c++) {
        if (!_puzzle.given[r][c]) _puzzle.cells[r][c] = 0;
        _puzzle.notes[r][c].clear();
      }
    }
    _errors = 0;
    _gameOver = false;
    _isSolved = false;
    _hasGivenUp = false;
    _statusMsg = '';
    _seconds = 0;
    _startTimer();
    _boardKey.currentState?.syncErrors();
    if (mounted) setState(() {});
  }

  // ---- 存档功能 ----

  /// 正在进行的存档请求（读档前需等待其完成，避免拿到旧数据）
  Future<void>? _saveFuture;

  /// 保存当前游戏进度到服务器
  Future<void> _saveGame({bool silent = false, String successMsg = '存档成功', String failMsg = '存档失败'}) {
    final future = _doSaveGame(silent: silent, successMsg: successMsg, failMsg: failMsg);
    _saveFuture = future;
    return future.whenComplete(() {
      if (identical(_saveFuture, future)) _saveFuture = null;
    });
  }

  Future<void> _doSaveGame({bool silent = false, String successMsg = '存档成功', String failMsg = '存档失败'}) async {
    // 已完成的棋局不允许再存档，防止读档后直接点完成重复提交成绩
    if (_isSolved || _gameOver || _hasGivenUp) {
      if (!silent && mounted) _showStatus('本局已结束，无需存档');
      return;
    }
    final payload = _buildSavePayload();
    if (!silent && mounted) _showStatus('正在保存...');
    // 1) 本地 SQLite 立即写入：离线也能保存
    try {
      await LocalSaveStore.save(widget.username, payload, synced: false);
      if (!silent && mounted) _showStatus(successMsg);
    } catch (_) {
      if (!silent && mounted) _showStatus(failMsg);
    }
    // 2) 云端同步（后台尽力而为）：失败不影响本地存档
    try {
      await ApiService.saveGame(
        username: widget.username,
        boardSize: _boardSize,
        cells: _puzzle.cells,
        notes: _puzzle.notes,
        solution: _puzzle.solution,
        given: _puzzle.given,
        seconds: _seconds,
        errors: _errors,
        isKiller: _isKiller,
        killerDifficulty: _killerDifficulty,
        cages: payload['cages'] as List<dynamic>?,
        seed: _currentSeed,
      );
      await LocalSaveStore.markSynced(widget.username);
    } catch (_) {}
  }

  /// 构造与后端 /save 请求一致的存档 JSON（本地与云端共用），并写入本地保存时间
  Map<String, dynamic> _buildSavePayload() {
    final notesJson = _puzzle.notes
        .map((row) => row.map((s) => s.toList()).toList())
        .toList();
    final cagesJson = _puzzle.cages
        ?.map((c) => {'cellIndices': c.cellIndices, 'sum': c.sum, 'op': c.op})
        .toList();
    return {
      'username': widget.username,
      'boardSize': _boardSize,
      'cells': _puzzle.cells,
      'notes': notesJson,
      'solution': _puzzle.solution,
      'given': _puzzle.given
          .map((row) => row.map((b) => b ? 1 : 0).toList())
          .toList(),
      'seconds': _seconds,
      'errors': _errors,
      'isKiller': _isKiller,
      'killerDifficulty': _killerDifficulty,
      'cages': cagesJson ?? [],
      'seed': _currentSeed,
      'savedAt': _nowText(),
    };
  }

  /// 当前本地时间，格式与后端 savedAt 一致
  String _nowText() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)} ${two(n.hour)}:${two(n.minute)}:${two(n.second)}';
  }

  /// 解析 savedAt 时间戳，解析失败按 0 处理
  DateTime _parseSavedAt(String t) {
    try {
      return DateTime.parse(t.replaceFirst(' ', 'T'));
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  /// 本地 SQLite + 云端合并取最新存档：时间戳较新的赢
  Future<Map<String, dynamic>?> _fetchSave() async {
    Map<String, dynamic>? local;
    try {
      local = await LocalSaveStore.load(widget.username);
    } catch (_) {}
    Map<String, dynamic>? cloud;
    var cloudOk = false;
    try {
      cloud = await ApiService.loadGame(username: widget.username);
      cloudOk = cloud != null && cloud['success'] == true;
    } catch (_) {}
    if (local == null && !cloudOk) return null;
    if (local == null) {
      // 只有云端：采用云端，并落到本地一份
      if (cloud != null) {
        try {
          await LocalSaveStore.save(widget.username, cloud, synced: true);
        } catch (_) {}
      }
      return cloud;
    }
    if (!cloudOk) {
      // 只有本地（离线）：采用本地
      local['success'] = true;
      return local;
    }
    // 云端 vs 本地：保存时间较新的赢
    final localT = _parseSavedAt(local['savedAt'] ?? '');
    final cloudT = _parseSavedAt(cloud?['savedAt'] ?? '');
    if (cloudT.isAfter(localT)) {
      // 云端更新：覆盖本地
      try {
        await LocalSaveStore.save(widget.username, cloud!, synced: true);
      } catch (_) {}
      return cloud;
    } else {
      // 本地更新或持平：用本地覆盖云端（尽力而为）
      try {
        await ApiService.uploadRawSave(local);
        await LocalSaveStore.markSynced(widget.username);
      } catch (_) {}
      local['success'] = true;
      return local;
    }
  }
  /// 从服务器加载最近一次存档
  Future<void> _loadGame() async {
    try {
      _click();
      _hideKeyboard();
      _loadingSave = true;
      _showStatus('正在加载...');
      // 等待暂停时自动存档完成，避免读档拿到旧数据
      while (_saveFuture != null) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      final res = await _fetchSave();
      if (!mounted) return;
      if (res == null || res['success'] != true) {
        _showStatus('读档失败');
        return;
      }
      final savedAt = res['savedAt'] ?? '';

      // 确认加载
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 300,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_download_rounded,
                    size: 44,
                    color: context.colors.primary,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '加载存档',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '存档时间\n$savedAt\n当前未保存的进度将丢失。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.textFaint,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: BorderSide(color: context.colors.divider),
                          ),
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            '取消',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: context.colors.primary,
                            foregroundColor: context.colors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('加载'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      _textFocus.unfocus();
      if (go != true || !mounted) return;

      _restoreFromData(res);
      _showStatus('读档成功');
    } catch (_) {
      if (mounted) _showStatus('加载失败');
    } finally {
      _loadingSave = false;
    }
  }

  /// 从存档数据恢复游戏状态
  void _restoreFromData(Map<String, dynamic> res) {
    final boardSize = res['boardSize'] as int? ?? 3;
    final isKiller = res['isKiller'] == true;
    final cellsRaw = res['cells'] as List;
    final notesRaw = res['notes'] as List;
    final solutionRaw = res['solution'] as List;
    final givenRaw = res['given'] as List;
    final seconds = res['seconds'] as int? ?? 0;
    final errors = res['errors'] as int? ?? 0;
    final killerDifficulty = res['killerDifficulty'] as String? ?? '中等';
    final cagesRaw = res['cages'] as List? ?? [];
    final seed = res['seed'] as int? ?? 0;

    final gs = boardSize * boardSize;
    _boardSize = boardSize;
    _isKiller = isKiller;
    _killerDifficulty = killerDifficulty;
    _currentSeed = seed;
    _puzzle = SudokuPuzzle(boardSize: boardSize);

    for (int r = 0; r < gs; r++) {
      for (int c = 0; c < gs; c++) {
        if (r < cellsRaw.length && c < (cellsRaw[r] as List).length) {
          _puzzle.cells[r][c] = (cellsRaw[r] as List)[c] as int? ?? 0;
        }
        if (r < solutionRaw.length && c < (solutionRaw[r] as List).length) {
          _puzzle.solution[r][c] = (solutionRaw[r] as List)[c] as int? ?? 0;
        }
        if (r < givenRaw.length && c < (givenRaw[r] as List).length) {
          _puzzle.given[r][c] = (givenRaw[r] as List)[c] == 1;
        }
        if (r < notesRaw.length && c < (notesRaw[r] as List).length) {
          final noteList = (notesRaw[r] as List)[c] as List;
          _puzzle.notes[r][c] = noteList.cast<int>().toSet();
        }
      }
    }

    // 恢复笼子（算数数独）
    if (isKiller && cagesRaw.isNotEmpty) {
      _puzzle.cages = cagesRaw.map((c) {
        final cMap = c as Map<String, dynamic>;
        return Cage(
          cellIndices: (cMap['cellIndices'] as List).cast<int>(),
          sum: cMap['sum'] as int? ?? 0,
          op: cMap['op'] as String? ?? '+',
        );
      }).toList();
    }

    _seconds = seconds;
    _errors = errors;
    // 读档后若棋盘已全部填对，视为已完成，防止直接点完成再次提交成绩
    _isSolved = _puzzle.isComplete() && _puzzle.isCorrect();
    _hasGivenUp = false;
    _gameOver = errors >= (boardSize == 3 ? 3 : 6);
    _paused = false;
    _undoStack.clear();
    _redoStack.clear();
    // 读档恢复的进度视为可存档：暂停/退出自动保存（含计时），无需再动棋盘
    _dirty = true;
    _boardKey = GlobalKey();

    // 已解答或已结束的棋局不再计时
    if (!_isSolved && !_gameOver) _startTimer();
    if (mounted) setState(() {});
    // 帧渲染后同步棋盘错误状态，确保之前填错的格子恢复红色
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boardKey.currentState?.syncErrors();
    });
    _showStatus('存档已恢复');
  }

  /// 计算标准时间（秒）
  int _standardTime() {
    if (_boardSize == 4) {
      switch (_difficulty) {
        case '简单':
          return 3600;
        case '中等':
          return 7200;
        case '困难':
          return 14400;
        default:
          return 7200;
      }
    }
    if (_isKiller) {
      switch (_killerDifficulty) {
        case '入门':
          return 2400;
        case '中等':
          return 4800;
        case '困难':
          return 9600;
        default:
          return 4800;
      }
    }
    switch (_difficulty) {
      case '简单':
        return 1800;
      case '中等':
        return 3600;
      case '困难':
      case '极简':
        return 7200;
      default:
        return 3600;
    }
  }

  /// 计算本局得分
  int _calculateScore() {
    // 基础分 × 模式系数（已合并到基础分）
    double base;
    if (_isKiller) {
      base = 200; // 杀手 ×2.0
    } else if (_boardSize == 4) {
      base = 250; // 16×16 ×2.5
    } else {
      base = 100; // 9×9 常规 ×1.0
    }

    // 难度系数
    String diff = _isKiller ? _killerDifficulty : _difficulty;
    double diffCoeff;
    switch (diff) {
      case '简单':
      case '入门':
        diffCoeff = 1.0;
        break;
      case '中等':
        diffCoeff = 1.5;
        break;
      case '困难':
      case '极简':
        diffCoeff = 2.0;
        break;
      default:
        diffCoeff = 1.0;
    }

    // 时间加成：(标准耗时 / 实际耗时) × 0.5 + 0.5，最低 0.5
    double timeCoeff = (_standardTime() / _seconds) * 0.5 + 0.5;
    timeCoeff = timeCoeff.clamp(0.5, 5.0);

    // 错误惩罚：每次错误扣 1/maxErrors
    double errorPenalty = (_maxErrors - _errors) / _maxErrors;
    if (errorPenalty < 0) errorPenalty = 0;

    return (base * diffCoeff * timeCoeff * errorPenalty).round();
  }

  /// 提交游戏结果（赢/输）到排行榜统计，返回得分
  Future<int> _submitScore({bool won = true}) async {
    final score = _calculateScore();
    try {
      String mode;
      if (_isKiller) {
        mode = '算数$_killerDifficulty';
      } else if (_boardSize == 4) {
        mode = '4×4$_difficulty';
      } else {
        mode = '3×3$_difficulty';
      }
      final res = await ApiService.submitScore(
        username: widget.username,
        won: won,
        gameMode: mode,
        boardSize: _boardSize,
        score: score,
        puzzleKey: _puzzle.fingerprint(),
      );
      if (mounted && won) {
        if (res['success'] == true) {
          _showStatus('积分已保存：$score 分');
        } else {
          _showStatus('提交失败');
        }
      }
    } catch (_) {
      if (mounted && won) _showStatus('提交失败');
    }
    return score;
  }

  /// 打开种子弹窗：展示当前种子，支持复制与输入复现
  void _showSeedDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _SeedDialog(
        seedLabel: _seedLabel,
        onApply: (seed) {
          Navigator.pop(ctx);
          _newGame(seed: seed);
        },
      ),
    );
  }

  void _showModeMenu() {
    if (!_debounce()) return;
    _clickChannel.invokeMethod('vibrate');
    // 收起手机键盘，防止菜单关闭后键盘弹出
    _textFocus.unfocus();
    try {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    } catch (_) {}

    final RenderBox? box =
        _menuIconKey.currentContext?.findRenderObject() as RenderBox?;
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
              const Text('3×3 算数', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 18),
              if (isKillerSelected)
                Icon(Icons.check, size: 14, color: context.colors.primary),
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
              if (is3Selected)
                Icon(Icons.check, size: 14, color: context.colors.primary),
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
              if (is4Selected)
                Icon(Icons.check, size: 14, color: context.colors.primary),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 在状态栏显示消息（棋盘上方），4秒后自动清除
  void _showStatus(String msg) {
    setState(() => _statusMsg = msg);
    _scheduleStatusClear();
  }

  /// 4秒后清除；若保存/读档请求仍在途则继续等待，避免“正在保存...”和结果之间闪现“已暂停”
  void _scheduleStatusClear() {
    _statusTimer?.cancel();
    _statusTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_saveFuture != null || _loadingSave) {
        _scheduleStatusClear();
        return;
      }
      setState(() => _statusMsg = '');
    });
  }

  int _cluesRemaining() {
    final gs = _puzzle.gridSize;
    int n = 0;
    for (int r = 0; r < gs; r++) {
      for (int c = 0; c < gs; c++) {
        if (_puzzle.cells[r][c] == 0) n++;
      }
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final infoStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);

    return Scaffold(
      backgroundColor: context.colors.background,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GestureDetector(
            key: _menuIconKey,
            onTap: () => _showModeMenu(),
            child: Icon(
              Icons.more_horiz,
              color: context.colors.textFaint,
              size: 24,
            ),
          ),
        ),
        leadingWidth: 40,
        title: const Text(
          '数独',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: context.colors.background,
        foregroundColor: context.colors.textPrimary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: () {
                _hideKeyboard();
                _showSeedDialog();
              },
              child: Icon(
                Icons.casino,
                color: context.colors.textFaint,
                size: 20,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _paused || _gameOver
                  ? null
                  : () {
                      setState(() => _noteMode = !_noteMode);
                    },
              child: Icon(
                _noteMode ? Icons.edit_note : Icons.edit_note_outlined,
                color: _noteMode
                    ? context.colors.primary
                    : context.colors.textFaint,
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
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 48,
                child: TextField(
                  controller: _textController,
                  focusNode: _textFocus,
                  keyboardType: _boardSize == 3
                      ? TextInputType.number
                      : TextInputType.text,
                  obscureText: _boardSize == 3,
                  textInputAction: TextInputAction.done,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.transparent,
                  ),
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
                      // 错误次数右侧间距与计时器右侧间距对称（均 24），左侧 12 保持视觉平衡
                      const SizedBox(width: 12),
                      Icon(
                        Icons.error_outline,
                        size: 14,
                        color: _errors >= _maxErrors
                            ? _red
                            : context.colors.textFaint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_errors/$_maxErrors',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _errors >= _maxErrors
                              ? _red
                              : context.colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: (_gameOver || _hasGivenUp) ? null : _togglePause,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _paused ? Icons.play_arrow : Icons.pause,
                              size: 14,
                              color: (_gameOver || _hasGivenUp)
                                  ? context.colors.disabledText
                                  : context.colors.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _formatTime(_seconds),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: (_gameOver || _hasGivenUp)
                                    ? context.colors.disabledText
                                    : context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Text(
                        _isKiller ? _killerDifficulty : _difficulty,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isKiller
                              ? _diffKiller(_killerDifficulty)
                              : _diffColor(_difficulty),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_cluesRemaining()}空',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textSecondary,
                        ),
                      ),
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
                                child: Stack(
                                  children: [
                                    // 切换模式/新局时新旧棋盘交叉淡入淡出，避免生硬跳变
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 240),
                                      reverseDuration:
                                          const Duration(milliseconds: 180),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      transitionBuilder: (child, animation) =>
                                          FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                      child: KeyedSubtree(
                                        key: ValueKey(
                                            'board-${_modeCode()}-$_currentSeed'),
                                        child: SudokuBoard(
                                          key: _boardKey,
                                          puzzle: _puzzle,
                                          noteMode: _noteMode,
                                          readOnly: _paused || _gameOver,
                                          onCellChanged: _onCellChanged,
                                          onNoteChanged: _onNoteChanged,
                                          onRefresh: () => setState(() {}),
                                          onRequestInput: () async {
                                            await setSoftInputMode('nothing');
                                            _textFocus.requestFocus();
                                            if (!kIsWeb) {
                                              await SystemChannels.textInput
                                                  .invokeMethod('TextInput.show');
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                    // 新局生成中显示加载遮罩（淡入淡出），避免 4×4 生成时看起来像卡死
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        ignoring: !_generating,
                                        child: AnimatedOpacity(
                                          opacity: _generating ? 1 : 0,
                                          duration:
                                              const Duration(milliseconds: 200),
                                          child: Container(
                                            color: context.colors.surface
                                                .withOpacity(0.45),
                                            child: const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
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
    // 临时提示（保存/读档等结果）优先显示，避免被“解答正确”等常驻文字覆盖
    if (_statusMsg.isNotEmpty) {
      return Text(
        _statusMsg,
        style: style.copyWith(color: context.colors.textSecondary),
      );
    }
    if (_isSolved) {
      return Text(
        '解答正确！用时 ${_formatTime(_seconds)}，获得 $_lastScore 积分',
        style: style.copyWith(color: context.colors.userInput),
      );
    }
    if (_hasGivenUp) {
      return Text('已查看答案', style: style.copyWith(color: Colors.amber.shade800));
    }
    if (_gameOver) {
      return Text(
        '游戏结束，用时 ${_formatTime(_seconds)}，获得 $_lastScore 积分',
        style: style.copyWith(color: _red),
      );
    }
    if (_paused) {
      return Text(
        '已暂停',
        style: style.copyWith(color: context.colors.textSecondary),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildBottomBar(TextStyle s) {
    final disabled = _paused || _gameOver;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, thickness: 0.5),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _textBtn(
                    '新局',
                    _generating ? null : _newGame,
                    s,
                    icon: Icons.refresh,
                  ),
                  _textBtn(
                    '完成',
                    (disabled || _isSolved || _hasGivenUp)
                        ? null
                        : _checkCompletion,
                    s,
                    fill: true,
                    icon: Icons.star_border,
                    overlayIcon: Icons.check,
                  ),
                  _textBtn(
                    '求解',
                    (disabled || _isSolved || _hasGivenUp) ? null : _autoSolve,
                    s,
                    icon: Icons.lightbulb_outline,
                    iconAtEnd: true,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _iconTextBtn(
                    Icons.undo,
                    '撤销',
                    disabled ? null : (_undoStack.isEmpty ? null : _undo),
                    s,
                  ),
                  _iconTextBtn(Icons.replay, '重置', _restart, s),
                  _iconTextBtn(
                    Icons.redo,
                    '重做',
                    disabled ? null : (_redoStack.isEmpty ? null : _redo),
                    s,
                    iconAtEnd: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5, indent: 40, endIndent: 40),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _iconTextBtn(Icons.cloud_upload, '存档', (_isSolved || _gameOver || _hasGivenUp)
                    ? null
                    : () {
                        _click();
                        _hideKeyboard();
                        _saveGame();
                      }, s),
              Container(
                width: 1,
                height: 24,
                color: context.colors.divider,
                margin: const EdgeInsets.symmetric(horizontal: 24),
              ),
              _iconTextBtn(Icons.cloud_download, '读档', _loadGame, s),
            ],
          ),
        ),
      ],
    );
  }

  Widget _textBtn(
    String label,
    VoidCallback? onTap,
    TextStyle s, {
    bool fill = false,
    IconData? icon,
    IconData? overlayIcon,
    bool iconAtEnd = false,
  }) {
    final isDisabled = onTap == null;
    final Color color;
    if (isDisabled) {
      color = fill
          ? context.colors.onPrimary.withValues(alpha: 0.72)
          : context.colors.disabledText;
    } else if (fill) {
      color = context.colors.onPrimary;
    } else {
      color = context.colors.textSecondary;
    }
    final textStyle = s.copyWith(
      fontSize: 15,
      fontWeight: fill ? FontWeight.w600 : FontWeight.w500,
      color: color,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 88,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill
                ? (isDisabled
                    ? context.colors.primary.withValues(alpha: 0.38)
                    : context.colors.primary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          // 图标+文字整体居中，间距 4（与下排撤销/重置/重做一致）
          child: icon == null
              ? Text(label, style: textStyle)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (iconAtEnd) ...[
                      Text(label, style: textStyle),
                      const SizedBox(width: 4),
                    ],
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(icon, size: 20, color: color),
                          if (overlayIcon != null)
                            Icon(overlayIcon, size: 7, color: color),
                        ],
                      ),
                    ),
                    if (!iconAtEnd) ...[
                      const SizedBox(width: 4),
                      Text(label, style: textStyle),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _iconTextBtn(
    IconData icon,
    String label,
    VoidCallback? onTap,
    TextStyle s, {
    bool iconAtEnd = false,
  }) {
    final isDisabled = onTap == null;
    final color = isDisabled
        ? context.colors.disabledText
        : context.colors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 88,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          // 图标+文字整体居中，间距 4（撤销/重置/重做/存档/读档统一）
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconAtEnd) ...[
                Text(label, style: s.copyWith(fontSize: 15, color: color)),
                const SizedBox(width: 4),
              ],
              Icon(icon, size: 18, color: color),
              if (!iconAtEnd) ...[
                const SizedBox(width: 4),
                Text(label, style: s.copyWith(fontSize: 15, color: color)),
              ],
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

/// 种子弹窗：显示/复制当前种子，或输入种子复现同一局谜题
class _SeedDialog extends StatefulWidget {
  final String seedLabel;
  final ValueChanged<int> onApply;

  const _SeedDialog({required this.seedLabel, required this.onApply});

  @override
  State<_SeedDialog> createState() => _SeedDialogState();
}

class _SeedDialogState extends State<_SeedDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _copied = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? _parse() {
    final s = _controller.text.trim();
    if (s.isEmpty) return null;
    final v = int.tryParse(s, radix: 36);
    if (v == null) return null;
    // 与安卓 Int.toIntOrNull(36) 一致：溢出时按 32 位有符号截断
    return (v & 0xFFFFFFFF).toSigned(32);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: colors.surface,
      child: SizedBox(
        width: 300,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '游戏种子',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '相同种子可复现同一局谜题',
                style: TextStyle(fontSize: 11, color: colors.textFaint),
              ),
              const SizedBox(height: 12),
              // 当前种子 + 复制（复制成功变对勾，不弹提示）；文字整宽居中，按钮浮在右侧
              Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      widget.seedLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.seedLabel));
                          setState(() => _copied = true);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 38,
                          height: 46,
                        ),
                        icon: Icon(
                          _copied ? Icons.check : Icons.copy,
                          size: 18,
                          color: colors.noteText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                onChanged: (v) {
                  final clean = v.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
                  if (clean != v) {
                    _controller.value = TextEditingValue(
                      text: clean,
                      selection: TextSelection.collapsed(offset: clean.length),
                    );
                  }
                  setState(() {});
                },
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
                decoration: InputDecoration(
                  labelText: '填入种子',
                  labelStyle: TextStyle(fontSize: 12, color: colors.textFaint),
                  hintText: '如 ${widget.seedLabel}',
                  hintStyle: TextStyle(fontSize: 13, color: colors.textFaint),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(color: colors.divider),
                        foregroundColor: colors.textSecondary,
                      ),
                      child: const Text('取消', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      // 按钮常亮不熄灭：输入无效时点击不生效
                      onPressed: () {
                        final s = _parse();
                        if (s != null) widget.onApply(s);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('生成', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
