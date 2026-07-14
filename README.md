# 数独 Sudoku

Flutter 数独移动应用，包含用户登录注册、数独游戏、排行榜、个人中心等功能。

## 功能

- **用户系统**：注册/登录（后端 MySQL 存储）
- **数独游戏**：随机生成唯一题解的数独，计时、擦除、求解
- **排行榜**：按分数排名
- **个人中心**：修改用户名、密码、手机号

## 技术栈

- **前端**：Flutter 3.44（Dart 3.12）
- **后端**：Dart shelf + shelf_router
- **数据库**：MySQL

## 快速开始

### 1. 启动后端

```bash
cd server
dart pub get
dart run bin/server.dart
```

后端运行在 `http://localhost:8080`。

### 2. 启动前端

```bash
flutter pub get
flutter run -d edge     # 浏览器运行
flutter run             # 连接设备运行
```

### 3. Web 构建

```bash
flutter build web
npx serve build/web
```
