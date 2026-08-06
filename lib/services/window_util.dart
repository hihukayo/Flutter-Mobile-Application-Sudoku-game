import 'package:flutter/services.dart';

const _channel = MethodChannel('com.example.puzzle_game/window');

/// 设置软键盘模式：
/// resize  = 键盘弹出时压缩窗口（登录/注册/设置等输入页面）
/// nothing = 键盘悬浮不压缩窗口（游戏页，操作按键不上推）
Future<void> setSoftInputMode(String mode) async {
  try {
    await _channel.invokeMethod('set_soft_input_mode', {'mode': mode});
  } catch (_) {
    // 非 Android 平台无此通道，忽略
  }
}