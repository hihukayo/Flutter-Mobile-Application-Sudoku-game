import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'settings_page.dart';
import '../services/api_service.dart';

class ProfilePage extends StatefulWidget {
  final String username;
  final String phone;
  final VoidCallback? onGoToGame;

  const ProfilePage({super.key, required this.username, required this.phone, this.onGoToGame});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  Uint8List? _avatarBytes;
  int _totalGames = 0;
  int _completedGames = 0;
  int _totalScore = 0;
  double _winRate = 0.0;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => _statsLoading = true);
    _syncAvatarFromServer(); // 切回“我的”时同步头像
    try {
      final res = await ApiService.getUserStats(username: widget.username);
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _totalGames = res['totalGames'] ?? 0;
          _completedGames = res['completedGames'] ?? 0;
          _totalScore = (res['totalScore'] as num?)?.toInt() ?? 0;
          _winRate = (res['winRate'] as num?)?.toDouble() ?? 0.0;
          _statsLoading = false;
        });
      } else {
        setState(() => _statsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('avatar_${widget.username}');
    if (stored != null) {
      setState(() => _avatarBytes = base64Decode(stored));
    }
  }

  /// 从服务器同步头像（换机/换 App 后也能恢复）
  Future<void> _syncAvatarFromServer() async {
    try {
      final res = await ApiService.getAvatar(username: widget.username);
      if (!mounted || res['success'] != true) return;
      final serverAvatar = res['avatar'] as String? ?? '';
      if (serverAvatar.isNotEmpty) {
        final bytes = base64Decode(serverAvatar);
        setState(() => _avatarBytes = bytes);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('avatar_${widget.username}', serverAvatar);
      }
    } catch (_) {}
  }

  Future<void> _saveAvatar(Uint8List bytes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatar_${widget.username}', base64Encode(bytes));
    // 上传服务器，实现跨设备/跨 App 同步
    try {
      await ApiService.uploadAvatar(
        username: widget.username,
        avatarBase64: base64Encode(bytes),
      );
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (xfile == null) return;

    final bytes = await xfile.readAsBytes();
    setState(() => _avatarBytes = bytes);
    _saveAvatar(bytes);
  }

  Color _winRateColor() {
    if (_winRate >= 70) return const Color(0xFF2E7D32);
    if (_winRate >= 40) return const Color(0xFF0B4CFF);
    if (_winRate > 0) return const Color(0xFFE65100);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // ---- 头像 + 用户名 ----
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: const Color(0xFF0B4CFF),
                    backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                    child: _avatarBytes == null
                        ? Text(
                            widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 16, color: Color(0xFF455A64)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              widget.username,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
            ),
          ),
          const SizedBox(height: 24),

          // ---- 统计卡片 ----
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: const Color(0xFFF5F7FA),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statItem(Icons.sports_esports, '总局数', _statsLoading ? '...' : '$_totalGames', const Color(0xFF0B4CFF)),
                  _divider(),
                  _statItem(Icons.emoji_events, '总积分', _statsLoading ? '...' : '$_totalScore', const Color(0xFFE65100)),
                  _divider(),
                  _statItem(Icons.trending_up, '胜率', _statsLoading ? '...' : '${_winRate.toStringAsFixed(1)}%', _winRateColor()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ---- 操作菜单 ----
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings, color: Color(0xFF455A64)),
                  title: const Text('设置', style: TextStyle(fontSize: 15)),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFFB0BEC5)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsPage(username: widget.username, phone: widget.phone),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ---- 退出登录 ----
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[400],
                side: BorderSide(color: Colors.red[200]!),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('login_username');
                await prefs.remove('login_phone');
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('退出登录', style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF78909C)),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 40, color: Colors.grey[300]);
  }
}
