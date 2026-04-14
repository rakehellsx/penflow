import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:io';

/// 账号认证服务（SQLite3 存储，SHA-256 哈希密码）
class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();
  AuthService._();

  Database? _db;

  /// 初始化数据库，创建表，插入默认账号 admin/admin
  Future<void> init() async {
    if (_db != null) return;

    final dir = await getApplicationSupportDirectory();
    final dbPath = '${dir.path}${Platform.pathSeparator}penflow_auth.db';

    _db = sqlite3.open(dbPath);

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT    NOT NULL UNIQUE,
        password TEXT    NOT NULL,
        role     TEXT    NOT NULL DEFAULT 'user',
        created_at TEXT  NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // 插入默认 admin 账号（若不存在）
    final existing = _db!.select(
      'SELECT id FROM users WHERE username = ?',
      ['admin'],
    );
    if (existing.isEmpty) {
      _db!.execute(
        'INSERT INTO users (username, password, role) VALUES (?, ?, ?)',
        ['admin', _hash('admin'), 'admin'],
      );
    }
  }

  /// SHA-256 哈希
  String _hash(String plain) {
    final bytes = utf8.encode(plain);
    return sha256.convert(bytes).toString();
  }

  /// 验证用户名密码，返回 true 表示成功
  bool verify(String username, String password) {
    if (_db == null) return false;
    final rows = _db!.select(
      'SELECT id FROM users WHERE username = ? AND password = ?',
      [username, _hash(password)],
    );
    return rows.isNotEmpty;
  }

  /// 修改密码，返回 true 表示成功
  bool changePassword({
    required String username,
    required String oldPassword,
    required String newPassword,
  }) {
    if (_db == null) return false;
    if (!verify(username, oldPassword)) return false;
    if (newPassword.trim().isEmpty) return false;

    _db!.execute(
      'UPDATE users SET password = ? WHERE username = ?',
      [_hash(newPassword), username],
    );
    return true;
  }

  /// 获取当前登录用户角色
  String? getRole(String username) {
    if (_db == null) return null;
    final rows = _db!.select(
      'SELECT role FROM users WHERE username = ?',
      [username],
    );
    return rows.isEmpty ? null : rows.first['role'] as String?;
  }

  void dispose() {
    _db?.dispose();
    _db = null;
  }
}
