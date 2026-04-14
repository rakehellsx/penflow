import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';
import 'workflow_provider.dart';
import 'tool_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 任务状态管理 Provider
// ─────────────────────────────────────────────────────────────────────────────

enum TaskStatus { idle, loading, error }

class TaskProvider extends ChangeNotifier {
  final TaskService _service = TaskService();

  List<TaskModel> _tasks = [];
  TaskModel? _activeTask;
  TaskStatus _status = TaskStatus.idle;
  String? _error;
  bool _initialized = false;

  List<TaskModel> get tasks       => _tasks;
  TaskModel?      get activeTask  => _activeTask;
  TaskStatus      get status      => _status;
  String?         get error       => _error;
  bool            get isLoading   => _status == TaskStatus.loading;

  // ── 初始化 ────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadTasks();
  }

  Future<void> _loadTasks() async {
    _status = TaskStatus.loading;
    notifyListeners();
    try {
      _tasks = await _service.listTasks();
      _status = TaskStatus.idle;
      _error  = null;
    } catch (e) {
      _status = TaskStatus.error;
      _error  = e.toString();
    }
    notifyListeners();
  }

  // ── 创建任务 ──────────────────────────────────────────────────────────────

  Future<TaskCreateResult?> createTask({
    required String name,
    required String description,
    required String zipPath,
    required WorkflowProvider workflowProvider,
    required ToolProvider toolProvider,
  }) async {
    _status = TaskStatus.loading;
    notifyListeners();

    final result = await _service.createTask(
      name: name,
      description: description,
      zipPath: zipPath,
    );

    if (result.success && result.task != null) {
      _tasks.insert(0, result.task!);
      _status = TaskStatus.idle;
      notifyListeners();
      // 自动加载新建任务的工作流，并持久化工具到 ToolDatabase
      await activateTask(result.task!, workflowProvider, toolProvider);
    } else {
      _status = TaskStatus.error;
      _error  = result.error;
      notifyListeners();
    }

    return result;
  }

  // ── 激活任务（加载工作流 + 持久化工具/文档到 ToolDatabase） ───────────────

  Future<void> activateTask(
    TaskModel task,
    WorkflowProvider workflowProvider,
    ToolProvider toolProvider,
  ) async {
    _activeTask = task;
    notifyListeners();

    // 0. 设置当前激活任务 ID（用于节点VM绑定关联）
    workflowProvider.setActiveTask(task.id);

    // 1. 将工作流 JSON 注入到画布
    workflowProvider.importWorkflow(task.workflowJson);

    // 2. 确保任务分类存在于 ToolDatabase
    final db = toolProvider.database;
    final existingCats = db.getCategoriesByTask(task.id);
    String catId;
    if (existingCats.isEmpty) {
      catId = await toolProvider.addCategory(
        label: '📋 ${task.name}',
        icon: '📋',
        colorHex: '#6C8EBF',
        taskId: task.id,
      );
    } else {
      catId = existingCats.first.id;
    }

    // 3. 将文档文件持久化到 ToolDatabase（避免重复写入）
    final existingDocs = db.getDocsByTask(task.id);
    final existingDocNames = existingDocs.map((d) => d.name).toSet();
    for (final doc in task.docs) {
      if (!existingDocNames.contains(doc.name)) {
        await toolProvider.addDocFromBytes(
          fileName: doc.name,
          bytes: await _readFileBytes(doc.localPath),
          taskId: task.id,
        );
      }
      // 同时在 tools 表中创建对应工具条目（供工具箱展示）
      final toolId = 'task_doc_${task.id}_${doc.id}';
      final existing = db.getToolById(toolId);
      if (existing == null) {
        await toolProvider.addTool(
          name: doc.name.replaceAll(RegExp(r'\.(md|txt|rst)$'), ''),
          desc: '任务文档 · ${task.name}',
          icon: '📝',
          catId: catId,
          usage: await _readFileText(doc.localPath),
          tags: ['任务文档', task.name],
          version: '-',
          platform: '-',
          taskId: task.id,
        );
      }
    }

    // 4. 将载荷文件持久化到 ToolDatabase（避免重复写入）
    final existingPayloads = db.getPayloadsByTask(task.id);
    final existingPayloadNames = existingPayloads.map((p) => p.name).toSet();
    for (final payload in task.payloads) {
      if (!existingPayloadNames.contains(payload.name)) {
        await toolProvider.addPayloadFromBytes(
          fileName: payload.name,
          bytes: await _readFileBytes(payload.localPath),
          taskId: task.id,
        );
      }
      // 同时在 tools 表中创建对应工具条目
      final toolId = 'task_payload_${task.id}_${payload.id}';
      final existing = db.getToolById(toolId);
      if (existing == null) {
        await toolProvider.addTool(
          name: payload.name,
          desc: '载荷工具 · ${payload.sizeLabel}',
          icon: payload.icon,
          catId: catId,
          usage: '## ${payload.name}\n\n**类型**: 载荷工具\n**路径**: `${payload.localPath}`\n**大小**: ${payload.sizeLabel}',
          tags: ['载荷', task.name],
          version: '-',
          platform: '-',
          taskId: task.id,
        );
      }
    }

    // 5. 刷新 ToolProvider（确保 UI 更新）
    await toolProvider.refresh();

    workflowProvider.addLog(
      'success',
      '已加载任务: ${task.name} (${task.payloads.length} 个载荷, ${task.docs.length} 个文档)',
    );
  }

  // ── 删除任务 ──────────────────────────────────────────────────────────────

  Future<void> deleteTask(
    String taskId,
    WorkflowProvider workflowProvider,
    ToolProvider toolProvider,
  ) async {
    await _service.deleteTask(taskId);
    // 同步清理 ToolDatabase 中的任务工具
    await toolProvider.deleteByTask(taskId);
    _tasks.removeWhere((t) => t.id == taskId);

    if (_activeTask?.id == taskId) {
      _activeTask = null;
      workflowProvider.clearTaskTools(taskId);
    }

    notifyListeners();
  }

  // ── 选择压缩包文件 ────────────────────────────────────────────────────────

  Future<String?> pickZipFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: '选择任务压缩包',
    );
    return result?.files.single.path;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── 辅助方法 ──────────────────────────────────────────────────────────────

  Future<List<int>> _readFileBytes(String path) async {
    try {
      return await _service.readFileBytes(path);
    } catch (_) {
      return [];
    }
  }

  Future<String> _readFileText(String path) async {
    try {
      return await _service.readFileText(path);
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
