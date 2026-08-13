import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/window_util.dart';
import '../services/app_snack.dart';
import '../services/app_theme.dart';
import '../widgets/masked_text_controller.dart';
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
  @override
  void initState() {
    super.initState();
    setSoftInputMode('resize');
    _loadServerAddress();
  }

  Future<void> _loadServerAddress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _serverAddress = prefs.getString('server_address') ?? '');
  }

  void _showSnack(String msg) {
    showAppSnack(msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('设置')),
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
                onTap: () => _showEditDialog(
                  '用户名',
                  widget.username,
                  (val, pwd) => ApiService.updateUsername(
                    username: widget.username,
                    newUsername: val,
                    password: pwd,
                  ),
                ),
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
                onTap: () => _showEditDialog(
                  '手机号',
                  widget.phone,
                  (val, pwd) => ApiService.updatePhone(
                    username: widget.username,
                    newPhone: val,
                    password: pwd,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildCard(
                icon: _themeIcon(),
                title: '深色模式',
                subtitle: _themeLabel(),
                onTap: _showThemeModeDialog,
              ),
              const SizedBox(height: 12),
              _buildCard(
                icon: Icons.cloud_off,
                title: '服务器地址',
                subtitle: _serverAddress.isEmpty
                    ? '自动（USB/模拟器）'
                    : _serverAddress,
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

  Widget _buildDangerCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: context.colors.danger),
        title: Text(title, style: TextStyle(color: context.colors.danger)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  IconData _themeIcon() {
    switch (themeModeNotifier.value) {
      case 'light':
        return Icons.light_mode_outlined;
      case 'dark':
        return Icons.dark_mode_outlined;
      default:
        return Icons.contrast;
    }
  }

  String _themeLabel() {
    switch (themeModeNotifier.value) {
      case 'light':
        return '浅色';
      case 'dark':
        return '深色';
      default:
        return '跟随系统';
    }
  }

  Future<void> _showThemeModeDialog() async {
    final colors = context.colors;
    final options = [
      ('跟随系统', 'system', Icons.contrast),
      ('浅色', 'light', Icons.light_mode_outlined),
      ('深色', 'dark', Icons.dark_mode_outlined),
    ];
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('深色模式', style: TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, mode, icon) in options)
              ListTile(
                leading: Icon(
                  icon,
                  color: themeModeNotifier.value == mode
                      ? colors.primary
                      : colors.textSecondary,
                ),
                title: Text(label),
                trailing: themeModeNotifier.value == mode
                    ? Icon(Icons.check, color: colors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  // 先等弹窗关闭动画结束再切换主题，避免两个动画重叠造成卡顿
                  Future.delayed(
                    const Duration(milliseconds: 200),
                    () => setThemeMode(mode),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showServerAddressDialog() async {
    final controller = TextEditingController(text: _serverAddress);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('服务器地址', style: TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '留空则自动连接（USB / 模拟器）',
              style: TextStyle(fontSize: 13, color: context.colors.textFaint),
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
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, controller.text.trim());
            },
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

  void _showEditDialog(
    String field,
    String current,
    Future<Map<String, dynamic>> Function(String value, String password) api,
  ) {
    final controller = TextEditingController();
    final pwdController = MaskedTextController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改$field', style: const TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: '请输入新$field',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwdController,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '当前密码',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = controller.text.trim();
              if (value.isEmpty || pwdController.realText.isEmpty) {
                _showSnack('请输入新$field和当前密码');
                return;
              }
              final res = await api(value, pwdController.realText);
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
    final oldCtrl = MaskedTextController();
    final newCtrl = MaskedTextController();
    final confirmCtrl = MaskedTextController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改密码', style: TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '当前密码',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '新密码',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '确认新密码',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newCtrl.realText != confirmCtrl.realText) {
                _showSnack('两次密码不一致');
                return;
              }
              if (oldCtrl.realText.isEmpty || newCtrl.realText.isEmpty) {
                _showSnack('请填写完整');
                return;
              }
              final res = await ApiService.updatePassword(
                username: widget.username,
                oldPassword: oldCtrl.realText,
                newPassword: newCtrl.realText,
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
    final pwdCtrl = MaskedTextController();
    final confirmPwdCtrl = MaskedTextController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '注销账号',
          style: TextStyle(fontSize: 18, color: context.colors.danger),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '此操作不可恢复，所有数据将被永久删除。',
                style: TextStyle(color: context.colors.danger, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: '手机号',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pwdCtrl,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: '密码',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPwdCtrl,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: '确认密码',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.danger,
              foregroundColor: context.colors.onPrimary,
            ),
            onPressed: () async {
              if (pwdCtrl.realText != confirmPwdCtrl.realText) {
                _showSnack('两次密码不一致');
                return;
              }
              if (phoneCtrl.text.trim().isEmpty || pwdCtrl.realText.isEmpty) {
                _showSnack('请填写手机号和密码');
                return;
              }
              final res = await ApiService.deleteAccount(
                username: widget.username,
                phone: phoneCtrl.text.trim(),
                password: pwdCtrl.realText,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (res['success']) {
                _showSnack('账号已注销');
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('login_username');
                await prefs.remove('login_phone');
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (_) => false,
                );
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
