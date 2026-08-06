import 'package:flutter/widgets.dart';

/// 密码输入控制器：仅视觉打码（圆点遮罩），真实文本正常流转。
/// 等价于安卓原生 PasswordVisualTransformation：
/// 输入类型保持普通文本，避免部分输入法（如百度输入法）
/// 遇到密码输入类型时收起键盘。
class MaskedTextController extends TextEditingController {
  MaskedTextController({super.text, this.reveal = false});

  /// 是否明文显示（用于“显示密码”开关）
  bool reveal;

  static const _dot = '\u2022';

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = reveal ? super.text : _dot * super.text.length;
    return TextSpan(style: style, text: text);
  }

  /// 业务逻辑使用的真实密码文本
  String get realText => super.text;

  /// 切换明文/遮罩后刷新显示
  void refresh() => notifyListeners();
}
