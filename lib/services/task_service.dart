import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:archive/archive_io.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 任务持久化服务（SQLite + 文件系统）
//
// 数据库表：
//   tasks         - 任务主表（含工作流路径、压缩包路径等完整字段）
//   task_files    - 任务文件表（载荷 + 文档）
//   node_vm_binds - 节点VM绑定表（画布节点 → 虚拟机）
// ─────────────────────────────────────────────────────────────────────────────

class TaskService {
  static final TaskService _instance = TaskService._();
  factory TaskService() => _instance;
  TaskService._();

  Database? _db;
  String? _tasksDir;
  final _uuid = const Uuid();

  // ── 初始化 ────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_db != null) return;

    final appDir = await getApplicationSupportDirectory();
    final dbPath = '${appDir.path}/penflow_tasks.db';
    _tasksDir = '${appDir.path}/tasks';

    await Directory(_tasksDir!).create(recursive: true);

    _db = sqlite3.open(dbPath);
    _db!.execute('PRAGMA foreign_keys = ON');
    _createTables();
  }

  void _createTables() {
    // 任务主表（完整字段）
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id              TEXT PRIMARY KEY,
        name            TEXT NOT NULL,
        description     TEXT NOT NULL DEFAULT '',
        workflow_path   TEXT NOT NULL DEFAULT '',
        zip_path        TEXT NOT NULL DEFAULT '',
        workflow_json   TEXT NOT NULL DEFAULT '{}',
        created_at      TEXT NOT NULL,
        updated_at      TEXT NOT NULL
      )
    ''');

    // 任务文件表（载荷 + 文档）
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS task_files (
        id         TEXT PRIMARY KEY,
        task_id    TEXT NOT NULL,
        name       TEXT NOT NULL,
        type       TEXT NOT NULL,
        local_path TEXT NOT NULL,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');

    // 节点VM绑定表（画布节点 → 虚拟机信息持久化）
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS node_vm_binds (
        id          TEXT PRIMARY KEY,
        task_id     TEXT,
        node_id     TEXT NOT NULL,
        vm_id       TEXT NOT NULL,
        vm_name     TEXT NOT NULL DEFAULT '',
        vm_ip       TEXT NOT NULL DEFAULT '',
        vm_os_type  TEXT NOT NULL DEFAULT '',
        vm_tag      TEXT NOT NULL DEFAULT '',
        vm_backend  TEXT NOT NULL DEFAULT '',
        bound_at    TEXT NOT NULL,
        UNIQUE(node_id)
      )
    ''');
  }

  // ── 压缩包解析 ────────────────────────────────────────────────────────────

  Future<TaskParseResult> parseZip(String zipPath) async {
    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      String? workflowJson;
      final payloadFiles = <_RawFile>[];
      final docFiles = <_RawFile>[];

      for (final file in archive) {
        if (file.isFile) {
          final name = file.name;
          final content = file.content as List<int>;

          if (name == 'workflow.json' || name.endsWith('/workflow.json')) {
            workflowJson = utf8.decode(content);
          } else if (name.startsWith('payloads/') || name.startsWith('payload/')) {
            final fname = name.split('/').last;
            if (fname.isNotEmpty) payloadFiles.add(_RawFile(fname, content));
          } else if (name.startsWith('docs/') || name.startsWith('doc/')) {
            final fname = name.split('/').last;
            if (fname.isNotEmpty) docFiles.add(_RawFile(fname, content));
          }
        }
      }

      if (workflowJson == null) {
        return TaskParseResult.error('压缩包中未找到 workflow.json 文件');
      }

      try {
        final wf = jsonDecode(workflowJson) as Map<String, dynamic>;
        if (!wf.containsKey('nodes') || !wf.containsKey('connections')) {
          return TaskParseResult.error('workflow.json 格式不正确，缺少 nodes 或 connections 字段');
        }
      } catch (e) {
        return TaskParseResult.error('workflow.json 解析失败: $e');
      }

      return TaskParseResult.success(
        workflowJson: workflowJson,
        payloadFiles: payloadFiles,
        docFiles: docFiles,
      );
    } catch (e) {
      return TaskParseResult.error('压缩包解析失败: $e');
    }
  }

  // ── 创建任务 ──────────────────────────────────────────────────────────────

  Future<TaskCreateResult> createTask({
    required String name,
    required String description,
    required String zipPath,
  }) async {
    await init();

    final parseResult = await parseZip(zipPath);
    if (!parseResult.success) {
      return TaskCreateResult.error(parseResult.error!);
    }

    final taskId = _uuid.v4();
    final taskDir = '$_tasksDir/$taskId';
    await Directory(taskDir).create(recursive: true);

    // 保存工作流 JSON 文件
    final workflowFilePath = '$taskDir/workflow.json';
    await File(workflowFilePath).writeAsString(parseResult.workflowJson!);

    // 保存载荷和文档文件
    final fileEntries = <TaskFileEntry>[];

    for (final raw in parseResult.payloadFiles) {
      final filePath = '$taskDir/payloads/${raw.name}';
      await Directory('$taskDir/payloads').create(recursive: true);
      await File(filePath).writeAsBytes(raw.content);
      fileEntries.add(TaskFileEntry(
        id: _uuid.v4(),
        taskId: taskId,
        name: raw.name,
        type: 'payload',
        localPath: filePath,
        sizeBytes: raw.content.length,
      ));
    }

    for (final raw in parseResult.docFiles) {
      final filePath = '$taskDir/docs/${raw.name}';
      await Directory('$taskDir/docs').create(recursive: true);
      await File(filePath).writeAsBytes(raw.content);
      fileEntries.add(TaskFileEntry(
        id: _uuid.v4(),
        taskId: taskId,
        name: raw.name,
        type: 'doc',
        localPath: filePath,
        sizeBytes: raw.content.length,
      ));
    }

    final now = DateTime.now().toIso8601String();

    // 写入任务主表（完整字段）
    _db!.execute(
      '''INSERT INTO tasks
         (id, name, description, workflow_path, zip_path, workflow_json, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        taskId,
        name,
        description,
        workflowFilePath,   // 工作流文件路径
        zipPath,            // 原始压缩包路径
        parseResult.workflowJson!,
        now,
        now,
      ],
    );

    for (final f in fileEntries) {
      _db!.execute(
        'INSERT INTO task_files (id, task_id, name, type, local_path, size_bytes) VALUES (?, ?, ?, ?, ?, ?)',
        [f.id, f.taskId, f.name, f.type, f.localPath, f.sizeBytes],
      );
    }

    final task = TaskModel(
      id: taskId,
      name: name,
      description: description,
      workflowJson: parseResult.workflowJson!,
      workflowPath: workflowFilePath,
      zipPath: zipPath,
      files: fileEntries,
      createdAt: DateTime.parse(now),
    );

    return TaskCreateResult.success(task);
  }

  // ── 查询任务列表 ──────────────────────────────────────────────────────────

  Future<List<TaskModel>> listTasks() async {
    await init();

    final rows = _db!.select(
      'SELECT id, name, description, workflow_path, zip_path, workflow_json, created_at FROM tasks ORDER BY created_at DESC',
    );

    final tasks = <TaskModel>[];
    for (final row in rows) {
      final taskId = row['id'] as String;
      final files = _loadTaskFiles(taskId);
      tasks.add(TaskModel(
        id: taskId,
        name: row['name'] as String,
        description: row['description'] as String,
        workflowJson: row['workflow_json'] as String,
        workflowPath: row['workflow_path'] as String,
        zipPath: row['zip_path'] as String,
        files: files,
        createdAt: DateTime.parse(row['created_at'] as String),
      ));
    }
    return tasks;
  }

  List<TaskFileEntry> _loadTaskFiles(String taskId) {
    final rows = _db!.select(
      'SELECT id, task_id, name, type, local_path, size_bytes FROM task_files WHERE task_id = ?',
      [taskId],
    );
    return rows.map((r) => TaskFileEntry(
      id: r['id'] as String,
      taskId: r['task_id'] as String,
      name: r['name'] as String,
      type: r['type'] as String,
      localPath: r['local_path'] as String,
      sizeBytes: r['size_bytes'] as int,
    )).toList();
  }

  // ── 删除任务 ──────────────────────────────────────────────────────────────

  Future<void> deleteTask(String taskId) async {
    await init();

    final taskDir = '$_tasksDir/$taskId';
    final dir = Directory(taskDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }

    // CASCADE 自动删除 task_files 和 node_vm_binds（通过 task_id）
    _db!.execute('DELETE FROM tasks WHERE id = ?', [taskId]);
    // node_vm_binds 没有外键约束，手动清理
    _db!.execute('DELETE FROM node_vm_binds WHERE task_id = ?', [taskId]);
  }

  // ── 节点VM绑定持久化 ──────────────────────────────────────────────────────

  /// 保存节点VM绑定（upsert）
  void saveNodeVmBind({
    required String nodeId,
    required String vmId,
    required String vmName,
    required String vmIp,
    required String vmOsType,
    required String vmTag,
    required String vmBackend,
    String? taskId,
  }) {
    final now = DateTime.now().toIso8601String();
    _db!.execute('''
      INSERT INTO node_vm_binds
        (id, task_id, node_id, vm_id, vm_name, vm_ip, vm_os_type, vm_tag, vm_backend, bound_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(node_id) DO UPDATE SET
        vm_id      = excluded.vm_id,
        vm_name    = excluded.vm_name,
        vm_ip      = excluded.vm_ip,
        vm_os_type = excluded.vm_os_type,
        vm_tag     = excluded.vm_tag,
        vm_backend = excluded.vm_backend,
        bound_at   = excluded.bound_at
    ''', [
      _uuid.v4(),
      taskId ?? '',
      nodeId,
      vmId,
      vmName,
      vmIp,
      vmOsType,
      vmTag,
      vmBackend,
      now,
    ]);
  }

  /// 删除节点VM绑定
  void removeNodeVmBind(String nodeId) {
    _db!.execute('DELETE FROM node_vm_binds WHERE node_id = ?', [nodeId]);
  }

  /// 查询单个节点的VM绑定
  NodeVmBind? getNodeVmBind(String nodeId) {
    final rows = _db!.select(
      'SELECT * FROM node_vm_binds WHERE node_id = ?',
      [nodeId],
    );
    if (rows.isEmpty) return null;
    return NodeVmBind.fromRow(rows.first);
  }

  /// 查询任务下所有节点的VM绑定
  List<NodeVmBind> getTaskNodeVmBinds(String taskId) {
    final rows = _db!.select(
      'SELECT * FROM node_vm_binds WHERE task_id = ?',
      [taskId],
    );
    return rows.map((r) => NodeVmBind.fromRow(r)).toList();
  }

  /// 查询所有节点VM绑定（用于工作流加载时恢复）
  Map<String, NodeVmBind> getAllNodeVmBinds() {
    final rows = _db!.select('SELECT * FROM node_vm_binds');
    final result = <String, NodeVmBind>{};
    for (final r in rows) {
      final bind = NodeVmBind.fromRow(r);
      result[bind.nodeId] = bind;
    }
    return result;
  }

  void dispose() {
    _db?.dispose();
    _db = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 节点VM绑定数据类
// ─────────────────────────────────────────────────────────────────────────────

class NodeVmBind {
  final String id;
  final String? taskId;
  final String nodeId;
  final String vmId;
  final String vmName;
  final String vmIp;
  final String vmOsType;
  final String vmTag;
  final String vmBackend;
  final DateTime boundAt;

  const NodeVmBind({
    required this.id,
    this.taskId,
    required this.nodeId,
    required this.vmId,
    required this.vmName,
    required this.vmIp,
    required this.vmOsType,
    required this.vmTag,
    required this.vmBackend,
    required this.boundAt,
  });

  factory NodeVmBind.fromRow(Row row) => NodeVmBind(
    id: row['id'] as String,
    taskId: row['task_id'] as String?,
    nodeId: row['node_id'] as String,
    vmId: row['vm_id'] as String,
    vmName: row['vm_name'] as String,
    vmIp: row['vm_ip'] as String,
    vmOsType: row['vm_os_type'] as String,
    vmTag: row['vm_tag'] as String,
    vmBackend: row['vm_backend'] as String,
    boundAt: DateTime.parse(row['bound_at'] as String),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 辅助类
// ─────────────────────────────────────────────────────────────────────────────

class _RawFile {
  final String name;
  final List<int> content;
  _RawFile(this.name, this.content);
}

class TaskParseResult {
  final bool success;
  final String? error;
  final String? workflowJson;
  final List<_RawFile> payloadFiles;
  final List<_RawFile> docFiles;

  TaskParseResult._({
    required this.success,
    this.error,
    this.workflowJson,
    this.payloadFiles = const [],
    this.docFiles = const [],
  });

  factory TaskParseResult.error(String msg) =>
      TaskParseResult._(success: false, error: msg);

  factory TaskParseResult.success({
    required String workflowJson,
    required List<_RawFile> payloadFiles,
    required List<_RawFile> docFiles,
  }) => TaskParseResult._(
    success: true,
    workflowJson: workflowJson,
    payloadFiles: payloadFiles,
    docFiles: docFiles,
  );
}

class TaskCreateResult {
  final bool success;
  final String? error;
  final TaskModel? task;

  TaskCreateResult._({required this.success, this.error, this.task});

  factory TaskCreateResult.error(String msg) =>
      TaskCreateResult._(success: false, error: msg);

  factory TaskCreateResult.success(TaskModel task) =>
      TaskCreateResult._(success: true, task: task);
}
