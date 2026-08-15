import 'package:flutter/material.dart';
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
  final _rankKey = GlobalKey<RankPageState>();
  final _profileKey = GlobalKey<ProfilePageState>();

  void _switchToGame() {
    setState(() => _currentIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      GamePage(username: widget.username),
      RankPage(key: _rankKey, username: widget.username),
      ProfilePage(key: _profileKey, username: widget.username, phone: widget.phone, onGoToGame: _switchToGame),
    ];

    return Center(
      child: SizedBox(
        width: 480,
        child: Scaffold(
          // 键盘弹出时整个页面固定不动：棋盘、操作区、导航栏都不被上推
          resizeToAvoidBottomInset: false,
          body: _SlidePageSwitcher(index: _currentIndex, children: pages),
          bottomNavigationBar: _NoSoundNavBar(
            currentIndex: _currentIndex,
            onTap: (i) {
              setState(() => _currentIndex = i);
              if (i == 1) _rankKey.currentState?.refresh();
              if (i == 2) _profileKey.currentState?.refresh();
            },
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
      final curved =
          CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn);
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
        entries.add(KeyedSubtree(
          key: ValueKey(i),
          child: Offstage(offstage: true, child: widget.children[i]),
        ));
      }
    }
    // 旧页面在下、新页面在上，交叉滑动时新页始终在最上层
    if (animating) {
      entries.add(KeyedSubtree(
        key: ValueKey(_previousIndex),
        child: SlideTransition(
          position: _outgoing,
          child: widget.children[_previousIndex],
        ),
      ));
    }
    entries.add(KeyedSubtree(
      key: ValueKey(widget.index),
      child: SlideTransition(
        position: _incoming,
        child: widget.children[widget.index],
      ),
    ));
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: i == currentIndex
                                ? context.colors.selectedBg
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            icons[i],
                            size: 22,
                            color: i == currentIndex
                                ? context.colors.primary
                                : context.colors.textSecondary,
                          ),
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
