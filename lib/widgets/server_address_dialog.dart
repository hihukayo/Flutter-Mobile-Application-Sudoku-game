import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/app_theme.dart';

/// 服务器地址设置对话框（登录/注册前也可使用）
Future<bool> showServerAddressDialog(BuildContext context) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => const _ServerAddressDialog(),
  );
  if (result == null) return false;
  await ApiService.setServerAddress(result);
  return true;
}

/// 对话框内容由 StatefulWidget 自持输入控制器，
/// 控制器随对话框自身的生命周期销毁，避免路由关闭动画期间的竞态问题。
class _ServerAddressDialog extends StatefulWidget {
  const _ServerAddressDialog();

  @override
  State<_ServerAddressDialog> createState() => _ServerAddressDialogState();
}

class _ServerAddressDialogState extends State<_ServerAddressDialog> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ApiService.currentAddress);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.dns_outlined, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          const Text(
            '服务器地址',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '留空则自动连接（USB / 模拟器）',
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: '服务器地址',
              hintText: '例如 192.168.1.100:8080',
              prefixIcon: const Icon(Icons.dns_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
    );
  }
}