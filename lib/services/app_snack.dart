import 'package:flutter/material.dart';

/// 应用根级 ScaffoldMessenger 的 Key，用于在异步回调中安全地弹出提示，
/// 避免依赖页面 context（页面可能已被销毁/正在切换，导致框架断言红屏）。
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// 在应用根级显示浮动提示条（自动清除旧提示，避免堆积）
void showAppSnack(String msg) {
  appMessengerKey.currentState
    ?..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
}