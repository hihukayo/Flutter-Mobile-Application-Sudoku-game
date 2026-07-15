# 🧩 数独 Sudoku

Flutter 数独移动应用，支持用户登录注册、经典/杀手数独、个人中心等功能。

## ✨ 功能

- **用户系统**：注册 / 登录（后端 MySQL 存储，密码 SHA256 加密）
- **数独游戏**：
  - 3×3 经典九宫格 & 4×4 十六进制数独
  - **杀手数独**（3×3）：虚线框（Cage）+ 和值模式，支持异形笼子
  - **难度自动随机**：遵循正态分布，避免连续重复
  - 计时器、暂停 / 继续
  - 笔记模式（候选数字标记）
  - 撤销 / 重做（支持笔记操作）
  - 错误计数（3×3 限 3 次，4×4 限 6 次）
  - 自动求解、重置
- **音效与震动**：按钮震动 + 原生音效（正弦波/MP3）
- **自动收起键盘**：填满格子或游戏结束时自动隐藏
- **按键防抖**：300ms 消抖，防止误触
- **排行榜**：按分数排名
- **个人中心**：修改用户名 / 密码 / 手机号、注销账号、头像

## 🛠 技术栈

| 层级 | 技术 |
| --- | --- |
| 前端 | Flutter (Dart) |
| 后端 | Dart shelf + shelf_router |
| 数据库 | MySQL |
| 音效 | Android AudioTrack / MediaPlayer / audioplayers (Web) |

---

## 🚀 快速启动

### 环境要求

| 工具 | 版本要求 |
| --- | --- |
| Flutter | ^3.12 |
| Dart SDK | ^3.12 |
| MySQL | 8.0+ |

### 一键启动

提供两个启动脚本：

| 脚本 | 位置 | 说明 |
|------|------|------|
| `run.bat` | `sudoku/` | 项目目录内运行 |
| `run.bat` | `application/` | 外层目录运行（自动切到 `sudoku/`） |

双击运行，菜单如下：

```
  [1]  Install to Phone
  [2]  Launch Web App (auto-start backend)
  [3]  Start Backend Only
  [4]  Stop Backend
  [5]  Exit
```

- **选 `1`** → 检测手机 → ADB 端口转发 → 安装运行
- **选 `2`** → 自动启动后端（8080）+ 打开 Web 前端（8081），退出时可选择关闭后端
- **选 `3`** → 单独启动后端
- **选 `4`** → 停止后端

> 确保 Flutter SDK 已加入 `PATH`（如 `D:\Flutter\bin`），否则取消 `run.bat` 中 `set PATH=` 的注释。

### 手动启动

**数据库：**
```sql
CREATE DATABASE IF NOT EXISTS PuzzleGame;
USE PuzzleGame;
CREATE TABLE IF NOT EXISTS users (
  username VARCHAR(255) NOT NULL,
  phone VARCHAR(255) NOT NULL,
  password VARCHAR(255) NOT NULL,
  PRIMARY KEY (username, phone)
);
```

**后端：**
```bash
cd server
dart pub get
dart run bin/server.dart
# 输出：MySQL 连接成功 → http://localhost:8080
```

**前端依赖：**
```bash
flutter pub get
```

**Web 浏览器：**
```bash
flutter run -d edge --web-port 8081
# 或 flutter run -d chrome
```

**物理手机（Android）：**
```bash
# 1. 手机开启 USB 调试并连接电脑
# 2. ADB 端口转发
adb reverse tcp:8080 tcp:8080
# 3. 安装
flutter run -d <device_id>
```

---

## 📱 运行到手机

1. 手机开启 **开发者选项** 和 **USB 调试**
2. USB 连接电脑，运行 `flutter devices` 确认设备已识别
3. ADB 端口转发（手机 `localhost:8080` → 电脑后端）：
   ```bash
   adb reverse tcp:8080 tcp:8080
   ```
4. 安装：`flutter run -d <设备ID>`

> 每次重新插拔手机需重新执行 `adb reverse`。

---

## 📦 构建

```bash
# Web 构建
flutter build web
npx serve build/web

# Android APK
flutter build apk --debug    # 调试版
flutter build apk --release  # 发布版
# APK 路径：build/app/outputs/flutter-apk/app-release.apk
```

---

## 🎮 游戏操作

### 触屏
- **点击格子** → 选中 + 弹出数字键盘
- **底部按钮**：新局 / 完成 / 求解 / 撤销 / 重置 / 重做
- **右上角图标**：切换笔记模式

### 键盘（Web / 外接键盘）
- **1-9**：填入数字（4×4 模式支持 A-G 对应 10-16）
- **退格 / Delete**：清除当前格
- **方向键**：移动选中格

---

## 🎯 杀手数独

在标准数独规则上增加 **虚线框（Cage）** 和 **和值** 约束。

### 规则
1. 每行、每列、每宫数字 1-9 不重复
2. 每个虚线框内数字之和必须等于右下角的和值
3. **试错机制**：不逐格对照答案，允许试错
4. 错误满 3 次游戏结束

### 判错逻辑
- **行列宫重复** → 格子变红，错误 +1
- **笼子和值超限** → 笼子边框变红，格子变红，错误 +1
- **正常填数** → 不变红（即使与答案不一致）
- **完成按钮** → 统一校验最终答案

### 难度分布（正态随机）

| 难度 | 出现概率 | 2格 | 3格 | 4格 | 5格 |
| --- | --- | --- | --- | --- | --- |
| 🟢 入门 | ~25% | 60% | 35% | 5% | 0% |
| 🔵 中等 | ~50% | 40% | 35% | 15% | 10% |
| 🔴 困难 | ~25% | 30% | 30% | 20% | 20% |

### 笼子形状
支持 **L 型**、**阶梯型** 等异形笼子，从笼子任意边界扩展生成。

---

## 🔊 音效与反馈

| 操作 | Android | Web |
|------|---------|-----|
| 按钮点击 | 80ms 震动 + 1200Hz 正弦波 | `click.wav` |
| 填入/删除数字 | 震动 + `Placement.mp3` | `Placement.mp3` |
| 完成游戏 | 震动 + 上扬滑音 600→1200Hz | `success.wav` |
| 错误满 3 次 | 震动 + `failed.mp3` | `failed.mp3` |
| 撤销 / 重做 | 震动 + 按钮点击音 | `click.wav` |

- 震动通过 Android Vibrator 原生接口（需 `VIBRATE` 权限）
- 所有操作带 300ms 防抖
- 填满格子或游戏结束自动收起键盘

---

## ⚙️ 常规难度说明

每局随机选取难度，正态分布：

### 3×3（81 格）

| 难度 | 提示数 | 出现概率 | 说明 |
| --- | --- | --- | --- |
| 🟥 极简 | 17-22 | ~10% | 需高级技巧 |
| 🟧 困难 | 23-28 | ~25% | 适合有经验玩家 |
| 🟦 中等 | 29-32 | ~40% | 常见数独水平 |
| 🟩 简单 | 33-36 | ~25% | 新手入门 |

### 4×4（256 格）

| 难度 | 提示数 | 出现概率 |
| --- | --- | --- |
| 🟧 困难 | 70-80 | ~25% |
| 🟦 中等 | 92-105 | ~50% |
| 🟩 简单 | 110-130 | ~25% |

---

## 📁 项目结构

```
sudoku/
├── lib/
│   ├── main.dart                    # 入口 + 启动画面
│   ├── models/
│   │   ├── sudoku_game.dart         # 数据模型（含 Cage）
│   │   └── sudoku_generator.dart    # 生成器 + 求解器
│   ├── screens/
│   │   ├── login_page.dart          # 登录
│   │   ├── register_page.dart       # 注册
│   │   ├── home_page.dart           # 首页（底部导航）
│   │   ├── game_page.dart           # 游戏核心（含杀手数独）
│   │   ├── rank_page.dart           # 排行榜
│   │   ├── profile_page.dart        # 个人中心
│   │   └── settings_page.dart       # 设置
│   ├── widgets/
│   │   └── sudoku_board.dart        # 棋盘组件（含 Cage 绘制）
│   └── services/
│       └── api_service.dart         # API 请求封装
├── assets/
│   └── audio/
│       ├── click.wav                # 按钮点击（Web）
│       ├── success.wav              # 游戏完成（Web）
│       ├── Placement.mp3            # 填入/删除数字
│       └── failed.mp3               # 游戏失败
├── server/
│   └── bin/server.dart              # 后端服务（shelf）
├── web/                             # Web 入口
└──run.bat                           # 一键启动器（手机/网页）
```

---

## 📄 License

本项目基于 GNU General Public License v3.0 (GPLv3) 开源 — 详见 [LICENSE](LICENSE) 文件。
