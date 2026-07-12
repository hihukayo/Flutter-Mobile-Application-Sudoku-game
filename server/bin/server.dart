import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as io;

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
  });

// ---- CORS 中间件 ----
Middleware corsMiddleware() {
  return (Handler innerHandler) {
    return (Request req) async {
      if (req.method == 'OPTIONS') {
        return Response(200, headers: _corsHeaders);
      }
      final res = await innerHandler(req);
      return res.change(headers: _corsHeaders);
    };
  };
}

final _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

// ---- 启动服务器 ----
void main() async {
  try {
    await _pool.execute('SELECT 1');
    print('MySQL 连接成功');
  } catch (e) {
    print('MySQL 连接失败：$e');
    exit(1);
  }

  final handler = const Pipeline()
      .addMiddleware(corsMiddleware())
      .addHandler(_router.call);
  final server = await io.serve(handler, '0.0.0.0', 8080);
  print('服务器已启动：http://localhost:${server.port}');
  print('接口列表：');
  print('  POST http://localhost:${server.port}/api/register');
  print('  POST http://localhost:${server.port}/api/login');
}
