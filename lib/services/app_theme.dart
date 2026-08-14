import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---- 全局基准色（浅色模式观感与原版一致）----
const kBlue = Color(0xFF0B4CFF);
const kRed = Color(0xFFE53935);
const kDarkSlate = Color(0xFF455A64);
const kInk = Color(0xFF1A1A2E);
const kSelectedBg = Color(0xFFBBDEFB);
const kHighlightBg = Color(0xFFF0F4F8);
const kGreen = Color(0xFF2E7D32);
const kGreyBlue = Color(0xFF78909C);
const kLightGrey = Color(0xFFE0E0E0);

/// 语义色：界面统一从这里取色，随深色模式自动切换
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.divider,
    required this.inputBg,
    required this.selectedBg,
    required this.highlightBg,
    required this.boardBg,
    required this.boardLine,
    required this.boardBorder,
    required this.chipBg,
    required this.disabledText,
    required this.userInput,
    required this.noteText,
    required this.primary,
    required this.onPrimary,
    required this.danger,
  });

  final Color background; // 页面背景
  final Color surface; // 卡片/面板背景
  final Color surfaceAlt; // 次级面板背景
  final Color textPrimary; // 主文字
  final Color textSecondary; // 次要文字
  final Color textFaint; // 更淡文字
  final Color divider; // 分割线
  final Color inputBg; // 输入框/浅底
  final Color selectedBg; // 选中高亮（浅蓝）
  final Color highlightBg; // 棋盘高亮格
  final Color boardBg; // 棋盘背景
  final Color boardLine; // 棋盘细线
  final Color boardBorder; // 棋盘外框/粗分隔线
  final Color chipBg; // 禁用/浅灰底
  final Color disabledText; // 禁用文字
  final Color userInput; // 玩家填写的数字
  final Color noteText; // 笔记/强调蓝
  final Color primary; // 主按钮底色
  final Color onPrimary; // 主按钮文字
  final Color danger; // 危险操作按钮

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? textFaint,
    Color? divider,
    Color? inputBg,
    Color? selectedBg,
    Color? highlightBg,
    Color? boardBg,
    Color? boardLine,
    Color? boardBorder,
    Color? chipBg,
    Color? disabledText,
    Color? userInput,
    Color? noteText,
    Color? primary,
    Color? onPrimary,
    Color? danger,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textFaint: textFaint ?? this.textFaint,
      divider: divider ?? this.divider,
      inputBg: inputBg ?? this.inputBg,
      selectedBg: selectedBg ?? this.selectedBg,
      highlightBg: highlightBg ?? this.highlightBg,
      boardBg: boardBg ?? this.boardBg,
      boardLine: boardLine ?? this.boardLine,
      boardBorder: boardBorder ?? this.boardBorder,
      chipBg: chipBg ?? this.chipBg,
      disabledText: disabledText ?? this.disabledText,
      userInput: userInput ?? this.userInput,
      noteText: noteText ?? this.noteText,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      inputBg: Color.lerp(inputBg, other.inputBg, t)!,
      selectedBg: Color.lerp(selectedBg, other.selectedBg, t)!,
      highlightBg: Color.lerp(highlightBg, other.highlightBg, t)!,
      boardBg: Color.lerp(boardBg, other.boardBg, t)!,
      boardLine: Color.lerp(boardLine, other.boardLine, t)!,
      boardBorder: Color.lerp(boardBorder, other.boardBorder, t)!,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      disabledText: Color.lerp(disabledText, other.disabledText, t)!,
      userInput: Color.lerp(userInput, other.userInput, t)!,
      noteText: Color.lerp(noteText, other.noteText, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

const lightAppColors = AppColors(
  background: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFFFF),
  surfaceAlt: Color(0xFFF5F7FA),
  textPrimary: kInk,
  textSecondary: kDarkSlate,
  textFaint: kGreyBlue,
  divider: kLightGrey,
  inputBg: Color(0xFFF5F7FA),
  selectedBg: kSelectedBg,
  highlightBg: Color(0xFFE7EFFA), // 浅色模式行列/宫高亮：柔和淡蓝底，与细格线和谐
  boardBg: Color(0xFFFFFFFF),
  boardLine: kLightGrey,
  boardBorder: kDarkSlate,
  chipBg: Color(0xFFF1F1F1),
  disabledText: Color(0xFFC0C0C0),
  userInput: kGreen,
  noteText: kBlue,
  primary: kBlue,
  onPrimary: Color(0xFFFFFFFF),
  danger: Color(0xFFEF5350),
);

/// 深色模式：蓝灰底，与安卓端观感区分开
const darkAppColors = AppColors(
  background: Color(0xFF0F141A),
  surface: Color(0xFF161D26),
  surfaceAlt: Color(0xFF1C242F),
  textPrimary: Color(0xFFE7ECF3),
  textSecondary: Color(0xFF9AA8BA),
  textFaint: Color(0xFF6E7B8C),
  divider: Color(0xFF232C37),
  inputBg: Color(0xFF1A222C),
  selectedBg: Color(0xFF20304A),
  highlightBg: Color(0xFF232A3A), // 深色模式高亮：比底色略亮、不泛白
  boardBg: Color(0xFF131A22),
  boardLine: Color(0xFF3A4654),
  boardBorder: Color(0xFF5E6D7E),
  chipBg: Color(0xFF202832),
  disabledText: Color(0xFF59636F),
  userInput: Color(0xFF7FC9A2),
  noteText: Color(0xFF8FB8F2),
  primary: Color(0xFF3D6BD9),
  onPrimary: Color(0xFFEEF2FA),
  danger: Color(0xFFD2706E),
);

/// 深色模式偏好：light / dark / system，设置页可切换，启动时加载
final ValueNotifier<String> themeModeNotifier = ValueNotifier<String>('system');

Future<void> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final mode = prefs.getString('theme_mode') ?? 'system';
  themeModeNotifier.value = mode;
}

Future<void> setThemeMode(String mode) async {
  themeModeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('theme_mode', mode);
}

/// 页面取色入口：context.colors
extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? lightAppColors;
}