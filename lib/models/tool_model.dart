import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

enum RiskLevel { none, low, medium, high, critical }
enum NodeStatus { idle, running, done, error }

extension RiskLevelExt on RiskLevel {
  Color get color {
    switch (this) {
      case RiskLevel.critical: return AppColors.riskCritical;
      case RiskLevel.high: return AppColors.riskHigh;
      case RiskLevel.medium: return AppColors.riskMedium;
      case RiskLevel.low: return AppColors.riskLow;
      case RiskLevel.none: return AppColors.riskNone;
    }
  }

  String get label {
    switch (this) {
      case RiskLevel.critical: return '极危';
      case RiskLevel.high: return '高危';
      case RiskLevel.medium: return '中危';
      case RiskLevel.low: return '低危';
      case RiskLevel.none: return '无风险';
    }
  }
}

class ToolCategory {
  final String id;
  final String label;
  final String icon;
  final Color color;

  const ToolCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class ToolDefinition {
  final String id;
  final String name;
  final String desc;
  final String icon;
  final String catId;
  final String usage;
  final List<String> tags;
  final String version;
  final String platform;
  final RiskLevel risk;
  final bool isBuiltin;

  const ToolDefinition({
    required this.id,
    required this.name,
    required this.desc,
    required this.icon,
    required this.catId,
    required this.usage,
    required this.tags,
    required this.version,
    required this.platform,
    required this.risk,
    this.isBuiltin = true,
  });
}

class VirtualMachine {
  final String id;
  final String name;
  final String ip;
  final String osType; // 'linux' | 'windows'
  final String status; // 'on' | 'off' | 'busy'
  final String icon;
  final String tag;

  const VirtualMachine({
    required this.id,
    required this.name,
    required this.ip,
    required this.osType,
    required this.status,
    required this.icon,
    required this.tag,
  });

  Color get statusColor {
    switch (status) {
      case 'on': return AppColors.green;
      case 'busy': return AppColors.yellow;
      default: return AppColors.text3;
    }
  }
}

class PlatformFile {
  final String name;
  final String size;
  final String type;
  final String date;

  const PlatformFile({
    required this.name,
    required this.size,
    required this.type,
    required this.date,
  });

  String get icon {
    switch (type) {
      case 'exe': return '🔧';
      case 'elf': return '⚙';
      case 'py': return '🐍';
      case 'ps1': return '💙';
      case 'sh': return '📜';
      case 'php': return '🐘';
      case 'aspx': return '🌐';
      case 'dll': return '🔩';
      case 'txt': return '📄';
      case 'bin': return '📦';
      case 'zip': return '🗜';
      default: return '📄';
    }
  }
}

class WorkflowNode {
  String id;
  String toolId;
  double x;
  double y;
  String? vmId;
  String? payload;
  String? payloadPath;
  NodeStatus status;
  String? notes;

  WorkflowNode({
    required this.id,
    required this.toolId,
    required this.x,
    required this.y,
    this.vmId,
    this.payload,
    this.payloadPath,
    this.status = NodeStatus.idle,
    this.notes,
  });

  WorkflowNode copyWith({
    String? id,
    String? toolId,
    double? x,
    double? y,
    String? vmId,
    String? payload,
    String? payloadPath,
    NodeStatus? status,
    String? notes,
  }) {
    return WorkflowNode(
      id: id ?? this.id,
      toolId: toolId ?? this.toolId,
      x: x ?? this.x,
      y: y ?? this.y,
      vmId: vmId ?? this.vmId,
      payload: payload ?? this.payload,
      payloadPath: payloadPath ?? this.payloadPath,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'toolId': toolId,
    'x': x,
    'y': y,
    'vmId': vmId,
    'payload': payload,
    'payloadPath': payloadPath,
    'status': status.index,
    'notes': notes,
  };

  factory WorkflowNode.fromJson(Map<String, dynamic> json) => WorkflowNode(
    id: json['id'],
    toolId: json['toolId'],
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    vmId: json['vmId'],
    payload: json['payload'],
    payloadPath: json['payloadPath'],
    status: NodeStatus.values[json['status'] ?? 0],
    notes: json['notes'],
  );
}

class WorkflowConnection {
  final String id;
  final String fromNodeId;
  final String toNodeId;

  const WorkflowConnection({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromNodeId': fromNodeId,
    'toNodeId': toNodeId,
  };

  factory WorkflowConnection.fromJson(Map<String, dynamic> json) => WorkflowConnection(
    id: json['id'],
    fromNodeId: json['fromNodeId'],
    toNodeId: json['toNodeId'],
  );
}

class LogEntry {
  final String id;
  final String type; // 'info' | 'success' | 'warning' | 'error'
  final String message;
  final DateTime timestamp;

  LogEntry({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
  });

  Color get color {
    switch (type) {
      case 'success': return AppColors.green;
      case 'warning': return AppColors.orange;
      case 'error': return AppColors.red;
      default: return AppColors.text2;
    }
  }
}

/// 任务动态分类（用于 WorkflowProvider 注入）
class TaskCategory {
  final String id;
  final String label;

  const TaskCategory({required this.id, required this.label});

  ToolCategory toToolCategory() => ToolCategory(
    id: id,
    label: label,
    icon: '📋',
    color: const Color(0xFF6C8EBF),
  );
}
