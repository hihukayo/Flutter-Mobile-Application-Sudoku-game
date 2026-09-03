import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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

class ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  Uint8List? _avatarBytes;
  int _totalGames = 0;
  int _completedGames = 0;
  int _totalScore = 0;
  double _winRate = 0.0;
  bool _statsLoading = true;
  Map<String, int> _contribMap = {};
  bool _contribLoading = true;
  bool _contribError = false;
  final ScrollController _calendarScroll = ScrollController();
  bool _calScrolledToEnd = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAvatar();
    // 统计与贡献日历在切换到“我的”页时由 HomePage 触发 refresh 加载，避免启动并发请求拖慢进入
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 回到前台时刷新统计与日历，保证数据时时最新（后端关闭时会提示加载失败）
    if (state == AppLifecycleState.resumed) refresh();
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

  /// 头像位置：略低于右上角设置齿轮，避免贴顶
  double _avatarTop() {
    return MediaQuery.of(context).padding.top + 36;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _calendarScroll.dispose();
    super.dispose();
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
          _contribError = false;
          _contribLoading = false;
        });
      } else {
        setState(() {
          _contribMap = {};
          _contribError = true;
          _contribLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _contribMap = {};
          _contribError = true;
          _contribLoading = false;
        });
      }
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
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: _avatarTop(),
              bottom: 24,
            ),
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
          const SizedBox(height: 6),
          Center(
            child: Text(
              widget.username,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
            ),
          ),
          const SizedBox(height: 12),

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
          const SizedBox(height: 10),
          // ---- 完成日历 ----
          _buildCalendarCard(),
          const SizedBox(height: 12),

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
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 4,
            child: IconButton(
              icon: Icon(Icons.settings, color: context.colors.textSecondary),
              onPressed: () => Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 240),
                  reverseTransitionDuration: const Duration(milliseconds: 240),
                  pageBuilder: (_, __, ___) =>
                      SettingsPage(username: widget.username, phone: widget.phone),
                  transitionsBuilder: (_, animation, __, child) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.fastOutSlowIn,
                    );
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    );
                  },
                ),
              ),
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

  // ---- 完成日历卡片（GitHub 风格：53 周 × 7 天方格，横向滚动） ----
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
            const SizedBox(height: 10),
            if (_contribLoading)
              const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
              )
            else if (_contribError)
              SizedBox(
                height: 90,
                child: Center(
                  child: Text('日历加载失败，请下拉重试', style: TextStyle(fontSize: 13, color: context.colors.textSecondary)),
                ),
              )
            else if (_contribMap.isEmpty)
              SizedBox(
                height: 90,
                child: Center(
                  child: Text('暂无记录，完成一局后开始统计', style: TextStyle(fontSize: 13, color: context.colors.textFaint)),
                ),
              )
            else
              _buildGithubGrid(dark),
          ],
        ),
      ),
    );
  }

  /// GitHub 风格：53 周 × 7 天方格，横向滚动，最右一格为今天
  Widget _buildGithubGrid(bool dark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 起点：今天往前 364 天，再对齐到周日（与 GitHub/安卓一致）
    var start = today.subtract(const Duration(days: 364));
    start = start.subtract(Duration(days: start.weekday % 7));

    const weeks = 53;
    const cell = 15.0;
    const gap = 2.0;
    const pitch = cell + gap;
    final total = _contribMap.values.fold<int>(0, (sum, c) => sum + c);

    // 首次进入滚到最右，展示当前月份（与 GitHub 一致）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_calScrolledToEnd && _calendarScroll.hasClients) {
        _calendarScroll.jumpTo(_calendarScroll.position.maxScrollExtent);
        _calScrolledToEnd = true;
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('近 1 年共 $total 局', style: TextStyle(fontSize: 11, color: context.colors.textFaint)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 星期竖轴（日 / 二 / 四 / 六），与格子逐行对齐
            Padding(
              padding: const EdgeInsets.only(top: 20, right: 6),
              child: Column(
                children: [
                  for (var r = 0; r < 7; r++)
                    Padding(
                      padding: EdgeInsets.only(bottom: r < 6 ? 3 : 0),
                      child: SizedBox(
                        width: 18,
                        height: 14,
                        child: Text(
                          _weekAxisLabel(r),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, height: 1.0, color: context.colors.textFaint),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false,
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.invertedStylus,
                  },
                ),
                child: Scrollbar(
                  controller: _calendarScroll,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  thumbVisibility: kIsWeb,
                  child: SingleChildScrollView(
                    controller: _calendarScroll,
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                            // 月份标签：按“每月 1 号所在列”显示，标签行与格子行严格等宽（Stack 定位，不占额外宽度）
                        SizedBox(
                          height: 16,
                          width: weeks * pitch - gap + 12,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              for (final e in _monthLabelCols(start, weeks).entries)
                                Positioned(
                                  left: e.key * pitch,
                                  child: Text(
                                    '${e.value}月',
                                    maxLines: 1,
                                    style: TextStyle(fontSize: 11, height: 1.0, color: context.colors.textFaint),
                                  ),
                                ),
                            ],
                          ),
                        ),const SizedBox(height: 4),
                        // 7 行（周日~周六）× 53 列，横向排列，行列间留 3dp 间距
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var w = 0; w < weeks; w++) ...[
                              Column(
                                children: [
                                  for (var row = 0; row < 7; row++)
                                    Padding(
                                      padding: EdgeInsets.only(bottom: row < 6 ? 3 : 0),
                                      child: _githubCell(start.add(Duration(days: w * 7 + row)), today, dark, cell),
                                    ),
                                ],
                              ),
                              if (w < weeks - 1) const SizedBox(width: gap),
                            
                            ],
                            const SizedBox(width: 12),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 星期竖轴标签：日 / 二 / 四 / 六（GitHub 风格，隔行显示）
  String _weekAxisLabel(int row) {
    switch (row) {
      case 0:
        return '日';
      case 2:
        return '二';
      case 4:
        return '四';
      case 6:
        return '六';
      default:
        return '';
    }
  }
  /// 计算“每月 1 号所在列”的月份标签（当前月如 9 月也能显示，与安卓一致）
  Map<int, int> _monthLabelCols(DateTime start, int weeks) {
    final map = <int, int>{};
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    var cursor = DateTime(start.year, start.month, 1);
    while (!cursor.isAfter(todayStart)) {
      final col = cursor.difference(start).inDays ~/ 7;
      if (col >= 0 && col < weeks) map[col] = cursor.month;
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return map;
  }  Widget _githubCell(DateTime day, DateTime today, bool dark, double cell) {
    if (day.isAfter(today)) {
      return SizedBox(width: cell, height: cell);
    }
    final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final count = _contribMap[key] ?? 0;
    return Container(
      width: cell,
      height: cell,
      decoration: BoxDecoration(
        color: _githubColor(count, dark),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// 与安卓一致的固定分级：0 / 1 / 2-3 / 4-6 / 7+
  Color _githubColor(int count, bool dark) {
    const emptyDark = Color(0xFF2D333B);
    const emptyLight = Color(0xFFEBEDF0);
    const levelsDark = [Color(0xFF0F5D30), Color(0xFF1B8A41), Color(0xFF2EA44F), Color(0xFF3FB950)];
    const levelsLight = [Color(0xFF9BE9A8), Color(0xFF40C463), Color(0xFF30A14E), Color(0xFF216E39)];
    if (count <= 0) return dark ? emptyDark : emptyLight;
    final levels = dark ? levelsDark : levelsLight;
    if (count == 1) return levels[0];
    if (count <= 3) return levels[1];
    if (count <= 6) return levels[2];
    return levels[3];
  }

  Widget _legend(bool dark) {
    const emptyDark = Color(0xFF2D333B);
    const emptyLight = Color(0xFFEBEDF0);
    const levelsDark = [Color(0xFF0F5D30), Color(0xFF1B8A41), Color(0xFF2EA44F), Color(0xFF3FB950)];
    const levelsLight = [Color(0xFF9BE9A8), Color(0xFF40C463), Color(0xFF30A14E), Color(0xFF216E39)];
    final empty = dark ? emptyDark : emptyLight;
    final levels = dark ? levelsDark : levelsLight;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('少', style: TextStyle(fontSize: 10, height: 1.0, color: context.colors.textFaint)),
        const SizedBox(width: 3),
        for (final c in [empty, ...levels]) ...[
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 2),
        ],
        const SizedBox(width: 1),
        Text('多', style: TextStyle(fontSize: 10, height: 1.0, color: context.colors.textFaint)),
      ],
    );
  }
}
