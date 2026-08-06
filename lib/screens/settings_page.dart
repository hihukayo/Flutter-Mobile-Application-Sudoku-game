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
  String _serverAddress = '';
  late final ScaffoldMessengerState _messenger = ScaffoldMessenger.of(context);

  @override
  void initState() {
    super.initState();
    _loadServerAddress();
  }

  Future<void> _loadServerAddress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _serverAddress = prefs.getString('server_address') ?? '');
  }

  @override
  void dispose() {
    _messenger.clearSnackBars();
    super.dispose();
  }

  void _showSnack(String msg) {
    _messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
        ),
      );
  }

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
              const SizedBox(height: 12),
              _buildCard(
                icon: Icons.cloud_off,
                title: '服务器地址',
                subtitle: _serverAddress.isEmpty ? '自动（USB/模拟器）' : _serverAddress,
                onTap: _showServerAddressDialog,
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

  Future<void> _showServerAddressDialog() async {
    final controller = TextEditingController(text: _serverAddress);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('服务器地址', style: TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '留空则使用默认（USB：localhost / 模拟器：10.0.2.2）',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '例如 192.168.1.100:8080',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null) {
      await ApiService.setServerAddress(result);
      setState(() => _serverAddress = result);
      if (mounted) {
        _showSnack(result.isEmpty ? '已恢复默认连接' : '服务器地址已保存');
      }
    }
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
              final value = controller.text.trim();
              if (value.isEmpty || pwdController.text.isEmpty) {
                _showSnack('请输入新$field和当前密码');
                return;
              }
              final res = await api(value, pwdController.text);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _showSnack(res['message'] ?? '操作完成');
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
                _showSnack('两次密码不一致');
                return;
              }
              if (oldCtrl.text.isEmpty || newCtrl.text.isEmpty) {
                _showSnack('请填写完整');
                return;
              }
              final res = await ApiService.updatePassword(
                username: widget.username, oldPassword: oldCtrl.text, newPassword: newCtrl.text,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _showSnack(res['message'] ?? '操作完成');
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
                _showSnack('两次密码不一致');
                return;
              }
              if (phoneCtrl.text.trim().isEmpty || pwdCtrl.text.isEmpty) {
                _showSnack('请填写手机号和密码');
                return;
              }
              final res = await ApiService.deleteAccount(
                username: widget.username, phone: phoneCtrl.text.trim(), password: pwdCtrl.text,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (res['success']) {
                _showSnack('账号已注销');
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('login_username');
                await prefs.remove('login_phone');
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
              } else {
                _showSnack(res['message'] ?? '操作失败');
              }
            },
            child: const Text('确认注销'),
          ),
        ],
      ),
    );
  }
}
