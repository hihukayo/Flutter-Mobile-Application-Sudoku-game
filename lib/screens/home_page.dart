import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_page.dart';
import 'rank_page.dart';
import 'profile_page.dart';
import '../services/app_theme.dart';

class HomePage extends StatefulWidget {
  final String username;
  final String phone;

  const HomePage({super.key, required this.username, required this.phone});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final List<int> _tabHistory = [];
  final _rankKey = GlobalKey<RankPageState>();
  final _profileKey = GlobalKey<ProfilePageState>();

  @override
  void initState() {
    super.initState();
    // 每次登录会话重置续玩提示标记：仅本次登录首次进入游戏页时自动弹一次
    GamePage.resumePromptShown = false;
  }

  void _switchToGame() {
    _switchTab(0);
  }

  /// tab 切换：压入访问历史，供返回键逐级回退（我的→排行榜→数独）
  void _switchTab(int i) {
    if (i == _currentIndex) return;
    setState(() {
      _tabHistory.add(_currentIndex);
      _currentIndex = i;
    });
    if (i == 1) _rankKey.currentState?.refresh();
    if (i == 2) _profileKey.currentState?.refresh();
  }

  /// 系统返回键：先按 tab 访问栈回退，栈空（数独页）时弹确认退出
  Future<void> _handleSystemBack() async {
    if (_tabHistory.isNotEmpty) {
      setState(() => _currentIndex = _tabHistory.removeLast());
      return;
    }
    final exit = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const _ExitConfirmDialog(),
    );
    if (exit == true && mounted) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      GamePage(username: widget.username),
      RankPage(key: _rankKey, username: widget.username),
      ProfilePage(
        key: _profileKey,
        username: widget.username,
        phone: widget.phone,
        onGoToGame: _switchToGame,
      ),
    ];

    return Center(
      child: SizedBox(
        width: 480,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleSystemBack();
          },
          child: Scaffold(
            // 键盘弹出时整个页面固定不动：棋盘、操作区、导航栏都不被上推
            resizeToAvoidBottomInset: false,
            body: _SlidePageSwitcher(index: _currentIndex, children: pages),
            bottomNavigationBar: _NoSoundNavBar(
              currentIndex: _currentIndex,
              onTap: _switchTab,
            ),
          ),
        ),
      ),
    );
  }
}

/// 翻页式左右滑动切换（保活各页面状态）：tab 向右点时新页从右往左滑入，向左点则相反
class _SlidePageSwitcher extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _SlidePageSwitcher({required this.index, required this.children});

  @override
  State<_SlidePageSwitcher> createState() => _SlidePageSwitcherState();
}

class _SlidePageSwitcherState extends State<_SlidePageSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<Offset> _incoming;
  late Animation<Offset> _outgoing;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _incoming = const AlwaysStoppedAnimation(Offset.zero);
    _outgoing = const AlwaysStoppedAnimation(Offset.zero);
  }

  @override
  void didUpdateWidget(covariant _SlidePageSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _previousIndex = oldWidget.index;
      final forward = widget.index > oldWidget.index;
      final curved = CurvedAnimation(
        parent: _controller,
        curve: Curves.fastOutSlowIn,
      );
      _incoming = Tween<Offset>(
        begin: Offset(forward ? 1 : -1, 0),
        end: Offset.zero,
      ).animate(curved);
      _outgoing = Tween<Offset>(
        begin: Offset.zero,
        end: Offset(forward ? -1 : 1, 0),
      ).animate(curved);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animating = _controller.isAnimating;
    final entries = <Widget>[];
    // 非参与动画的页面保持挂载（离屏保活），保证游戏计时等状态不丢
    for (int i = 0; i < widget.children.length; i++) {
      final isIncoming = i == widget.index;
      final isOutgoing = animating && i == _previousIndex;
      if (!isIncoming && !isOutgoing) {
        entries.add(
          KeyedSubtree(
            key: ValueKey(i),
            child: Offstage(offstage: true, child: widget.children[i]),
          ),
        );
      }
    }
    // 旧页面在下、新页面在上，交叉滑动时新页始终在最上层
    if (animating) {
      entries.add(
        KeyedSubtree(
          key: ValueKey(_previousIndex),
          child: SlideTransition(
            position: _outgoing,
            child: widget.children[_previousIndex],
          ),
        ),
      );
    }
    entries.add(
      KeyedSubtree(
        key: ValueKey(widget.index),
        child: SlideTransition(
          position: _incoming,
          child: widget.children[widget.index],
        ),
      ),
    );
    return Stack(fit: StackFit.expand, children: entries);
  }
}

/// 底部导航栏：GestureDetector 实现，无 InkWell，不触发系统点击音/反馈
class _NoSoundNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NoSoundNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const labels = ['数独', '排行榜', '我的'];
    const icons = [Icons.grid_on, Icons.emoji_events, Icons.person];
    return Container(
      color: context.colors.surfaceAlt,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (int i = 0; i < labels.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icons[i],
                          size: 22,
                          color: i == currentIndex
                              ? context.colors.primary
                              : context.colors.textSecondary,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: i == currentIndex
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: i == currentIndex
                                ? context.colors.primary
                                : context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 退出确认对话框：与安卓端一致的样式（图标 + 提示 + 取消/退出）
class _ExitConfirmDialog extends StatelessWidget {
  const _ExitConfirmDialog();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 300,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.logout, size: 40, color: colors.textSecondary),
            const SizedBox(height: 16),
            Text(
              '确定要退出吗？',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '未完成的棋局将自动保存',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colors.textFaint,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 15,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('退出', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
