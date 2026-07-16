import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_page.dart';

String maskPhone(String phone) {
  if (phone.length < 7) return phone;
  return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
}

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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
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
                subtitle: maskPhone(widget.phone),
                onTap: () => _showEditDialog('手机号', widget.phone, (val, pwd) => ApiService.updatePhone(
                  username: widget.username, newPhone: val, password: pwd,
                )),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              _buildDangerCard(
                icon: Icons.delete_forever,
                title: '注销账号',
                subtitle: '永久删除所有数据',
                onTap: () => _showDeleteAccountDialog(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
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

  Widget _buildDangerCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.red),
        title: Text(title, style: const TextStyle(color: Colors.red)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _showEditDialog(String field, String current, Future<Map<String, dynamic>> Function(String value, String password) api) {
    final controller = TextEditingController();
    final pwdController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改$field', style: const TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(labelText: '请输入新$field', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwdController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '当前密码', border: OutlineInputBorder()),
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
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? '操作完成')));
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
        title: const Text('修改密码', style: TextStyle(fontSize: 18)),
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
                username: widget.username, oldPassword: oldCtrl.text, newPassword: newCtrl.text,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? '操作完成')));
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final phoneCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('注销账号', style: TextStyle(fontSize: 18, color: Colors.red)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('此操作不可恢复，所有数据将被永久删除。', style: TextStyle(color: Colors.red, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '手机号', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: pwdCtrl, obscureText: true, decoration: const InputDecoration(labelText: '密码', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: confirmPwdCtrl, obscureText: true, decoration: const InputDecoration(labelText: '确认密码', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (pwdCtrl.text != confirmPwdCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('两次密码不一致')));
                return;
              }
              final res = await ApiService.deleteAccount(
                username: widget.username, phone: phoneCtrl.text.trim(), password: pwdCtrl.text,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (res['success']) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('账号已注销')));
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('login_username');
                await prefs.remove('login_phone');
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? '操作失败')));
              }
            },
            child: const Text('确认注销'),
          ),
        ],
      ),
    );
  }
}
