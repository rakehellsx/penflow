import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart' show Color;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';
import '../models/tool_model.dart';
import '../data/tools_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ToolDatabase - 工具箱 SQLite 持久化服务
//
// 数据库表：
//   tool_categories  - 工具分类（内置 + 自定义）
//   tools            - 工具定义（内置 + 自定义）
//   tool_payloads    - 载荷文件（本地磁盘路径关联）
//   tool_docs        - 工具文档（本地磁盘路径关联）
//
// 本地文件存储：
//   {appSupport}/penflow_tools/payloads/{tool_id}/  - 载荷文件
//   {appSupport}/penflow_tools/docs/{tool_id}/      - 文档文件
// ─────────────────────────────────────────────────────────────────────────────

class ToolDatabase {
  static final ToolDatabase _instance = ToolDatabase._();
  factory ToolDatabase() => _instance;
  ToolDatabase._();

  Database? _db;
  String? _toolsDir;
  final _uuid = const Uuid();

  // ── 初始化 ────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_db != null) return;
    final appDir = await getApplicationSupportDirectory();
    final dbPath = '${appDir.path}/penflow_tools.db';
    _toolsDir = '${appDir.path}/penflow_tools';
    await Directory('$_toolsDir/payloads').create(recursive: true);
    await Directory('$_toolsDir/docs').create(recursive: true);

    _db = sqlite3.open(dbPath);
    _db!.execute('PRAGMA foreign_keys = ON');
    _createTables();

    // 首次启动：将内置工具数据写入数据库
    await _seedBuiltinTools();
  }

  void _createTables() {
    // 工具分类表
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS tool_categories (
        id         TEXT PRIMARY KEY,
        label      TEXT NOT NULL,
        icon       TEXT NOT NULL DEFAULT '🔧',
        color_hex  TEXT NOT NULL DEFAULT '#6C8EBF',
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_builtin INTEGER NOT NULL DEFAULT 0,
        task_id    TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // 工具定义表
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS tools (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        desc       TEXT NOT NULL DEFAULT '',
        icon       TEXT NOT NULL DEFAULT '🔧',
        cat_id     TEXT NOT NULL,
        version    TEXT NOT NULL DEFAULT '',
        platform   TEXT NOT NULL DEFAULT 'Linux',
        risk       INTEGER NOT NULL DEFAULT 1,
        tags_json  TEXT NOT NULL DEFAULT '[]',
        usage      TEXT NOT NULL DEFAULT '',
        is_builtin INTEGER NOT NULL DEFAULT 0,
        task_id    TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (cat_id) REFERENCES tool_categories(id) ON DELETE SET DEFAULT
      )
    ''');

    // 载荷文件表（本地磁盘路径关联）
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS tool_payloads (
        id         TEXT PRIMARY KEY,
        tool_id    TEXT,
        task_id    TEXT,
        name       TEXT NOT NULL,
        local_path TEXT NOT NULL,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // 工具文档表（本地磁盘路径关联）
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS tool_docs (
        id           TEXT PRIMARY KEY,
        tool_id      TEXT,
        task_id      TEXT,
        name         TEXT NOT NULL,
        local_path   TEXT NOT NULL,
        content_cache TEXT NOT NULL DEFAULT '',
        created_at   TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  // ── 内置工具初始化（首次启动写入） ───────────────────────────────────────

  Future<void> _seedBuiltinTools() async {
    final count = _db!.select('SELECT COUNT(*) as c FROM tools WHERE is_builtin = 1').first['c'] as int;
    if (count > 0) return; // 已初始化，跳过

    // 写入内置分类
    for (final entry in kCategories.entries) {
      final cat = entry.value;
      final colorHex = '#${cat.color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
      _db!.execute('''
        INSERT OR IGNORE INTO tool_categories (id, label, icon, color_hex, sort_order, is_builtin)
        VALUES (?, ?, ?, ?, ?, 1)
      ''', [cat.id, cat.label, cat.icon, colorHex, kCategories.keys.toList().indexOf(entry.key)]);
    }

    // 写入内置工具
    for (final tool in kTools) {
      final tagsJson = jsonEncode(tool.tags);
      _db!.execute('''
        INSERT OR IGNORE INTO tools
          (id, name, desc, icon, cat_id, version, platform, risk, tags_json, usage, is_builtin)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
      ''', [
        tool.id, tool.name, tool.desc, tool.icon,
        tool.catId, tool.version, tool.platform,
        tool.risk.index, tagsJson, tool.usage,
      ]);
    }
  }

  // ── 分类 CRUD ─────────────────────────────────────────────────────────────

  List<ToolCategory> getAllCategories() {
    final rows = _db!.select(
        'SELECT * FROM tool_categories ORDER BY sort_order, created_at');
    return rows.map(_rowToCategory).toList();
  }

  List<ToolCategory> getCategoriesByTask(String taskId) {
    final rows = _db!.select(
        'SELECT * FROM tool_categories WHERE task_id = ? ORDER BY sort_order',
        [taskId]);
    return rows.map(_rowToCategory).toList();
  }

  String addCategory({
    required String label,
    required String icon,
    String colorHex = '#6C8EBF',
    String? taskId,
  }) {
    final id = 'cat_${_uuid.v4().substring(0, 8)}';
    final maxOrder = (_db!.select('SELECT MAX(sort_order) as m FROM tool_categories').first['m'] as int?) ?? 0;
    _db!.execute('''
      INSERT INTO tool_categories (id, label, icon, color_hex, sort_order, is_builtin, task_id)
      VALUES (?, ?, ?, ?, ?, 0, ?)
    ''', [id, label, icon, colorHex, maxOrder + 1, taskId]);
    return id;
  }

  void updateCategory(String id, {String? label, String? icon, String? colorHex}) {
    if (label != null) _db!.execute('UPDATE tool_categories SET label = ? WHERE id = ?', [label, id]);
    if (icon != null) _db!.execute('UPDATE tool_categories SET icon = ? WHERE id = ?', [icon, id]);
    if (colorHex != null) _db!.execute('UPDATE tool_categories SET color_hex = ? WHERE id = ?', [colorHex, id]);
  }

  void deleteCategory(String id) {
    _db!.execute('DELETE FROM tool_categories WHERE id = ? AND is_builtin = 0', [id]);
  }

  // ── 工具 CRUD ─────────────────────────────────────────────────────────────

  List<ToolDefinition> getAllTools() {
    final rows = _db!.select('SELECT * FROM tools ORDER BY is_builtin DESC, created_at');
    return rows.map(_rowToTool).toList();
  }

  List<ToolDefinition> getToolsByCategory(String catId) {
    final rows = _db!.select('SELECT * FROM tools WHERE cat_id = ? ORDER BY is_builtin DESC, name', [catId]);
    return rows.map(_rowToTool).toList();
  }

  List<ToolDefinition> getToolsByTask(String taskId) {
    final rows = _db!.select('SELECT * FROM tools WHERE task_id = ? ORDER BY created_at', [taskId]);
    return rows.map(_rowToTool).toList();
  }

  ToolDefinition? getToolById(String id) {
    final rows = _db!.select('SELECT * FROM tools WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _rowToTool(rows.first);
  }

  List<ToolDefinition> searchTools(String query) {
    final q = '%${query.toLowerCase()}%';
    final rows = _db!.select('''
      SELECT * FROM tools
      WHERE lower(name) LIKE ? OR lower(desc) LIKE ? OR lower(tags_json) LIKE ?
      ORDER BY is_builtin DESC, name
    ''', [q, q, q]);
    return rows.map(_rowToTool).toList();
  }

  String addTool({
    required String name,
    required String desc,
    required String icon,
    required String catId,
    String version = '',
    String platform = 'Linux',
    RiskLevel risk = RiskLevel.low,
    List<String> tags = const [],
    String usage = '',
    String? taskId,
  }) {
    final id = 'tool_${_uuid.v4().substring(0, 8)}';
    _db!.execute('''
      INSERT INTO tools (id, name, desc, icon, cat_id, version, platform, risk, tags_json, usage, is_builtin, task_id)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
    ''', [id, name, desc, icon, catId, version, platform, risk.index, jsonEncode(tags), usage, taskId]);
    return id;
  }

  void updateTool(String id, {
    String? name,
    String? desc,
    String? icon,
    String? catId,
    String? version,
    String? platform,
    RiskLevel? risk,
    List<String>? tags,
    String? usage,
  }) {
    final updates = <String>[];
    final params = <dynamic>[];
    if (name != null) { updates.add('name = ?'); params.add(name); }
    if (desc != null) { updates.add('desc = ?'); params.add(desc); }
    if (icon != null) { updates.add('icon = ?'); params.add(icon); }
    if (catId != null) { updates.add('cat_id = ?'); params.add(catId); }
    if (version != null) { updates.add('version = ?'); params.add(version); }
    if (platform != null) { updates.add('platform = ?'); params.add(platform); }
    if (risk != null) { updates.add('risk = ?'); params.add(risk.index); }
    if (tags != null) { updates.add('tags_json = ?'); params.add(jsonEncode(tags)); }
    if (usage != null) { updates.add('usage = ?'); params.add(usage); }
    if (updates.isEmpty) return;
    updates.add("updated_at = datetime('now')");
    params.add(id);
    _db!.execute('UPDATE tools SET ${updates.join(', ')} WHERE id = ?', params);
  }

  void deleteTool(String id) {
    // 删除关联的载荷和文档（级联清理磁盘文件）
    _deletePayloadsByTool(id);
    _deleteDocsByTool(id);
    _db!.execute('DELETE FROM tools WHERE id = ? AND is_builtin = 0', [id]);
  }

  // ── 载荷文件 CRUD ─────────────────────────────────────────────────────────

  List<ToolPayloadEntry> getPayloadsByTool(String toolId) {
    final rows = _db!.select(
        'SELECT * FROM tool_payloads WHERE tool_id = ? ORDER BY created_at', [toolId]);
    return rows.map(_rowToPayload).toList();
  }

  List<ToolPayloadEntry> getPayloadsByTask(String taskId) {
    final rows = _db!.select(
        'SELECT * FROM tool_payloads WHERE task_id = ? ORDER BY created_at', [taskId]);
    return rows.map(_rowToPayload).toList();
  }

  List<ToolPayloadEntry> getAllPayloads() {
    final rows = _db!.select('SELECT * FROM tool_payloads ORDER BY created_at');
    return rows.map(_rowToPayload).toList();
  }

  /// 从外部路径复制载荷文件到应用目录，并写入数据库
  Future<String> addPayload({
    required String sourcePath,
    String? toolId,
    String? taskId,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) throw Exception('文件不存在: $sourcePath');

    final id = _uuid.v4();
    final fileName = sourcePath.split(Platform.pathSeparator).last;
    final destDir = '$_toolsDir/payloads/${toolId ?? taskId ?? 'misc'}';
    await Directory(destDir).create(recursive: true);
    final destPath = '$destDir/$fileName';
    await sourceFile.copy(destPath);
    final size = await sourceFile.length();

    _db!.execute('''
      INSERT INTO tool_payloads (id, tool_id, task_id, name, local_path, size_bytes)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [id, toolId, taskId, fileName, destPath, size]);
    return id;
  }

  /// 直接写入字节数据（用于压缩包解压场景）
  Future<String> addPayloadFromBytes({
    required String fileName,
    required List<int> bytes,
    String? toolId,
    String? taskId,
  }) async {
    final id = _uuid.v4();
    final destDir = '$_toolsDir/payloads/${toolId ?? taskId ?? 'misc'}';
    await Directory(destDir).create(recursive: true);
    final destPath = '$destDir/$fileName';
    await File(destPath).writeAsBytes(bytes);

    _db!.execute('''
      INSERT INTO tool_payloads (id, tool_id, task_id, name, local_path, size_bytes)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [id, toolId, taskId, fileName, destPath, bytes.length]);
    return id;
  }

  void deletePayload(String id) {
    final rows = _db!.select('SELECT local_path FROM tool_payloads WHERE id = ?', [id]);
    if (rows.isNotEmpty) {
      final path = rows.first['local_path'] as String;
      try { File(path).deleteSync(); } catch (_) {}
    }
    _db!.execute('DELETE FROM tool_payloads WHERE id = ?', [id]);
  }

  void _deletePayloadsByTool(String toolId) {
    final rows = _db!.select('SELECT local_path FROM tool_payloads WHERE tool_id = ?', [toolId]);
    for (final row in rows) {
      try { File(row['local_path'] as String).deleteSync(); } catch (_) {}
    }
    _db!.execute('DELETE FROM tool_payloads WHERE tool_id = ?', [toolId]);
  }

  // ── 工具文档 CRUD ─────────────────────────────────────────────────────────

  List<ToolDocEntry> getDocsByTool(String toolId) {
    final rows = _db!.select(
        'SELECT * FROM tool_docs WHERE tool_id = ? ORDER BY created_at', [toolId]);
    return rows.map(_rowToDoc).toList();
  }

  List<ToolDocEntry> getDocsByTask(String taskId) {
    final rows = _db!.select(
        'SELECT * FROM tool_docs WHERE task_id = ? ORDER BY created_at', [taskId]);
    return rows.map(_rowToDoc).toList();
  }

  /// 从外部路径复制文档到应用目录，并写入数据库
  Future<String> addDoc({
    required String sourcePath,
    String? toolId,
    String? taskId,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) throw Exception('文件不存在: $sourcePath');

    final id = _uuid.v4();
    final fileName = sourcePath.split(Platform.pathSeparator).last;
    final destDir = '$_toolsDir/docs/${toolId ?? taskId ?? 'misc'}';
    await Directory(destDir).create(recursive: true);
    final destPath = '$destDir/$fileName';
    await sourceFile.copy(destPath);

    // 缓存文档内容（仅文本文件）
    String contentCache = '';
    final ext = fileName.split('.').last.toLowerCase();
    if (['md', 'txt', 'rst'].contains(ext)) {
      try { contentCache = await sourceFile.readAsString(); } catch (_) {}
    }

    _db!.execute('''
      INSERT INTO tool_docs (id, tool_id, task_id, name, local_path, content_cache)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [id, toolId, taskId, fileName, destPath, contentCache]);
    return id;
  }

  /// 直接写入字节数据（用于压缩包解压场景）
  Future<String> addDocFromBytes({
    required String fileName,
    required List<int> bytes,
    String? toolId,
    String? taskId,
  }) async {
    final id = _uuid.v4();
    final destDir = '$_toolsDir/docs/${toolId ?? taskId ?? 'misc'}';
    await Directory(destDir).create(recursive: true);
    final destPath = '$destDir/$fileName';
    await File(destPath).writeAsBytes(bytes);

    String contentCache = '';
    final ext = fileName.split('.').last.toLowerCase();
    if (['md', 'txt', 'rst'].contains(ext)) {
      try { contentCache = utf8.decode(bytes, allowMalformed: true); } catch (_) {}
    }

    _db!.execute('''
      INSERT INTO tool_docs (id, tool_id, task_id, name, local_path, content_cache)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [id, toolId, taskId, fileName, destPath, contentCache]);
    return id;
  }

  void deleteDoc(String id) {
    final rows = _db!.select('SELECT local_path FROM tool_docs WHERE id = ?', [id]);
    if (rows.isNotEmpty) {
      final path = rows.first['local_path'] as String;
      try { File(path).deleteSync(); } catch (_) {}
    }
    _db!.execute('DELETE FROM tool_docs WHERE id = ?', [id]);
  }

  void _deleteDocsByTool(String toolId) {
    final rows = _db!.select('SELECT local_path FROM tool_docs WHERE tool_id = ?', [toolId]);
    for (final row in rows) {
      try { File(row['local_path'] as String).deleteSync(); } catch (_) {}
    }
    _db!.execute('DELETE FROM tool_docs WHERE tool_id = ?', [toolId]);
  }

  // ── 外部 JSON 配置导入 ────────────────────────────────────────────────────

  /// 导入工具配置 JSON（格式见 exportToolsJson）
  /// 返回：{'imported': int, 'skipped': int, 'errors': List<String>}
  Map<String, dynamic> importFromJson(String jsonStr, {String? taskId}) {
    int imported = 0, skipped = 0;
    final errors = <String>[];

    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // 导入分类
      final categories = (data['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final cat in categories) {
        try {
          final id = cat['id'] as String? ?? 'cat_${_uuid.v4().substring(0, 8)}';
          final existing = _db!.select('SELECT id FROM tool_categories WHERE id = ?', [id]);
          if (existing.isNotEmpty) { skipped++; continue; }
          _db!.execute('''
            INSERT INTO tool_categories (id, label, icon, color_hex, sort_order, is_builtin, task_id)
            VALUES (?, ?, ?, ?, ?, 0, ?)
          ''', [
            id,
            cat['label'] ?? '未命名分类',
            cat['icon'] ?? '🔧',
            cat['color_hex'] ?? '#6C8EBF',
            cat['sort_order'] ?? 99,
            taskId,
          ]);
          imported++;
        } catch (e) {
          errors.add('分类导入失败: $e');
        }
      }

      // 导入工具
      final tools = (data['tools'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final tool in tools) {
        try {
          final id = tool['id'] as String? ?? 'tool_${_uuid.v4().substring(0, 8)}';
          final existing = _db!.select('SELECT id FROM tools WHERE id = ?', [id]);
          if (existing.isNotEmpty) {
            // 已存在则更新（非内置工具）
            final isBuiltin = (existing.first['is_builtin'] as int?) == 1;
            if (!isBuiltin) {
              updateTool(id,
                name: tool['name'],
                desc: tool['desc'],
                icon: tool['icon'],
                catId: tool['cat_id'],
                version: tool['version'],
                platform: tool['platform'],
                risk: RiskLevel.values[tool['risk'] ?? 1],
                tags: (tool['tags'] as List?)?.cast<String>() ?? [],
                usage: tool['usage'],
              );
              imported++;
            } else {
              skipped++;
            }
            continue;
          }
          _db!.execute('''
            INSERT INTO tools (id, name, desc, icon, cat_id, version, platform, risk, tags_json, usage, is_builtin, task_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
          ''', [
            id,
            tool['name'] ?? '未命名工具',
            tool['desc'] ?? '',
            tool['icon'] ?? '🔧',
            tool['cat_id'] ?? 'util',
            tool['version'] ?? '',
            tool['platform'] ?? 'Linux',
            tool['risk'] ?? 1,
            jsonEncode(tool['tags'] ?? []),
            tool['usage'] ?? '',
            taskId,
          ]);
          imported++;
        } catch (e) {
          errors.add('工具导入失败 [${tool['name']}]: $e');
        }
      }
    } catch (e) {
      errors.add('JSON 解析失败: $e');
    }

    return {'imported': imported, 'skipped': skipped, 'errors': errors};
  }

  /// 导出所有非内置工具为 JSON 字符串
  String exportToolsJson({String? taskId}) {
    List<Row> catRows;
    List<Row> toolRows;
    if (taskId != null) {
      catRows = _db!.select('SELECT * FROM tool_categories WHERE task_id = ?', [taskId]);
      toolRows = _db!.select('SELECT * FROM tools WHERE task_id = ?', [taskId]);
    } else {
      catRows = _db!.select('SELECT * FROM tool_categories WHERE is_builtin = 0');
      toolRows = _db!.select('SELECT * FROM tools WHERE is_builtin = 0');
    }

    final categories = catRows.map((r) => {
      'id': r['id'],
      'label': r['label'],
      'icon': r['icon'],
      'color_hex': r['color_hex'],
      'sort_order': r['sort_order'],
    }).toList();

    final tools = toolRows.map((r) => {
      'id': r['id'],
      'name': r['name'],
      'desc': r['desc'],
      'icon': r['icon'],
      'cat_id': r['cat_id'],
      'version': r['version'],
      'platform': r['platform'],
      'risk': r['risk'],
      'tags': jsonDecode(r['tags_json'] as String? ?? '[]'),
      'usage': r['usage'],
    }).toList();

    return const JsonEncoder.withIndent('  ').convert({
      'version': '1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'categories': categories,
      'tools': tools,
    });
  }

  /// 清理任务相关工具（删除任务时调用）
  void deleteByTask(String taskId) {
    // 清理载荷文件
    final payloads = _db!.select('SELECT local_path FROM tool_payloads WHERE task_id = ?', [taskId]);
    for (final row in payloads) {
      try { File(row['local_path'] as String).deleteSync(); } catch (_) {}
    }
    // 清理文档文件
    final docs = _db!.select('SELECT local_path FROM tool_docs WHERE task_id = ?', [taskId]);
    for (final row in docs) {
      try { File(row['local_path'] as String).deleteSync(); } catch (_) {}
    }
    _db!.execute('DELETE FROM tool_payloads WHERE task_id = ?', [taskId]);
    _db!.execute('DELETE FROM tool_docs WHERE task_id = ?', [taskId]);
    _db!.execute('DELETE FROM tools WHERE task_id = ? AND is_builtin = 0', [taskId]);
    _db!.execute('DELETE FROM tool_categories WHERE task_id = ? AND is_builtin = 0', [taskId]);
  }

  // ── 行转模型 ──────────────────────────────────────────────────────────────

  ToolCategory _rowToCategory(Row row) {
    final colorHex = row['color_hex'] as String? ?? '#6C8EBF';
    final color = _hexToColor(colorHex);
    return ToolCategory(
      id: row['id'] as String,
      label: row['label'] as String,
      icon: row['icon'] as String? ?? '🔧',
      color: color,
    );
  }

  ToolDefinition _rowToTool(Row row) {
    List<String> tags = [];
    try {
      tags = (jsonDecode(row['tags_json'] as String? ?? '[]') as List).cast<String>();
    } catch (_) {}
    return ToolDefinition(
      id: row['id'] as String,
      name: row['name'] as String,
      desc: row['desc'] as String? ?? '',
      icon: row['icon'] as String? ?? '🔧',
      catId: row['cat_id'] as String,
      version: row['version'] as String? ?? '',
      platform: row['platform'] as String? ?? 'Linux',
      risk: RiskLevel.values[(row['risk'] as int?) ?? 1],
      tags: tags,
      usage: row['usage'] as String? ?? '',
    );
  }

  ToolPayloadEntry _rowToPayload(Row row) => ToolPayloadEntry(
    id: row['id'] as String,
    toolId: row['tool_id'] as String?,
    taskId: row['task_id'] as String?,
    name: row['name'] as String,
    localPath: row['local_path'] as String,
    sizeBytes: row['size_bytes'] as int? ?? 0,
  );

  ToolDocEntry _rowToDoc(Row row) => ToolDocEntry(
    id: row['id'] as String,
    toolId: row['tool_id'] as String?,
    taskId: row['task_id'] as String?,
    name: row['name'] as String,
    localPath: row['local_path'] as String,
    contentCache: row['content_cache'] as String? ?? '',
  );

  static Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    if (h.length == 6) {
      return Color(int.parse('FF$h', radix: 16));
    } else if (h.length == 8) {
      return Color(int.parse(h, radix: 16));
    }
    return const Color(0xFF6C8EBF);
  }

  Database? get db => _db;
  String? get toolsDir => _toolsDir;
}

// ── 数据模型 ──────────────────────────────────────────────────────────────────

class ToolPayloadEntry {
  final String id;
  final String? toolId;
  final String? taskId;
  final String name;
  final String localPath;
  final int sizeBytes;

  const ToolPayloadEntry({
    required this.id,
    this.toolId,
    this.taskId,
    required this.name,
    required this.localPath,
    required this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }
}

class ToolDocEntry {
  final String id;
  final String? toolId;
  final String? taskId;
  final String name;
  final String localPath;
  final String contentCache;

  const ToolDocEntry({
    required this.id,
    this.toolId,
    this.taskId,
    required this.name,
    required this.localPath,
    required this.contentCache,
  });
}
