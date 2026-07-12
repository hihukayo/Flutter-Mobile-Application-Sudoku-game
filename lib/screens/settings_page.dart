import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsPage extends StatefulWidget {
  final String username;
  final String phone;

  const SettingsPage({super.key, required this.username, required this.phone});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildCard(
            icon: Icons.person,
            title: '修改用户名',
            subtitle: widget.username,
            onTap: () => _showEditDialog('用户名', widget.username, (val, pwd) => ApiService.updateUsername(
              username: widget.username, newUsername: val, password: pwd,
            )),
          ),
          const SizedBox(height: 12),
          _buildCard(
            icon: Icons.lock,
            title: '修改密码',
            subtitle: '******',
            onTap: () => _showPasswordDialog(),
          ),
          const SizedBox(height: 12),
          _buildCard(
            icon: Icons.phone,
            title: '修改手机号',
            subtitle: widget.phone,
            onTap: () => _showEditDialog('手机号', widget.phone, (val, pwd) => ApiService.updatePhone(
              username: widget.username, newPhone: val, password: pwd,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _showEditDialog(
    String field,
    String current,
    Future<Map<String, dynamic>> Function(String value, String password) api,
  ) {
    final controller = TextEditingController(text: current);
    final pwdController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改$field'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(labelText: '新$field', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwdController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '当前密码', border: const OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final res = await api(controller.text.trim(), pwdController.text);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(res['message'] ?? '操作完成')),
              );
              if (res['success']) Navigator.pop(context, true);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showPasswordDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldCtrl, obscureText: true, decoration: const InputDecoration(labelText: '当前密码', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: '新密码', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: '确认新密码', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('两次密码不一致')));
                return;
              }
              final res = await ApiService.updatePassword(
                username: widget.username,
                oldPassword: oldCtrl.text,
                newPassword: newCtrl.text,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(res['message'] ?? '操作完成')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
