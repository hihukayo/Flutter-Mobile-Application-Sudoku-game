# 🧩 数独 Sudoku

> Flutter 数独移动应用：登录注册、经典 / 算数数独、云存档、头像、积分排行榜。前端使用 Flutter，后端使用 Go（[go-sudoku-backend](https://github.com/hihukayo/go-sudoku-backend.git)）+ MySQL。

## ✨ 功能特性

- **用户系统**：注册 / 登录 / 注销，修改用户名 / 手机号 / 密码
- **个人头像**：相册选图，服务器持久化存储，换设备可恢复
- **数独游戏**
  - 3×3 经典九宫格 & 4×4 十六进制数独
  - 算数数独（3×3）：笼子（Cage）+ 运算符（+ - × ÷），支持异形笼子
  - 难度随机（正态分布），避免连续重复
  - 计时器、暂停 / 继续（暂停自动存档）、笔记模式、撤销 / 重做
  - 错误计数（3×3 限 3 次，4×4 限 6 次），错误次数不受撤销 / 重做影响
- **云存档**：手动保存 / 加载 + 自动存档，未游玩的新盘不会覆盖旧存档；读档后即视为已玩过，暂停 / 退出自动保存，计时回溯到存档时刻
- **排行榜**：按总积分排名，显示胜率，用户名旁高亮「我」
- **完成日历**：「我的」页近 12 个月月历热力图，按月卡片 + 圆点点阵展示每天完成局数，颜色越绿代表完成越多，风格与安卓端横向 53 周区分
- **积分系统**：基础分 × 难度系数 × 时间加成 × 错误惩罚
- **深色模式**：设置中可切换 跟随系统 / 浅色 / 深色并持久化保存，全界面配色自适应，深色下棋盘、笔记、按钮均做可读性优化，切换流畅无卡顿
- **音效与震动**：按键震动 + 原生音效，300ms 防误触

## 🛠 技术栈

<div align="center">

<table align="center" width="640">
  <tr>
    <th width="320" align="center">层级</th>
    <th width="320" align="center">技术</th>
  </tr>
  <tr>
    <td width="320" align="center">前端</td>
    <td width="320" align="center">Flutter (Dart)</td>
  </tr>
  <tr>
    <td width="320" align="center">后端</td>
    <td width="320" align="center">Go（<a href="https://github.com/hihukayo/go-sudoku-backend.git">go-sudoku-backend</a>）+ MySQL</td>
  </tr>
  <tr>
    <td width="320" align="center">音效</td>
    <td width="320" align="center">Android AudioTrack / MediaPlayer / audioplayers (Web)</td>
  </tr>
</table>

</div>

## 🚀 快速开始

### 环境要求

<div align="center">

<table align="center" width="640">
  <tr>
    <th width="213" align="center">工具</th>
    <th width="213" align="center">版本要求</th>
    <th width="214" align="center">说明</th>
  </tr>
  <tr>
    <td width="213" align="center">Flutter</td>
    <td width="213" align="center">^3.12</td>
    <td width="214" align="center">前端框架</td>
  </tr>
  <tr>
    <td width="213" align="center">Dart SDK</td>
    <td width="213" align="center">^3.12</td>
    <td width="214" align="center">随 Flutter 安装</td>
  </tr>
  <tr>
    <td width="213" align="center">Go</td>
    <td width="213" align="center">1.22+</td>
    <td width="214" align="center">后端编译</td>
  </tr>
  <tr>
    <td width="213" align="center">MySQL</td>
    <td width="213" align="center">8.0+</td>
    <td width="214" align="center">数据库</td>
  </tr>
</table>

</div>

### 1. 启动后端（Go）

```bash
git clone https://github.com/hihukayo/go-sudoku-backend.git
cd go-sudoku-backend
go build -o server.exe .
.\server.exe
# 输出：MySQL 连接成功 → 服务器已启动: http://localhost:8080
```

### 2. 运行 App（手机 / 模拟器）

```bash
flutter pub get
flutter devices
flutter run -d <设备ID>
```

### 3. 启动 Web 版

```bash
flutter build web --release
npx serve build/web
# 打开 npx serve 提示的地址（默认 http://localhost:3000）
```

> Web 版默认访问 `http://127.0.0.1:8080/api`（Go 后端），请先启动后端。

### 连接后端

- **USB 连接**：执行 `adb reverse tcp:8080 tcp:8080`，App 自动使用 `http://localhost:8080/api`
- **同一 WiFi**：手机与电脑连同一热点，电脑运行 `ipconfig` 查看局域网 IP（如 `192.168.43.74`），App 设置 → 服务器地址 填写 `192.168.43.74:8080`（请求 8 秒超时，超时可重试）
- **模拟器**：自动使用 `http://10.0.2.2:8080/api`
- **Web**：自动使用 `http://127.0.0.1:8080/api`

## 🗄 数据库

数据库 `PuzzleGame` 共 5 张表，后端启动时自动建表；也可手动执行以下 SQL：

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

表用途：

<div align="center">

<table align="center" width="640">
  <tr>
    <th width="320" align="center">表</th>
    <th width="320" align="center">用途</th>
  </tr>
  <tr>
    <td width="320" align="center">users</td>
    <td width="320" align="center">用户账号（用户名、手机号、密码哈希）</td>
  </tr>
  <tr>
    <td width="320" align="center">saves</td>
    <td width="320" align="center">游戏存档（每用户只保留最新一个）</td>
  </tr>
  <tr>
    <td width="320" align="center">user_stats</td>
    <td width="320" align="center">用户累计统计（总局数、完成数、总分）</td>
  </tr>
  <tr>
    <td width="320" align="center">game_records</td>
    <td width="320" align="center">每局游戏记录（模式、胜负、得分）</td>
  </tr>
  <tr>
    <td width="320" align="center">avatars</td>
    <td width="320" align="center">用户头像（base64，每用户一张）</td>
  </tr>
</table>

</div>

## 📡 API 接口

所有接口位于 `/api/`，请求 / 响应均为 JSON；失败时 `success` 为 `false`，HTTP 状态码一律 200。

### 用户系统

<div align="center">

<table align="center" width="640">
  <tr>
    <th width="213" align="center">方法</th>
    <th width="213" align="center">路径</th>
    <th width="214" align="center">说明</th>
  </tr>
  <tr>
    <td width="213" align="center">POST</td>
    <td width="213" align="center"><code>/api/register</code></td>
    <td width="214" align="center">注册账号</td>
  </tr>
  <tr>
    <td width="213" align="center">POST</td>
    <td width="213" align="center"><code>/api/login</code></td>
    <td width="214" align="center">登录（用户名或手机号）</td>
  </tr>
  <tr>
    <td width="213" align="center">PUT</td>
    <td width="213" align="center"><code>/api/user/update-username</code></td>
    <td width="214" align="center">修改用户名</td>
  </tr>
  <tr>
    <td width="213" align="center">PUT</td>
    <td width="213" align="center"><code>/api/user/update-password</code></td>
    <td width="214" align="center">修改密码</td>
  </tr>
  <tr>
    <td width="213" align="center">PUT</td>
    <td width="213" align="center"><code>/api/user/update-phone</code></td>
    <td width="214" align="center">修改手机号</td>
  </tr>
  <tr>
    <td width="213" align="center">DELETE</td>
    <td width="213" align="center"><code>/api/user/delete</code></td>
    <td width="214" align="center">注销账号</td>
  </tr>
</table>

</div>

### 存档

<div align="center">

<table align="center" width="640">
  <tr>
    <th width="213" align="center">方法</th>
    <th width="213" align="center">路径</th>
    <th width="214" align="center">说明</th>
  </tr>
  <tr>
    <td width="213" align="center">POST</td>
    <td width="213" align="center"><code>/api/save</code></td>
    <td width="214" align="center">保存游戏进度</td>
  </tr>
  <tr>
    <td width="213" align="center">GET</td>
    <td width="213" align="center"><code>/api/load?username=xxx</code></td>
    <td width="214" align="center">加载最近存档</td>
  </tr>
</table>

</div>

### 排行榜

<div align="center">

<table align="center" width="640">
  <tr>
    <th width="213" align="center">方法</th>
    <th width="213" align="center">路径</th>
    <th width="214" align="center">说明</th>
  </tr>
  <tr>
    <td width="213" align="center">POST</td>
    <td width="213" align="center"><code>/api/rank/submit</code></td>
    <td width="214" align="center">提交游戏结果（含积分）</td>
  </tr>
  <tr>
    <td width="213" align="center">GET</td>
    <td width="213" align="center"><code>/api/rank/list</code></td>
    <td width="214" align="center">排行榜（前 50）</td>
  </tr>
  <tr>
    <td width="213" align="center">GET</td>
    <td width="213" align="center"><code>/api/rank/user?username=xxx</code></td>
    <td width="214" align="center">个人统计</td>
  </tr>
</table>

</div>

### 头像

<div align="center">

<table align="center" width="640">
  <tr>
    <th width="213" align="center">方法</th>
    <th width="213" align="center">路径</th>
    <th width="214" align="center">说明</th>
  </tr>
  <tr>
    <td width="213" align="center">PUT</td>
    <td width="213" align="center"><code>/api/avatar</code></td>
    <td width="214" align="center">上传头像（base64，服务器持久化）</td>
  </tr>
  <tr>
    <td width="213" align="center">GET</td>
    <td width="213" align="center"><code>/api/avatar?username=xxx</code></td>
    <td width="214" align="center">获取头像（base64）</td>
  </tr>
</table>

</div>

## 🏆 积分系统

```
最终得分 = 基础分 × 难度系数 × 时间加成 × 错误惩罚
```

**基础分（含模式系数）**

<div align="center">

<table align="center" width="640">
  <tr>
    <th width="320" align="center">模式</th>
    <th width="320" align="center">基础分</th>
  </tr>
  <tr>
    <td width="320" align="center">9×9 常规</td>
    <td width="320" align="center">100</td>
  </tr>
  <tr>
    <td width="320" align="center">9×9 算数</td>
    <td width="320" align="center">200</td>
  </tr>
  <tr>
    <td width="320" align="center">16×16 常规</td>
    <td width="320" align="center">250</td>
  </tr>
</table>

</div>

**难度系数**

<div align="center">

<table align="center" width="640">
  <tr>
    <th width="320" align="center">难度</th>
    <th width="320" align="center">系数</th>
  </tr>
  <tr>
    <td width="320" align="center">简单 / 入门</td>
    <td width="320" align="center">1.0</td>
  </tr>
  <tr>
    <td width="320" align="center">中等</td>
    <td width="320" align="center">1.5</td>
  </tr>
  <tr>
    <td width="320" align="center">困难 / 极简</td>
    <td width="320" align="center">2.0</td>
  </tr>
</table>

</div>

**时间加成**：`(标准耗时 / 实际耗时) × 0.5 + 0.5`，取值 `[0.5, 5.0]`

**错误惩罚**：`(最大允许错误 - 实际错误) / 最大允许错误`，3×3 最大 3 次，4×4 最大 6 次

## 🎯 算数数独

在标准数独规则上增加笼子（Cage）与运算符约束：

1. 每行、每列、每宫数字 1-9 不重复
2. 每个笼子内数字按运算符计算结果等于右下角标签：`+` 求和、`-` 求差、`×` 求积、`÷` 求商
3. 2 格笼以除法为主（65%），3/4 格笼以加法为主（90%，乘积不超过 50），不生成 5 格笼
4. 试错机制：不逐格对照答案，允许试错
5. 错误满 3 次游戏结束

难度分布（正态随机）：

<div align="center">

<table align="center" width="640">
  <tr>
    <th width="106" align="center">难度</th>
    <th width="106" align="center">出现概率</th>
    <th width="106" align="center">2格</th>
    <th width="106" align="center">3格</th>
    <th width="106" align="center">4格</th>
    <th width="110" align="center">5格</th>
  </tr>
  <tr>
    <td width="106" align="center">🟢 入门</td>
    <td width="106" align="center">~25%</td>
    <td width="106" align="center">60%</td>
    <td width="106" align="center">35%</td>
    <td width="106" align="center">5%</td>
    <td width="110" align="center">0%</td>
  </tr>
  <tr>
    <td width="106" align="center">🔵 中等</td>
    <td width="106" align="center">~50%</td>
    <td width="106" align="center">40%</td>
    <td width="106" align="center">35%</td>
    <td width="106" align="center">25%</td>
    <td width="110" align="center">0%</td>
  </tr>
  <tr>
    <td width="106" align="center">🔴 困难</td>
    <td width="106" align="center">~25%</td>
    <td width="106" align="center">30%</td>
    <td width="106" align="center">30%</td>
    <td width="106" align="center">40%</td>
    <td width="110" align="center">0%</td>
  </tr>
</table>

</div>

支持 **L 型**、**阶梯型** 等异形笼子，从笼子任意边界扩展生成。

## 🔊 音效与反馈

<div align="center">

<table align="center" width="640">
  <tr>
    <th width="213" align="center">操作</th>
    <th width="213" align="center">Android</th>
    <th width="214" align="center">Web</th>
  </tr>
  <tr>
    <td width="213" align="center">按钮点击</td>
    <td width="213" align="center">80ms 震动 + 1200Hz 正弦波</td>
    <td width="214" align="center"><code>click.wav</code></td>
  </tr>
  <tr>
    <td width="213" align="center">填入/删除数字</td>
    <td width="213" align="center">震动 + <code>Placement.mp3</code></td>
    <td width="214" align="center"><code>Placement.mp3</code></td>
  </tr>
  <tr>
    <td width="213" align="center">完成游戏</td>
    <td width="213" align="center">震动 + 上扬滑音 600→1200Hz</td>
    <td width="214" align="center"><code>success.wav</code></td>
  </tr>
  <tr>
    <td width="213" align="center">错误满 3 次</td>
    <td width="213" align="center">震动 + <code>failed.mp3</code></td>
    <td width="214" align="center"><code>failed.mp3</code></td>
  </tr>
  <tr>
    <td width="213" align="center">撤销 / 重做</td>
    <td width="213" align="center">震动 + 按钮点击音</td>
    <td width="214" align="center"><code>click.wav</code></td>
  </tr>
</table>

</div>

## 📈 难度说明

### 3×3（81 格）

<div align="center">

<table align="center" width="640">
  <tr>
    <th width="160" align="center">难度</th>
    <th width="160" align="center">提示数</th>
    <th width="160" align="center">出现概率</th>
    <th width="160" align="center">说明</th>
  </tr>
  <tr>
    <td width="160" align="center">🟥 极简</td>
    <td width="160" align="center">17-22</td>
    <td width="160" align="center">~10%</td>
    <td width="160" align="center">需高级技巧</td>
  </tr>
  <tr>
    <td width="160" align="center">🟧 困难</td>
    <td width="160" align="center">23-28</td>
    <td width="160" align="center">~25%</td>
    <td width="160" align="center">适合有经验玩家</td>
  </tr>
  <tr>
    <td width="160" align="center">🟦 中等</td>
    <td width="160" align="center">29-32</td>
    <td width="160" align="center">~40%</td>
    <td width="160" align="center">常见数独水平</td>
  </tr>
  <tr>
    <td width="160" align="center">🟩 简单</td>
    <td width="160" align="center">33-36</td>
    <td width="160" align="center">~25%</td>
    <td width="160" align="center">新手入门</td>
  </tr>
</table>

</div>

### 4×4（256 格）

<div align="center">

<table align="center" width="640">
  <tr>
    <th width="213" align="center">难度</th>
    <th width="213" align="center">提示数</th>
    <th width="214" align="center">出现概率</th>
  </tr>
  <tr>
    <td width="213" align="center">🟧 困难</td>
    <td width="213" align="center">70-80</td>
    <td width="214" align="center">~25%</td>
  </tr>
  <tr>
    <td width="213" align="center">🟦 中等</td>
    <td width="213" align="center">92-105</td>
    <td width="214" align="center">~50%</td>
  </tr>
  <tr>
    <td width="213" align="center">🟩 简单</td>
    <td width="213" align="center">110-130</td>
    <td width="214" align="center">~25%</td>
  </tr>
</table>

</div>

## 📁 项目结构

```
sudoku/
├── lib/
│   ├── main.dart                  # 入口 + 启动画面
│   ├── models/                    # 数据模型、生成器、求解器
│   ├── screens/                   # 登录、注册、首页、游戏、排行榜、个人中心、设置
│   ├── widgets/sudoku_board.dart  # 棋盘组件（含算数笼绘制）
│   └── services/api_service.dart  # API 请求封装（可配置服务器地址 + 8 秒超时）
├── assets/audio/                  # 音效资源
├── android/                       # Android 工程
├── ios/                           # iOS 工程
├── web/                           # Web 入口（可构建 Web 版）
└── pubspec.yaml
```

> 后端为独立仓库：[go-sudoku-backend](https://github.com/hihukayo/go-sudoku-backend.git)（Go + MySQL，完整接口文档见该仓库 README）。

## 📥 下载

最新发布版：[GitHub Releases](https://github.com/hihukayo/Flutter-Mobile-Application-Sudoku-game/releases/latest)（含 arm64-v8a / armeabi-v7a / x86_64 三种安装包）

## 📄 License

本项目基于 GNU General Public License v3.0 (GPLv3) 开源 — 详见 [LICENSE](LICENSE) 文件。
