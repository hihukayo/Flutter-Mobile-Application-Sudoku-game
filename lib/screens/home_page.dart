import 'package:flutter/material.dart';
import 'game_page.dart';
import 'rank_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  final String username;
  final String phone;

  const HomePage({super.key, required this.username, required this.phone});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const GamePage(),
      const RankPage(),
      ProfilePage(username: widget.username, phone: widget.phone),
    ];

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: IndexedStack(index: _currentIndex, children: pages),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_on), label: '对局'),
          NavigationDestination(icon: Icon(Icons.emoji_events), label: '排行榜'),
          NavigationDestination(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
