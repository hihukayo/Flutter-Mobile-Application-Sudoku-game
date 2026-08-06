# 🧩 数独 Sudoku

Flutter 数独移动应用，支持用户登录注册、经典/杀手数独、云存档、积分排行榜、个人中心等功能。

## ✨ 功能

- **用户系统**：注册 / 登录（后端 MySQL 存储，密码 SHA256 加密）
- **数独游戏**：
  - 3×3 经典九宫格 & 4×4 十六进制数独
  - **杀手数独**（3×3）：虚线框（Cage）+ 和值模式，支持异形笼子
  - **难度自动随机**：遵循正态分布，避免连续重复
  - 计时器、暂停 / 继续（暂停时自动存档）
  - 笔记模式（候选数字标记）
  - 撤销 / 重做（支持笔记操作）
  - 错误计数（3×3 限 3 次，4×4 限 6 次）
  - **云存档**：保存/读档游戏进度（手动 + 自动），未游玩的新盘不会覆盖旧存档
  - 自动求解、重置
- **积分系统**：每局游戏根据难度、用时、错误数计算积分
  - 公式：`基础分 × 难度系数 × 时间加成 × 错误惩罚`
  - 排行榜按总积分排名，显示胜率
- **音效与震动**：按钮震动 + 原生音效（正弦波/MP3）
- **自动收起键盘**：填满格子或游戏结束时自动隐藏
- **按键防抖**：300ms 消抖，防止误触
- **排行榜**：按总积分排名，显示胜率，用户名旁高亮「我」
- **个人中心**：总局数/总积分/胜率、修改用户名/密码/手机号、注销账号、头像（服务器同步，换设备可恢复）

## 🛠 技术栈

<div align="center">

<table align="center" width="100%">
  <tr>
    <th>层级</th>
    <th>技术</th>
  </tr>
  <tr>
    <td>前端</td>
    <td>Flutter (Dart)</td>
  </tr>
  <tr>
    <td>后端</td>
    <td>Go（<a href="https://github.com/hihukayo/go-sudoku-backend.git">go-sudoku-backend</a>）</td>
  </tr>
  <tr>
    <td>数据库</td>
    <td>MySQL</td>
  </tr>
  <tr>
    <td>音效</td>
    <td>Android AudioTrack / MediaPlayer / audioplayers (Web)</td>
  </tr>
</table>

</div>

---

## 🚀 快速启动

### 环境要求

<div align="center">

<table align="center" width="100%">
  <tr>
    <th>工具</th>
    <th>版本要求</th>
  </tr>
  <tr>
    <td>Flutter</td>
    <td>^3.12</td>
  </tr>
  <tr>
    <td>Dart SDK</td>
    <td>^3.12</td>
  </tr>
  <tr>
    <td>MySQL</td>
    <td>8.0+</td>
  </tr>
  <tr>
    <td>Go</td>
    <td>1.22+（编译 go-sudoku-backend 后端）</td>
  </tr>
</table>

</div>

### 一键启动

在 PowerShell 中运行 `run.ps1` 或直接双击 `run.ps1` 执行，菜单如下：
```
  [1]  Install to Phone
  [2]  Launch Web App (auto-start backend)
  [3]  Start Backend Only
  [4]  Stop Backend
  [5]  Exit
```

- **选 `1`** → 检测手机 → ADB 端口转发 → 安装运行
- **选 `2`** → 自动构建前端 + 启动后端 → 浏览器打开 http://127.0.0.1:8080
- **选 `3`** → 单独启动后端
- **选 `4`** → 停止后端

> 如果遇到执行策略限制，先运行 `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`。
> 注意：后端已迁移到 Go（go-sudoku-backend），`run.ps1` 中「启动后端」相关选项对应旧 Dart 后端，仅作历史保留。

### 手动启动

**数据库：**
```sql
CREATE DATABASE IF NOT EXISTS PuzzleGame;
USE PuzzleGame;

-- 用户表
CREATE TABLE IF NOT EXISTS users (
  username VARCHAR(255) NOT NULL,
  phone VARCHAR(255) NOT NULL,
  password VARCHAR(255) NOT NULL,
  PRIMARY KEY (username, phone)
);

-- 游戏存档（每用户只保留最新一个）
CREATE TABLE IF NOT EXISTS saves (
  username VARCHAR(255) NOT NULL,
  board_size INT DEFAULT 3,
  cells JSON,
  notes JSON,
  solution JSON,
  given JSON,
  seconds INT DEFAULT 0,
  errors INT DEFAULT 0,
  is_killer TINYINT DEFAULT 0,
  killer_difficulty VARCHAR(50) DEFAULT '',
  cages JSON,
  saved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (username)
);

-- 用户统计
CREATE TABLE IF NOT EXISTS user_stats (
  username VARCHAR(255) PRIMARY KEY,
  total_games INT DEFAULT 0,
  completed_games INT DEFAULT 0,
  total_score INT DEFAULT 0,
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 游戏记录
CREATE TABLE IF NOT EXISTS game_records (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(255) NOT NULL,
  won TINYINT DEFAULT 0,
  game_mode VARCHAR(50) DEFAULT '',
  board_size INT DEFAULT 3,
  score INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_username (username),
  INDEX idx_game_mode (game_mode),
  INDEX idx_board_size (board_size)
);

-- 用户头像（每用户一张，base64 存储）
CREATE TABLE IF NOT EXISTS avatars (
  username VARCHAR(255) PRIMARY KEY,
  avatar MEDIUMTEXT,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

**后端：**
```bash
git clone https://github.com/hihukayo/go-sudoku-backend.git
cd go-sudoku-backend
go build -o server.exe .
.\server.exe
# 输出：MySQL 连接成功 → 服务器已启动: http://localhost:8080
```

**前端依赖：**
```bash
flutter pub get
```

**Web 浏览器：**
```bash
flutter build web --release
npx serve build/web
# 打开 npx serve 提示的地址（默认 http://localhost:3000）
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
> 同一 WiFi 方式：手机与电脑连同一热点，电脑运行 `ipconfig` 查看局域网 IP（如 `192.168.43.74`），App 设置 → 服务器地址 填写 `192.168.43.74:8080` 即可，无需 USB，也无需 `adb reverse`。

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

## 📡 API 接口

所有接口位于 `http://127.0.0.1:8080/api/`，请求/响应均为 JSON。

### 用户系统

<div align="center">

<table align="center" width="100%">
  <tr>
    <th>方法</th>
    <th>路径</th>
    <th>说明</th>
  </tr>
  <tr>
    <td>POST</td>
    <td><code>/api/register</code></td>
    <td>注册 <code>{username, phone, password}</code></td>
  </tr>
  <tr>
    <td>POST</td>
    <td><code>/api/login</code></td>
    <td>登录 <code>{account, password}</code></td>
  </tr>
  <tr>
    <td>PUT</td>
    <td><code>/api/user/update-username</code></td>
    <td>修改用户名</td>
  </tr>
  <tr>
    <td>PUT</td>
    <td><code>/api/user/update-password</code></td>
    <td>修改密码</td>
  </tr>
  <tr>
    <td>PUT</td>
    <td><code>/api/user/update-phone</code></td>
    <td>修改手机号</td>
  </tr>
  <tr>
    <td>DELETE</td>
    <td><code>/api/user/delete</code></td>
    <td>注销账号</td>
  </tr>
</table>

</div>

### 存档系统

<div align="center">

<table align="center" width="100%">
  <tr>
    <th>方法</th>
    <th>路径</th>
    <th>说明</th>
  </tr>
  <tr>
    <td>POST</td>
    <td><code>/api/save</code></td>
    <td>保存游戏进度</td>
  </tr>
  <tr>
    <td>GET</td>
    <td><code>/api/load?username=xxx</code></td>
    <td>加载最近存档</td>
  </tr>
</table>

</div>

### 排行榜

<div align="center">

<table align="center" width="100%">
  <tr>
    <th>方法</th>
    <th>路径</th>
    <th>说明</th>
  </tr>
  <tr>
    <td>POST</td>
    <td><code>/api/rank/submit</code></td>
    <td>提交游戏结果（含积分）</td>
  </tr>
  <tr>
    <td>GET</td>
    <td><code>/api/rank/list</code></td>
    <td>排行榜（总积分降序）</td>
  </tr>
  <tr>
    <td>GET</td>
    <td><code>/api/rank/user?username=xxx</code></td>
    <td>个人统计</td>
  </tr>
</table>

</div>

### 头像

<div align="center">

<table align="center" width="100%">
  <tr>
    <th>方法</th>
    <th>路径</th>
    <th>说明</th>
  </tr>
  <tr>
    <td>PUT</td>
    <td><code>/api/avatar</code></td>
    <td>上传头像（base64，服务器持久化）</td>
  </tr>
  <tr>
    <td>GET</td>
    <td><code>/api/avatar?username=xxx</code></td>
    <td>获取头像（base64）</td>
  </tr>
</table>

</div>

---

## 💾 存档系统

- **自动存档**：暂停游戏时自动保存进度
- **手动存档/读档**：游戏页面底部「存档」「读档」按钮
- **续玩**：进入游戏时自动检测存档，弹窗询问是否继续
- **云端存储**：存档保存在服务器 MySQL，换设备可恢复
- **连接配置**：服务器地址可在设置中填写，请求 8 秒超时，超时后提示并可重试

## 🏆 积分系统

每局游戏结束后自动计算积分：

```
最终得分 = 基础分 × 难度系数 × 时间加成 × 错误惩罚
```

**基础分（含模式系数）：**

<div align="center">

<table align="center" width="100%">
  <tr>
    <th>模式</th>
    <th>基础分</th>
  </tr>
  <tr>
    <td>9×9 常规</td>
    <td>100</td>
  </tr>
  <tr>
    <td>9×9 杀手</td>
    <td>200</td>
  </tr>
  <tr>
    <td>16×16 常规</td>
    <td>250</td>
  </tr>
</table>

</div>

**难度系数：**

<div align="center">

<table align="center" width="100%">
  <tr>
    <th>难度</th>
    <th>系数</th>
  </tr>
  <tr>
    <td>简单 / 入门</td>
    <td>1.0</td>
  </tr>
  <tr>
    <td>中等</td>
    <td>1.5</td>
  </tr>
  <tr>
    <td>困难 / 极简</td>
    <td>2.0</td>
  </tr>
</table>

</div>

**时间加成：**
```
(标准耗时 / 实际耗时) × 0.5 + 0.5    取值 [0.5, 5.0]
```

**错误惩罚：**
```
(最大允许错误 - 实际错误) / 最大允许错误
```
3×3 模式最大 3 次错误，4×4 模式最大 6 次错误。

---

## 🎮 游戏操作

### 触屏
- **点击格子** → 选中 + 弹出数字键盘
- **底部按钮**：新局 / 完成 / 求解 / 撤销 / 重置 / 重做 / 存档 / 读档
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

<div align="center">

<table align="center" width="100%">
  <tr>
    <th>难度</th>
    <th>出现概率</th>
    <th>2格</th>
    <th>3格</th>
    <th>4格</th>
    <th>5格</th>
  </tr>
  <tr>
    <td>🟢 入门</td>
    <td>~25%</td>
    <td>60%</td>
    <td>35%</td>
    <td>5%</td>
    <td>0%</td>
  </tr>
  <tr>
    <td>🔵 中等</td>
    <td>~50%</td>
    <td>40%</td>
    <td>35%</td>
    <td>15%</td>
    <td>10%</td>
  </tr>
  <tr>
    <td>🔴 困难</td>
    <td>~25%</td>
    <td>30%</td>
    <td>30%</td>
    <td>20%</td>
    <td>20%</td>
  </tr>
</table>

</div>

### 笼子形状
支持 **L 型**、**阶梯型** 等异形笼子，从笼子任意边界扩展生成。

---

## 🔊 音效与反馈

<div align="center">

<table align="center" width="100%">
  <tr>
    <th>操作</th>
    <th>Android</th>
    <th>Web</th>
  </tr>
  <tr>
    <td>按钮点击</td>
    <td>80ms 震动 + 1200Hz 正弦波</td>
    <td><code>click.wav</code></td>
  </tr>
  <tr>
    <td>填入/删除数字</td>
    <td>震动 + <code>Placement.mp3</code></td>
    <td><code>Placement.mp3</code></td>
  </tr>
  <tr>
    <td>完成游戏</td>
    <td>震动 + 上扬滑音 600→1200Hz</td>
    <td><code>success.wav</code></td>
  </tr>
  <tr>
    <td>错误满 3 次</td>
    <td>震动 + <code>failed.mp3</code></td>
    <td><code>failed.mp3</code></td>
  </tr>
  <tr>
    <td>撤销 / 重做</td>
    <td>震动 + 按钮点击音</td>
    <td><code>click.wav</code></td>
  </tr>
</table>

</div>

- 震动通过 Android Vibrator 原生接口（需 `VIBRATE` 权限）
- 所有操作带 300ms 防抖
- 填满格子或游戏结束自动收起键盘

---

## ⚙️ 常规难度说明

每局随机选取难度，正态分布：

### 3×3（81 格）

<div align="center">

<table align="center" width="100%">
  <tr>
    <th>难度</th>
    <th>提示数</th>
    <th>出现概率</th>
    <th>说明</th>
  </tr>
  <tr>
    <td>🟥 极简</td>
    <td>17-22</td>
    <td>~10%</td>
    <td>需高级技巧</td>
  </tr>
  <tr>
    <td>🟧 困难</td>
    <td>23-28</td>
    <td>~25%</td>
    <td>适合有经验玩家</td>
  </tr>
  <tr>
    <td>🟦 中等</td>
    <td>29-32</td>
    <td>~40%</td>
    <td>常见数独水平</td>
  </tr>
  <tr>
    <td>🟩 简单</td>
    <td>33-36</td>
    <td>~25%</td>
    <td>新手入门</td>
  </tr>
</table>

</div>

### 4×4（256 格）

<div align="center">

<table align="center" width="100%">
  <tr>
    <th>难度</th>
    <th>提示数</th>
    <th>出现概率</th>
  </tr>
  <tr>
    <td>🟧 困难</td>
    <td>70-80</td>
    <td>~25%</td>
  </tr>
  <tr>
    <td>🟦 中等</td>
    <td>92-105</td>
    <td>~50%</td>
  </tr>
  <tr>
    <td>🟩 简单</td>
    <td>110-130</td>
    <td>~25%</td>
  </tr>
</table>

</div>

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
│   │   ├── game_page.dart           # 游戏核心（含杀手数独、存档/读档）
│   │   ├── rank_page.dart           # 排行榜（积分 + 胜率）
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
│   └── bin/server.dart              # 旧 Dart 后端（已废弃，改用 go-sudoku-backend）
├── web/                             # Web 入口
└── run.ps1                           # 一键启动器（手机/网页）
```

---

## 📄 License

本项目基于 GNU General Public License v3.0 (GPLv3) 开源 — 详见 [LICENSE](LICENSE) 文件。
