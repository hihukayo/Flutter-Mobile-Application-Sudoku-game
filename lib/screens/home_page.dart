import 'package:flutter/material.dart';
import 'login_page.dart';

class HomePage extends StatelessWidget {
  final String username;
  final String phone;
  const HomePage({super.key, required this.username, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pearl 珍珠棋'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '退出登录',
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (_) => false,
            ),
          ),
        ],
      ),
      body: Center(
        child: Text('欢迎，$username！\n手机号：$phone', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
