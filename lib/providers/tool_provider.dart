import 'package:flutter/material.dart';
import '../models/tool_model.dart';
import '../services/tool_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ToolProvider - 工具箱状态管理
// 从 SQLite 加载工具，支持运行时 CRUD、搜索、外部导入
// ─────────────────────────────────────────────────────────────────────────────

class ToolProvider extends ChangeNotifier {
  final _db = ToolDatabase();

  List<ToolCategory> _categories = [];
  List<ToolDefinition> _tools = [];
  bool _initialized = false;
  bool _loading = false;
  String? _error;

  List<ToolCategory> get categories => _categories;
  List<ToolDefinition> get tools => _tools;
  bool get initialized => _initialized;
  bool get loading => _loading;
  String? get error => _error;

  // ── 初始化 ────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _loading = true;
    notifyListeners();
    try {
      await _db.init();
      await _reload();
      _initialized = true;
      _error = null;
    } catch (e) {
      _error = '工具箱初始化失败: $e';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> _reload() async {
    _categories = _db.getAllCategories();
    _tools = _db.getAllTools();
  }

  Future<void> refresh() async {
    await _reload();
    notifyListeners();
  }

  // ── 查询 ──────────────────────────────────────────────────────────────────

  List<ToolDefinition> getToolsByCategory(String catId) =>
      _tools.where((t) => t.catId == catId).toList();

  List<ToolDefinition> searchTools(String query) {
    if (query.isEmpty) return _tools;
    final q = query.toLowerCase();
    return _tools.where((t) =>
        t.name.toLowerCase().contains(q) ||
        t.desc.toLowerCase().contains(q) ||
        t.tags.any((tag) => tag.toLowerCase().contains(q))).toList();
  }

  ToolDefinition? getToolById(String id) {
    try {
      return _tools.firstWhere((t) => t.id == id);
    } catch (_) {
      return _db.getToolById(id);
    }
  }

  ToolCategory? getCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── 分类 CRUD ─────────────────────────────────────────────────────────────

  Future<String> addCategory({
    required String label,
    required String icon,
    String colorHex = '#6C8EBF',
    String? taskId,
  }) async {
    final id = _db.addCategory(label: label, icon: icon, colorHex: colorHex, taskId: taskId);
    await _reload();
    notifyListeners();
    return id;
  }

  Future<void> updateCategory(String id, {String? label, String? icon, String? colorHex}) async {
    _db.updateCategory(id, label: label, icon: icon, colorHex: colorHex);
    await _reload();
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    _db.deleteCategory(id);
    await _reload();
    notifyListeners();
  }

  // ── 工具 CRUD ─────────────────────────────────────────────────────────────

  Future<String> addTool({
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
  }) async {
    final id = _db.addTool(
      name: name, desc: desc, icon: icon, catId: catId,
      version: version, platform: platform, risk: risk,
      tags: tags, usage: usage, taskId: taskId,
    );
    await _reload();
    notifyListeners();
    return id;
  }

  Future<void> updateTool(String id, {
    String? name, String? desc, String? icon, String? catId,
    String? version, String? platform, RiskLevel? risk,
    List<String>? tags, String? usage,
  }) async {
    _db.updateTool(id,
      name: name, desc: desc, icon: icon, catId: catId,
      version: version, platform: platform, risk: risk,
      tags: tags, usage: usage,
    );
    await _reload();
    notifyListeners();
  }

  Future<void> deleteTool(String id) async {
    _db.deleteTool(id);
    await _reload();
    notifyListeners();
  }

  // ── 载荷文件 ──────────────────────────────────────────────────────────────

  List<ToolPayloadEntry> getPayloadsByTool(String toolId) =>
      _db.getPayloadsByTool(toolId);

  List<ToolPayloadEntry> getAllPayloads() => _db.getAllPayloads();

  Future<String> addPayload({
    required String sourcePath,
    String? toolId,
    String? taskId,
  }) async {
    final id = await _db.addPayload(sourcePath: sourcePath, toolId: toolId, taskId: taskId);
    notifyListeners();
    return id;
  }

  Future<String> addPayloadFromBytes({
    required String fileName,
    required List<int> bytes,
    String? toolId,
    String? taskId,
  }) async {
    final id = await _db.addPayloadFromBytes(
        fileName: fileName, bytes: bytes, toolId: toolId, taskId: taskId);
    notifyListeners();
    return id;
  }

  void deletePayload(String id) {
    _db.deletePayload(id);
    notifyListeners();
  }

  // ── 工具文档 ──────────────────────────────────────────────────────────────

  List<ToolDocEntry> getDocsByTool(String toolId) => _db.getDocsByTool(toolId);

  Future<String> addDoc({
    required String sourcePath,
    String? toolId,
    String? taskId,
  }) async {
    final id = await _db.addDoc(sourcePath: sourcePath, toolId: toolId, taskId: taskId);
    notifyListeners();
    return id;
  }

  Future<String> addDocFromBytes({
    required String fileName,
    required List<int> bytes,
    String? toolId,
    String? taskId,
  }) async {
    final id = await _db.addDocFromBytes(
        fileName: fileName, bytes: bytes, toolId: toolId, taskId: taskId);
    notifyListeners();
    return id;
  }

  void deleteDoc(String id) {
    _db.deleteDoc(id);
    notifyListeners();
  }

  // ── 外部 JSON 导入/导出 ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> importFromJson(String jsonStr, {String? taskId}) async {
    final result = _db.importFromJson(jsonStr, taskId: taskId);
    await _reload();
    notifyListeners();
    return result;
  }

  String exportToolsJson({String? taskId}) => _db.exportToolsJson(taskId: taskId);

  // ── 任务清理 ──────────────────────────────────────────────────────────────

  Future<void> deleteByTask(String taskId) async {
    _db.deleteByTask(taskId);
    await _reload();
    notifyListeners();
  }

  // ── 数据库实例（供 TaskService 使用） ─────────────────────────────────────
  ToolDatabase get database => _db;
}
