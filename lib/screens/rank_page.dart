import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RankPage extends StatefulWidget {
  final String username;

  const RankPage({super.key, required this.username});

  @override
  State<RankPage> createState() => RankPageState();
}

class RankPageState extends State<RankPage> {
  List<Map<String, dynamic>> _rankList = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final res = await ApiService.getRankList();
      if (!mounted) return;
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _rankList = (res['data'] as List).cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        setState(() {
          _error = res['message'] ?? '加载失败';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '网络错误，请稍后重试';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部留出状态栏空间
        SizedBox(height: MediaQuery.of(context).padding.top + 4),
        // 标题栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFF5F7FA),
          child: Row(
            children: [
              const SizedBox(width: 4),
              const SizedBox(width: 36, child: Center(child: Text('排名', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF78909C))))),
              const SizedBox(width: 4),
              const Expanded(child: Text('玩家', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF78909C)))),
              SizedBox(width: 72, child: Text('积分', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF455A64)))),
              const SizedBox(width: 64, child: Text('胜率', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF78909C)))),
            ],
          ),
        ),
        const Divider(height: 1),
        // 排行榜内容
        Expanded(child: _buildRankContent()),
      ],
    );
  }

  Widget _buildRankContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(_error, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_rankList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('暂无排行数据', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
            const SizedBox(height: 4),
            Text('完成一局游戏后数据将自动记录', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _rankList.length,
        itemBuilder: (_, index) {
          final item = _rankList[index];
          final rank = index + 1;
          final isMe = item['username'] == widget.username;
          return _buildRankItem(rank, item, isMe);
        },
      ),
    );
  }

  String _formatScore(int s) {
    if (s >= 1000000) return '${(s / 1000000).toStringAsFixed(1)}m';
    if (s >= 1000) return '${(s / 1000).toStringAsFixed(1)}k';
    return '$s';
  }

  Widget _buildRankItem(int rank, Map<String, dynamic> item, bool isMe) {
    final totalScore = (item['totalScore'] as num?)?.toInt() ?? 0;
    final winRate = (item['winRate'] as num?)?.toDouble() ?? 0.0;
    final username = item['username'] ?? '';

    // 前三名奖牌
    Widget rankWidget;
    if (rank == 1) {
      rankWidget = const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 26);
    } else if (rank == 2) {
      rankWidget = const Icon(Icons.emoji_events, color: Color(0xFFC0C0C0), size: 26);
    } else if (rank == 3) {
      rankWidget = const Icon(Icons.emoji_events, color: Color(0xFFCD7F32), size: 26);
    } else {
      rankWidget = Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF0B4CFF) : Colors.grey[200],
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          '$rank',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isMe ? Colors.white : const Color(0xFF455A64),
          ),
        ),
      );
    }

    // 胜率颜色
    Color winRateColor;
    if (winRate >= 70) {
      winRateColor = const Color(0xFF2E7D32);
    } else if (winRate >= 40) {
      winRateColor = const Color(0xFF0B4CFF);
    } else if (winRate > 0) {
      winRateColor = const Color(0xFFE65100);
    } else {
      winRateColor = Colors.grey[500]!;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFF0F4FF) : null,
        borderRadius: BorderRadius.circular(8),
        border: isMe ? Border.all(color: const Color(0xFF0B4CFF).withValues(alpha: 0.3)) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            const SizedBox(width: 4),
            SizedBox(width: 36, child: Center(child: rankWidget)),
            const SizedBox(width: 4),
            Expanded(
              child: Row(
                children: [
                  Text(
                    username,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isMe ? const Color(0xFF0B4CFF) : Colors.black87,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    const Text('我', style: TextStyle(fontSize: 12, color: Color(0xFF0B4CFF), fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: 72,
              child: Text(
                _formatScore(totalScore),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF455A64)),
              ),
            ),
            SizedBox(
              width: 64,
              child: Text(
                '${winRate.toStringAsFixed(1)}%',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: winRateColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
