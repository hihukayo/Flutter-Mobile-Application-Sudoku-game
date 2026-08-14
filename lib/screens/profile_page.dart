import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'settings_page.dart';
import '../services/api_service.dart';
import '../services/app_theme.dart';

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
  Map<String, int> _contribMap = {};
  bool _contribLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    refresh();
    _loadContributions();
  }

  Future<void> refresh() async {
    setState(() => _statsLoading = true);
    _loadContributions();
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

  /// 拉取完成日历数据（近一年，按天统计完成局数）
  Future<void> _loadContributions() async {
    try {
      final res = await ApiService.getContributions(username: widget.username, days: 365);
      if (!mounted) return;
      if (res['success'] == true && res['data'] != null) {
        final map = <String, int>{};
        for (final item in (res['data'] as List)) {
          final m = item as Map<String, dynamic>;
          final date = m['date'] as String? ?? '';
          final count = (m['count'] as num?)?.toInt() ?? 0;
          if (date.isNotEmpty) map[date] = count;
        }
        setState(() {
          _contribMap = map;
          _contribLoading = false;
        });
      } else {
        setState(() => _contribLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _contribLoading = false);
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
                    backgroundColor: context.colors.primary,
                    backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                    child: _avatarBytes == null
                        ? Text(
                            widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?',
                            style: TextStyle(fontSize: 36, color: context.colors.onPrimary, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt, size: 16, color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              widget.username,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
            ),
          ),
          const SizedBox(height: 24),

          // ---- 统计卡片 ----
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: context.colors.surfaceAlt,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statItem(Icons.sports_esports, '总局数', _statsLoading ? '...' : '$_totalGames', context.colors.primary),
                  _divider(),
                  _statItem(Icons.emoji_events, '总积分', _statsLoading ? '...' : '$_totalScore', const Color(0xFFE65100)),
                  _divider(),
                  _statItem(Icons.trending_up, '胜率', _statsLoading ? '...' : '${_winRate.toStringAsFixed(1)}%', _winRateColor()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ---- 完成日历 ----
          _buildCalendarCard(),
          const SizedBox(height: 12),

          // ---- 操作菜单 ----
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.settings, color: context.colors.textSecondary),
                  title: const Text('设置', style: TextStyle(fontSize: 15)),
                  trailing: Icon(Icons.chevron_right, color: context.colors.textFaint),
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
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.danger,
                foregroundColor: context.colors.onPrimary,
                elevation: 0,
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
          style: TextStyle(fontSize: 12, color: context.colors.textFaint),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 40, color: context.colors.divider);
  }

  // ---- 完成日历卡片（月历圆点，风格区别于安卓的横向 53 周） ----
  Widget _buildCalendarCard() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: context.colors.surfaceAlt,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, size: 18, color: context.colors.primary),
                const SizedBox(width: 6),
                Text(
                  '完成日历',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                ),
                const Spacer(),
                if (!_contribLoading && _contribMap.isNotEmpty) _legend(dark),
              ],
            ),
            const SizedBox(height: 12),
            if (_contribLoading)
              const SizedBox(
                height: 110,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
              )
            else if (_contribMap.isEmpty)
              SizedBox(
                height: 90,
                child: Center(
                  child: Text('暂无记录，完成一局后开始统计', style: TextStyle(fontSize: 13, color: context.colors.textFaint)),
                ),
              )
            else
              _buildMonthGrid(dark),
          ],
        ),
      ),
    );
  }

  /// 最近 12 个月，每张卡片是一个真实月历点阵
  Widget _buildMonthGrid(bool dark) {
    final now = DateTime.now();
    final months = <DateTime>[
      for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i, 1),
    ];
    var maxCount = 1;
    for (final c in _contribMap.values) {
      if (c > maxCount) maxCount = c;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final m in months)
              SizedBox(width: cellWidth, child: _buildMonthCard(m, maxCount, dark)),
          ],
        );
      },
    );
  }

  Widget _buildMonthCard(DateTime month, int maxCount, bool dark) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstIndex = DateTime(month.year, month.month, 1).weekday - 1; // 周一=0
    final monthTotal = _monthTotal(month);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${month.year}年${month.month}月',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textSecondary),
              ),
              const Spacer(),
              Text(
                '$monthTotal 局',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: monthTotal > 0 ? _levelColor(3, dark) : context.colors.textFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var row = 0; row * 7 < firstIndex + daysInMonth; row++)
            Padding(
              padding: EdgeInsets.only(bottom: row * 7 + 7 < firstIndex + daysInMonth ? 3 : 0),
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++) ...[
                    _dayDot(row * 7 + col, firstIndex, daysInMonth, month, maxCount, dark),
                    if (col < 6) const SizedBox(width: 2),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayDot(int idx, int firstIndex, int daysInMonth, DateTime month, int maxCount, bool dark) {
    final day = idx - firstIndex + 1;
    if (day < 1 || day > daysInMonth) {
      return const SizedBox(width: 12, height: 12);
    }
    final key = '${month.year}-${month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final count = _contribMap[key] ?? 0;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _dotColor(count, maxCount, dark)),
    );
  }

  /// 动态分级：按近一年内单日最大完成数分 4 档
  Color _dotColor(int count, int maxCount, bool dark) {
    if (count <= 0) {
      return dark ? const Color(0xFF26313C) : const Color(0xFFE9EDF2);
    }
    final t = (count / maxCount).clamp(0.0, 1.0);
    var idx = (t * 4).floor();
    if (idx < 0) idx = 0;
    if (idx > 3) idx = 3;
    return _levelColor(idx, dark);
  }

  Color _levelColor(int level, bool dark) {
    const light = [Color(0xFFC8EAD8), Color(0xFF8FD4AC), Color(0xFF4FB87F), Color(0xFF1F9A5F)];
    const darkPalette = [Color(0xFF1D4A38), Color(0xFF2E7D55), Color(0xFF3FAE75), Color(0xFF57D99A)];
    final palette = dark ? darkPalette : light;
    var i = level;
    if (i < 0) i = 0;
    if (i > 3) i = 3;
    return palette[i];
  }

  Widget _legend(bool dark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('少', style: TextStyle(fontSize: 11, color: context.colors.textFaint)),
        const SizedBox(width: 4),
        for (var l = 0; l <= 4; l++) ...[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: l == 0 ? (dark ? const Color(0xFF26313C) : const Color(0xFFE9EDF2)) : _levelColor(l - 1, dark),
            ),
          ),
          if (l < 4) const SizedBox(width: 3),
        ],
        const SizedBox(width: 4),
        Text('多', style: TextStyle(fontSize: 11, color: context.colors.textFaint)),
      ],
    );
  }

  int _monthTotal(DateTime month) {
    var total = 0;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    for (var d = 1; d <= daysInMonth; d++) {
      final key = '${month.year}-${month.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      total += _contribMap[key] ?? 0;
    }
    return total;
  }
}
