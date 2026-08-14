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
          body: IndexedStack(index: _currentIndex, children: pages),
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: context.colors.surfaceAlt,
              surfaceTintColor: Colors.transparent,
              indicatorColor: context.colors.selectedBg,
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return IconThemeData(color: selected ? context.colors.primary : context.colors.textSecondary);
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 12,
                  color: selected ? context.colors.primary : context.colors.textSecondary,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) {
                setState(() => _currentIndex = i);
                if (i == 1) _rankKey.currentState?.refresh();
                if (i == 2) _profileKey.currentState?.refresh();
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.grid_on), label: '数独'),
                NavigationDestination(icon: Icon(Icons.emoji_events), label: '排行榜'),
                NavigationDestination(icon: Icon(Icons.person), label: '我的'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
