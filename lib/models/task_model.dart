// ─────────────────────────────────────────────────────────────────────────────
// 任务数据模型
// ─────────────────────────────────────────────────────────────────────────────

/// 任务中的文件条目（载荷工具 / 工具文档）
class TaskFileEntry {
  final String id;
  final String taskId;
  final String name;       // 文件名
  final String type;       // 'payload' | 'doc'
  final String localPath;  // 解压后的本地绝对路径
  final int sizeBytes;

  const TaskFileEntry({
    required this.id,
    required this.taskId,
    required this.name,
    required this.type,
    required this.localPath,
    required this.sizeBytes,
  });

  String get icon {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'py':   return '🐍';
      case 'sh':   return '📜';
      case 'exe':  return '🔧';
      case 'elf':  return '⚙';
      case 'ps1':  return '💙';
      case 'dll':  return '🔩';
      case 'php':  return '🐘';
      case 'aspx': return '🌐';
      case 'bin':  return '📦';
      case 'md':   return '📝';
      case 'txt':  return '📄';
      default:     return '📄';
    }
  }

  String get sizeLabel {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }
}

/// 任务模型（完整字段）
class TaskModel {
  final String id;
  final String name;
  final String description;
  final String workflowJson;        // 工作流 JSON 字符串
  final String workflowPath;        // 工作流文件本地路径
  final String zipPath;             // 原始压缩包路径
  final List<TaskFileEntry> files;  // 所有文件（载荷 + 文档）
  final DateTime createdAt;

  const TaskModel({
    required this.id,
    required this.name,
    required this.description,
    required this.workflowJson,
    required this.workflowPath,
    required this.zipPath,
    required this.files,
    required this.createdAt,
  });

  List<TaskFileEntry> get payloads => files.where((f) => f.type == 'payload').toList();
  List<TaskFileEntry> get docs     => files.where((f) => f.type == 'doc').toList();

  TaskModel copyWith({
    String? name,
    String? description,
    String? workflowJson,
    List<TaskFileEntry>? files,
  }) => TaskModel(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    workflowJson: workflowJson ?? this.workflowJson,
    workflowPath: workflowPath,
    zipPath: zipPath,
    files: files ?? this.files,
    createdAt: createdAt,
  );
}
