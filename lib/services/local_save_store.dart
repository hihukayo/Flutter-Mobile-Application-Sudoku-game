import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';

/// 本地 SQLite 存档（离线也能存/读）。
/// 结构与后端 saves 表一致，另加 synced 标记表示是否已同步到云端。
class LocalSaveStore {
  static Database? _db;

  static Future<Database?> _database() async {
    if (kIsWeb) return null;
    _db ??= await openDatabase(
      'sudoku_local.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE IF NOT EXISTS local_saves ('
          'username TEXT PRIMARY KEY,'
          'save_json TEXT NOT NULL,'
          'saved_at TEXT,'
          'synced INTEGER DEFAULT 0)',
        );
      },
    );
    return _db;
  }

  /// 保存/覆盖本地存档；synced 表示这份存档是否已同步到云端
  static Future<void> save(String username, Map<String, dynamic> save, {required bool synced}) async {
    final db = await _database();
    if (db == null) return;
    await db.insert(
      'local_saves',
      {
        'username': username,
        'save_json': jsonEncode(save),
        'saved_at': save['savedAt'] ?? '',
        'synced': synced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 云端上传成功后调用：标记为已同步
  static Future<void> markSynced(String username) async {
    final db = await _database();
    if (db == null) return;
    await db.update('local_saves', {'synced': 1}, where: 'username = ?', whereArgs: [username]);
  }

  static Future<Map<String, dynamic>?> load(String username) async {
    final db = await _database();
    if (db == null) return null;
    final rows = await db.query(
      'local_saves',
      columns: ['save_json', 'saved_at', 'synced'],
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return jsonDecode(rows.first['save_json'] as String) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}