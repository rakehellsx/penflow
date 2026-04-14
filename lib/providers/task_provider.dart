import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/task_model.dart';
import '../models/tool_model.dart';
import '../services/task_service.dart';
import 'workflow_provider.dart';

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

  /// 弹出文件选择器选择压缩包，然后创建任务
  Future<TaskCreateResult?> createTask({
    required String name,
    required String description,
    required String zipPath,
    required WorkflowProvider workflowProvider,
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
      // 自动加载新建任务的工作流
      await activateTask(result.task!, workflowProvider);
    } else {
      _status = TaskStatus.error;
      _error  = result.error;
      notifyListeners();
    }

    return result;
  }

  // ── 激活任务（加载工作流 + 注入工具/文档） ────────────────────────────────

  Future<void> activateTask(TaskModel task, WorkflowProvider workflowProvider) async {
    _activeTask = task;
    notifyListeners();

    // 0. 设置当前激活任务 ID（用于节点VM绑定关联）
    workflowProvider.setActiveTask(task.id);

    // 1. 将工作流 JSON 注入到画布
    workflowProvider.importWorkflow(task.workflowJson);

    // 2. 将任务文档注入为动态工具
    final extraTools = <ToolDefinition>[];
    for (final doc in task.docs) {
      String docContent = '';
      try {
        docContent = await File(doc.localPath).readAsString();
      } catch (_) {
        docContent = '# ${doc.name}\n\n文档内容无法读取';
      }

      // 从文件名推断工具名（去掉扩展名）
      final toolName = doc.name.replaceAll(RegExp(r'\.(md|txt)$'), '');
      final toolId = 'task_doc_${task.id}_${doc.id}';

      extraTools.add(ToolDefinition(
        id: toolId,
        name: toolName,
        desc: '任务文档: ${task.name}',
        icon: '📝',
        catId: 'task_${task.id}',
        usage: docContent,
        tags: ['任务文档', task.name],
        version: '-',
        platform: '-',
        risk: RiskLevel.none,
      ));
    }

    // 3. 将载荷文件注入为工具（可在节点载荷选择中使用）
    for (final payload in task.payloads) {
      final toolId = 'task_payload_${task.id}_${payload.id}';
      extraTools.add(ToolDefinition(
        id: toolId,
        name: payload.name,
        desc: '载荷工具: ${payload.sizeLabel}',
        icon: payload.icon,
        catId: 'task_${task.id}',
        usage: '## ${payload.name}\n\n**类型**: 载荷工具\n**路径**: `${payload.localPath}`\n**大小**: ${payload.sizeLabel}',
        tags: ['载荷', task.name],
        version: '-',
        platform: '-',
        risk: RiskLevel.high,
      ));
    }

    // 4. 注入任务分类和工具到 WorkflowProvider
    workflowProvider.injectTaskTools(
      taskId: task.id,
      taskName: task.name,
      tools: extraTools,
      payloadFiles: task.payloads,
    );

    workflowProvider.addLog('success', '已加载任务: ${task.name} (${task.payloads.length} 个载荷, ${task.docs.length} 个文档)');
  }

  // ── 删除任务 ──────────────────────────────────────────────────────────────

  Future<void> deleteTask(String taskId, WorkflowProvider workflowProvider) async {
    await _service.deleteTask(taskId);
    _tasks.removeWhere((t) => t.id == taskId);

    // 如果删除的是当前激活任务，清除注入的工具
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

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
