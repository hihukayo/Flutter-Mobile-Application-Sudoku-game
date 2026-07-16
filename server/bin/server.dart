import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

// ---- 数据库连接 ----
final _pool = MySQLConnectionPool(
  host: '127.0.0.1',
  port: 3306,
  userName: 'root',
  password: 'Zhy20060211zhyvanitas@',
  databaseName: 'PuzzleGame',
  maxConnections: 10,
);

// ---- 工具函数 ----
String _hashPassword(String password) {
  return sha256.convert(utf8.encode(password)).toString();
}

Map _ok([String? msg]) => {'success': true, 'message': msg ?? 'ok'};
Map _fail(String msg) => {'success': false, 'message': msg};

// ---- API 路由 ----
final _router = Router()
  // GET /api/ping — 连通性测试
  ..get('/api/ping', (Request req) async {
    return Response.ok(jsonEncode({'success': true, 'message': 'pong'}),
        headers: {'Content-Type': 'application/json'});
  })
  // POST /api/register
  ..post('/api/register', (Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final username = body['username']?.toString().trim();
      final phone = body['phone']?.toString().trim();
      final password = body['password']?.toString();

      if (username == null || username.isEmpty) {
        return Response.ok(jsonEncode(_fail('用户名不能为空')),
            headers: {'Content-Type': 'application/json'});
      }
      if (phone == null || phone.isEmpty) {
        return Response.ok(jsonEncode(_fail('手机号不能为空')),
            headers: {'Content-Type': 'application/json'});
      }
      if (password == null || password.length < 6) {
        return Response.ok(jsonEncode(_fail('密码至少 6 位')),
            headers: {'Content-Type': 'application/json'});
      }

      // 检查用户名是否已存在
      final checkUser = await _pool.execute(
        'SELECT username FROM users WHERE username = :username',
        {'username': username},
      );
      if (checkUser.rows.isNotEmpty) {
        return Response.ok(jsonEncode(_fail('该用户名已被注册')),
            headers: {'Content-Type': 'application/json'});
      }

      // 检查手机号是否已注册
      final checkPhone = await _pool.execute(
        'SELECT phone FROM users WHERE phone = :phone',
        {'phone': phone},
      );
      if (checkPhone.rows.isNotEmpty) {
        return Response.ok(jsonEncode(_fail('该手机号已注册')),
            headers: {'Content-Type': 'application/json'});
      }

      // 插入新用户（主键为 username + phone）
      await _pool.execute(
        'INSERT INTO users (username, phone, password) VALUES (:username, :phone, :password)',
        {'username': username, 'phone': phone, 'password': _hashPassword(password)},
      );

      return Response.ok(jsonEncode(_ok('注册成功')),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.ok(jsonEncode(_fail('服务器错误：$e')),
          headers: {'Content-Type': 'application/json'});
    }
  })

  // POST /api/login
  ..post('/api/login', (Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final account = body['account']?.toString().trim();
      final password = body['password']?.toString();

      if (account == null || account.isEmpty || password == null || password.isEmpty) {
        return Response.ok(jsonEncode(_fail('请输入账号（用户名/手机号）和密码')),
            headers: {'Content-Type': 'application/json'});
      }

      // 支持用户名或手机号登录
      final result = await _pool.execute(
        'SELECT username, phone, password FROM users WHERE username = :account OR phone = :account',
        {'account': account},
      );
      if (result.rows.isEmpty) {
        return Response.ok(jsonEncode(_fail('账号或密码错误')),
            headers: {'Content-Type': 'application/json'});
      }

      final row = result.rows.first;
      final storedHash = row.colAt(2)!;
      if (storedHash != _hashPassword(password)) {
        return Response.ok(jsonEncode(_fail('账号或密码错误')),
            headers: {'Content-Type': 'application/json'});
      }

      return Response.ok(
          jsonEncode({
            'success': true,
            'message': '登录成功',
            'username': row.colAt(0),
            'phone': row.colAt(1),
          }),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.ok(jsonEncode(_fail('服务器错误：$e')),
          headers: {'Content-Type': 'application/json'});
    }
  })

  // PUT /api/user/update-username
  ..put('/api/user/update-username', (Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final username = body['username']?.toString().trim();
      final newUsername = body['newUsername']?.toString().trim();
      final password = body['password']?.toString();

      if (username == null || newUsername == null || password == null) {
        return Response.ok(jsonEncode(_fail('参数不完整')), headers: {'Content-Type': 'application/json'});
      }

      // 验证密码
      final check = await _pool.execute(
        'SELECT password FROM users WHERE username = :username',
        {'username': username},
      );
      if (check.rows.isEmpty || check.rows.first.colAt(0) != _hashPassword(password)) {
        return Response.ok(jsonEncode(_fail('密码验证失败')), headers: {'Content-Type': 'application/json'});
      }

      // 检查新用户名是否已被占用
      final dup = await _pool.execute(
        'SELECT username FROM users WHERE username = :newUsername AND username != :username',
        {'newUsername': newUsername, 'username': username},
      );
      if (dup.rows.isNotEmpty) {
        return Response.ok(jsonEncode(_fail('该用户名已被使用')), headers: {'Content-Type': 'application/json'});
      }

      await _pool.execute(
        'UPDATE users SET username = :newUsername WHERE username = :username',
        {'newUsername': newUsername, 'username': username},
      );
      return Response.ok(jsonEncode(_ok('用户名已更新')), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.ok(jsonEncode(_fail('服务器错误：$e')), headers: {'Content-Type': 'application/json'});
    }
  })

  // PUT /api/user/update-password
  ..put('/api/user/update-password', (Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final username = body['username']?.toString().trim();
      final oldPassword = body['oldPassword']?.toString();
      final newPassword = body['newPassword']?.toString();

      if (username == null || oldPassword == null || newPassword == null) {
        return Response.ok(jsonEncode(_fail('参数不完整')), headers: {'Content-Type': 'application/json'});
      }
      if (newPassword.length < 6) {
        return Response.ok(jsonEncode(_fail('新密码至少 6 位')), headers: {'Content-Type': 'application/json'});
      }

      final check = await _pool.execute(
        'SELECT password FROM users WHERE username = :username',
        {'username': username},
      );
      if (check.rows.isEmpty || check.rows.first.colAt(0) != _hashPassword(oldPassword)) {
        return Response.ok(jsonEncode(_fail('原密码错误')), headers: {'Content-Type': 'application/json'});
      }

      await _pool.execute(
        'UPDATE users SET password = :password WHERE username = :username',
        {'password': _hashPassword(newPassword), 'username': username},
      );
      return Response.ok(jsonEncode(_ok('密码已更新')), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.ok(jsonEncode(_fail('服务器错误：$e')), headers: {'Content-Type': 'application/json'});
    }
  })

  // PUT /api/user/update-phone
  ..put('/api/user/update-phone', (Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final username = body['username']?.toString().trim();
      final newPhone = body['newPhone']?.toString().trim();
      final password = body['password']?.toString();

      if (username == null || newPhone == null || password == null) {
        return Response.ok(jsonEncode(_fail('参数不完整')), headers: {'Content-Type': 'application/json'});
      }

      final check = await _pool.execute(
        'SELECT password FROM users WHERE username = :username',
        {'username': username},
      );
      if (check.rows.isEmpty || check.rows.first.colAt(0) != _hashPassword(password)) {
        return Response.ok(jsonEncode(_fail('密码验证失败')), headers: {'Content-Type': 'application/json'});
      }

      final dup = await _pool.execute(
        'SELECT phone FROM users WHERE phone = :newPhone AND username != :username',
        {'newPhone': newPhone, 'username': username},
      );
      if (dup.rows.isNotEmpty) {
        return Response.ok(jsonEncode(_fail('该手机号已被使用')), headers: {'Content-Type': 'application/json'});
      }

      await _pool.execute(
        'UPDATE users SET phone = :newPhone WHERE username = :username',
        {'newPhone': newPhone, 'username': username},
      );
      return Response.ok(jsonEncode(_ok('手机号已更新')), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.ok(jsonEncode(_fail('服务器错误：$e')), headers: {'Content-Type': 'application/json'});
    }
  })

  // DELETE /api/user/delete
  ..delete('/api/user/delete', (Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final username = body['username']?.toString().trim();
      final phone = body['phone']?.toString().trim();
      final password = body['password']?.toString();

      if (username == null || phone == null || password == null) {
        return Response.ok(jsonEncode(_fail('参数不完整')), headers: {'Content-Type': 'application/json'});
      }

      // 验证账号是否存在且密码正确
      final check = await _pool.execute(
        'SELECT password FROM users WHERE username = :username AND phone = :phone',
        {'username': username, 'phone': phone},
      );
      if (check.rows.isEmpty) {
        return Response.ok(jsonEncode(_fail('账号信息不匹配')), headers: {'Content-Type': 'application/json'});
      }
      if (check.rows.first.colAt(0) != _hashPassword(password)) {
        return Response.ok(jsonEncode(_fail('密码错误')), headers: {'Content-Type': 'application/json'});
      }

      await _pool.execute(
        'DELETE FROM users WHERE username = :username',
        {'username': username},
      );
      return Response.ok(jsonEncode(_ok('账号已注销')), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.ok(jsonEncode(_fail('服务器错误：$e')), headers: {'Content-Type': 'application/json'});
    }
  })

  // ---- 存档功能 ----

  // POST /api/save — 保存游戏进度
  ..post('/api/save', (Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final username = body['username']?.toString().trim();
      if (username == null || username.isEmpty) {
        return Response.ok(jsonEncode(_fail('参数不完整')),
            headers: {'Content-Type': 'application/json'});
      }

      // 先删除该用户的旧存档（只保留最新一个）
      await _pool.execute('DELETE FROM saves WHERE username = :username', {'username': username});

      // 插入新存档
      await _pool.execute('''
        INSERT INTO saves (username, board_size, cells, notes, solution, given,
                           seconds, errors, is_killer, killer_difficulty, cages)
        VALUES (:username, :boardSize, :cells, :notes, :solution, :given,
                :seconds, :errors, :isKiller, :killerDifficulty, :cages)
      ''', {
        'username': username,
        'boardSize': body['boardSize']?.toString() ?? '3',
        'cells': jsonEncode(body['cells']),
        'notes': jsonEncode(body['notes']),
        'solution': jsonEncode(body['solution']),
        'given': jsonEncode(body['given']),
        'seconds': (body['seconds'] ?? 0).toString(),
        'errors': (body['errors'] ?? 0).toString(),
        'isKiller': body['isKiller'] == true ? '1' : '0',
        'killerDifficulty': body['killerDifficulty']?.toString() ?? '',
        'cages': body['cages'] != null ? jsonEncode(body['cages']) : '[]',
      });

      return Response.ok(jsonEncode(_ok('存档成功')),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.ok(jsonEncode(_fail('保存失败：$e')),
          headers: {'Content-Type': 'application/json'});
    }
  })

  // GET /api/load?username=xxx — 加载最近一次存档
  ..get('/api/load', (Request req) async {
    try {
      final username = req.url.queryParameters['username']?.trim();
      if (username == null || username.isEmpty) {
        return Response.ok(jsonEncode(_fail('缺少用户名')),
            headers: {'Content-Type': 'application/json'});
      }

      final result = await _pool.execute(
        'SELECT * FROM saves WHERE username = :username ORDER BY saved_at DESC LIMIT 1',
        {'username': username},
      );

      if (result.rows.isEmpty) {
        return Response.ok(jsonEncode({'success': false, 'message': '没有存档'}),
            headers: {'Content-Type': 'application/json'});
      }

      final row = result.rows.first;
      final data = {
        'success': true,
        'boardSize': int.tryParse(row.colAt(1) ?? '3') ?? 3,
        'cells': jsonDecode(row.colAt(2) ?? '[]'),
        'notes': jsonDecode(row.colAt(3) ?? '[]'),
        'solution': jsonDecode(row.colAt(4) ?? '[]'),
        'given': jsonDecode(row.colAt(5) ?? '[]'),
        'seconds': int.tryParse(row.colAt(6) ?? '0') ?? 0,
        'errors': int.tryParse(row.colAt(7) ?? '0') ?? 0,
        'isKiller': row.colAt(8) == '1',
        'killerDifficulty': row.colAt(9) ?? '',
        'cages': jsonDecode(row.colAt(10) ?? '[]'),
        'savedAt': row.colAt(11) ?? '',
      };

      return Response.ok(jsonEncode(data),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.ok(jsonEncode(_fail('加载失败：$e')),
          headers: {'Content-Type': 'application/json'});
    }
  })

  // ---- 排行榜功能 ----

  // POST /api/rank/submit — 提交游戏结果（更新胜率+积分）
  ..post('/api/rank/submit', (Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final username = body['username']?.toString().trim();
      final won = body['won'] == true;
      final score = (body['score'] as num?)?.toInt() ?? 0;

      if (username == null || username.isEmpty) {
        return Response.ok(jsonEncode(_fail('参数不完整')),
            headers: {'Content-Type': 'application/json'});
      }

      // 拆分 INSERT/UPDATE
      var check = await _pool.execute(
        'SELECT COUNT(*) FROM user_stats WHERE username = :username',
        {'username': username},
      );
      if (check.rows.first.colAt(0) == '0') {
        await _pool.execute('''
          INSERT INTO user_stats (username, total_games, completed_games, total_score)
          VALUES ('$username', 1, ${won ? 1 : 0}, $score)
        ''');
      } else {
        await _pool.execute('''
          UPDATE user_stats SET
            total_games = total_games + 1,
            completed_games = completed_games + ${won ? 1 : 0},
            total_score = total_score + $score
          WHERE username = '$username'
        ''');
      }

      // 记录游戏详情
      final gameMode = body['gameMode']?.toString() ?? '';
      final boardSize = body['boardSize']?.toString() ?? '3';
      await _pool.execute('''
        INSERT INTO game_records (username, won, game_mode, board_size, score)
        VALUES ('$username', ${won ? 1 : 0}, '$gameMode', $boardSize, $score)
      ''');

      return Response.ok(jsonEncode({'success': true, 'message': '已记录', 'score': score}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.ok(jsonEncode(_fail('提交失败：$e')),
          headers: {'Content-Type': 'application/json'});
    }
  })

  // GET /api/rank/list — 获取排行榜（按完成数降序，胜率降序）
  ..get('/api/rank/list', (Request req) async {
    try {
      final result = await _pool.execute('''
        SELECT username, total_games, completed_games, COALESCE(total_score, 0)
        FROM user_stats
        WHERE total_games > 0
        ORDER BY total_score DESC,
                 completed_games DESC
        LIMIT 50
      ''');

      final list = result.rows.map((row) {
        final username = row.colAt(0) ?? '';
        final total = int.tryParse(row.colAt(1) ?? '0') ?? 0;
        final completed = int.tryParse(row.colAt(2) ?? '0') ?? 0;
        final score = int.tryParse(row.colAt(3) ?? '0') ?? 0;
        final winRate = total > 0 ? (completed * 100 / total).toStringAsFixed(1) : '0.0';
        return {
          'username': username,
          'totalGames': total,
          'completedGames': completed,
          'winRate': double.parse(winRate),
          'totalScore': score,
        };
      }).toList();

      return Response.ok(jsonEncode({'success': true, 'data': list}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.ok(jsonEncode(_fail('获取排行榜失败：$e')),
          headers: {'Content-Type': 'application/json'});
    }
  })

  // GET /api/rank/user?username=xxx — 获取单个用户统计
  ..get('/api/rank/user', (Request req) async {
    try {
      final username = req.url.queryParameters['username']?.trim();
      if (username == null || username.isEmpty) {
        return Response.ok(jsonEncode(_fail('缺少用户名')),
            headers: {'Content-Type': 'application/json'});
      }

      final result = await _pool.execute(
        'SELECT total_games, completed_games, COALESCE(total_score, 0) FROM user_stats WHERE username = :username',
        {'username': username},
      );

      if (result.rows.isEmpty) {
        return Response.ok(jsonEncode({
          'success': true,
          'totalGames': 0,
          'completedGames': 0,
          'totalScore': 0,
          'winRate': 0.0,
        }), headers: {'Content-Type': 'application/json'});
      }

      final row = result.rows.first;
      final total = int.tryParse(row.colAt(0) ?? '0') ?? 0;
      final completed = int.tryParse(row.colAt(1) ?? '0') ?? 0;
      final score = int.tryParse(row.colAt(2) ?? '0') ?? 0;
      final winRate = total > 0 ? (completed * 100 / total) : 0.0;

      // 按模式统计
      final modeResult = await _pool.execute('''
        SELECT game_mode, COUNT(*) AS total, SUM(won) AS completed
        FROM game_records
        WHERE username = :username
        GROUP BY game_mode
        ORDER BY total DESC
      ''', {'username': username});

      final modeStats = modeResult.rows.map((r) => {
        'mode': r.colAt(0) ?? '',
        'total': int.tryParse(r.colAt(1) ?? '0') ?? 0,
        'completed': int.tryParse(r.colAt(2) ?? '0') ?? 0,
      }).toList();

      return Response.ok(jsonEncode({
        'success': true,
        'totalGames': total,
        'completedGames': completed,
        'totalScore': score,
        'winRate': winRate,
        'modeStats': modeStats,
      }), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.ok(jsonEncode(_fail('获取失败：$e')),
          headers: {'Content-Type': 'application/json'});
    }
  });

// ---- CORS 中间件（含错误兜底，确保跨域请求始终有返回） ----
Middleware corsMiddleware() {
  return (Handler innerHandler) {
    return (Request req) async {
      // 预检请求直接返回
      if (req.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      try {
        final res = await innerHandler(req);
        return res.change(headers: _corsHeaders);
      } catch (e) {
        // 路由内未捕获的异常，兜底返回 500 并带 CORS 头
        return Response.internalServerError(
          body: jsonEncode({'success': false, 'message': '服务器内部错误'}),
          headers: {..._corsHeaders, 'Content-Type': 'application/json'},
        );
      }
    };
  };
}

final _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

// ---- 创建表（不存在时自动创建） ----
Future<void> _initTables() async {
  await _pool.execute('''
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
    )
  ''');
  await _pool.execute('''
    CREATE TABLE IF NOT EXISTS user_stats (
      username VARCHAR(255) PRIMARY KEY,
      total_games INT DEFAULT 0,
      completed_games INT DEFAULT 0,
      total_score INT DEFAULT 0,
      last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  await _pool.execute('''
    CREATE TABLE IF NOT EXISTS game_records (
      id INT AUTO_INCREMENT PRIMARY KEY,
      username VARCHAR(255) NOT NULL,
      won TINYINT DEFAULT 0,
      game_mode VARCHAR(50) DEFAULT '',
      board_size INT DEFAULT 3,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_username (username),
      INDEX idx_game_mode (game_mode),
      INDEX idx_board_size (board_size)
    )
  ''');
  // 兼容升级：添加积分字段（表已存在时忽略错误）
  try { await _pool.execute('ALTER TABLE user_stats ADD COLUMN total_score INT DEFAULT 0'); } catch (_) {}
  try { await _pool.execute('ALTER TABLE game_records ADD COLUMN score INT DEFAULT 0'); } catch (_) {}
  // 修复历史数据中可能存在的 NULL 值
  try { await _pool.execute('UPDATE user_stats SET total_score = 0 WHERE total_score IS NULL'); } catch (_) {}
  try { await _pool.execute('UPDATE game_records SET score = 0 WHERE score IS NULL'); } catch (_) {}
  print('数据表初始化完成');
}

// ---- 启动服务器 ----
void main() async {
  try {
    await _pool.execute('SELECT 1');
    print('MySQL 连接成功');
  } catch (e) {
    print('MySQL 连接失败：$e');
    exit(1);
  }

  await _initTables();

  // API 管道（含 CORS）
  final apiPipeline = const Pipeline()
      .addMiddleware(corsMiddleware())
      .addHandler(_router.call);

  // 静态文件服务
  final staticHandler = createStaticHandler('../build/web',
      defaultDocument: 'index.html');

  // 组合处理器
  FutureOr<Response> handler(Request req) async {
    final path = req.url.path;
    if (path.startsWith('api/')) {
      return await apiPipeline(req);
    }
    final result = await staticHandler(req);
    if (result.statusCode == 404) {
      return await staticHandler(Request(req.method,
          Uri.parse('http://${req.requestedUri.host}:${req.requestedUri.port}/index.html'),
          headers: req.headers));
    }
    return result;
  }

  // 绑定到所有网络接口（IPv4 + 尝试 IPv6）
  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('服务器已启动：http://localhost:${server.port} （IPv4）');
  try {
    await io.serve(handler, InternetAddress.loopbackIPv6, 8080);
    print('  ✓ 同时监听 IPv6 localhost');
  } catch (_) {}
  print('接口列表 (端口 ${server.port})：');
  print('  GET    http://127.0.0.1:${server.port}/api/ping');
  print('  Web:   http://127.0.0.1:${server.port} （前端页面）');
}
