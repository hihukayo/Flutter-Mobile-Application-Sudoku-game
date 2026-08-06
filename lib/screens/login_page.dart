import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/window_util.dart';
import '../services/app_snack.dart';
import 'register_page.dart';
import '../widgets/masked_text_controller.dart';
import '../widgets/server_address_dialog.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _accountController = TextEditingController();
  final _passwordController = MaskedTextController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    setSoftInputMode('resize');
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    showAppSnack(msg);
  }

  Future<void> _login() async {
    final account = _accountController.text.trim();
    final password = _passwordController.realText.trim();
    if (account.isEmpty || password.isEmpty) {
      _showMsg('请输入账号和密码');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await ApiService.login(account: account, password: password);
      if (!mounted) return;
      if (res['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('login_username', res['username'] ?? '');
        await prefs.setString('login_phone', res['phone'] ?? '');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(
              username: res['username'] ?? '',
              phone: res['phone'] ?? '',
            ),
          ),
        );
      } else {
        _showMsg(res['message'] ?? '登录失败');
      }
    } catch (_) {
      if (!mounted) return;
      _showMsg('连接失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goRegister() async {
    final username = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
    if (!mounted || username == null) return;
    _accountController.text = username;
    _showMsg('注册成功，请登录');
  }

  Future<void> _showServerSetting() async {
    await showServerAddressDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      '数独',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sudoku',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 40),
                    TextField(
                      controller: _accountController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '用户名 / 手机号',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      textInputAction: TextInputAction.done,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: '密码',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(() {
                            _obscurePassword = !_obscurePassword;
                            _passwordController.reveal = !_obscurePassword;
                            _passwordController.refresh();
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('登录', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _loading ? null : _goRegister,
                      child: const Text('没有账号？去注册'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.settings),
              tooltip: '服务器设置',
              onPressed: _showServerSetting,
            ),
          ),
        ],
      ),
    );
  }
}