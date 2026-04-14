import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/tool_model.dart';
import '../data/tools_data.dart';

class WorkflowProvider extends ChangeNotifier {
  List<WorkflowNode> _nodes = [];
  List<WorkflowConnection> _connections = [];
  String? _selectedNodeId;
  List<LogEntry> _logs = [];
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  String _targetDomain = 'corp.local';
  bool _isConnecting = false;
  String? _connectingFromNodeId;

  final _uuid = const Uuid();

  List<WorkflowNode> get nodes => _nodes;
  List<WorkflowConnection> get connections => _connections;
  String? get selectedNodeId => _selectedNodeId;
  List<LogEntry> get logs => _logs;
  double get scale => _scale;
  Offset get offset => _offset;
  String get targetDomain => _targetDomain;
  bool get isConnecting => _isConnecting;
  String? get connectingFromNodeId => _connectingFromNodeId;

  WorkflowNode? get selectedNode =>
      _selectedNodeId != null ? _nodes.where((n) => n.id == _selectedNodeId).firstOrNull : null;

  // ── Node Operations ──

  String addNode(String toolId, double x, double y) {
    final id = 'n${_uuid.v4().substring(0, 8)}';
    final node = WorkflowNode(id: id, toolId: toolId, x: x, y: y);
    _nodes.add(node);
    _selectedNodeId = id;
    final tool = kTools.where((t) => t.id == toolId).firstOrNull;
    addLog('info', '[${tool?.name ?? toolId}] 已添加到画布');
    notifyListeners();
    return id;
  }

  void updateNodePosition(String id, double x, double y) {
    final idx = _nodes.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _nodes[idx] = _nodes[idx].copyWith(x: x, y: y);
      notifyListeners();
    }
  }

  void deleteNode(String id) {
    _nodes.removeWhere((n) => n.id == id);
    _connections.removeWhere((c) => c.fromNodeId == id || c.toNodeId == id);
    if (_selectedNodeId == id) _selectedNodeId = null;
    addLog('warning', '节点已删除');
    notifyListeners();
  }

  void duplicateNode(String id) {
    final node = _nodes.where((n) => n.id == id).firstOrNull;
    if (node != null) {
      addNode(node.toolId, node.x + 20, node.y + 20);
    }
  }

  void selectNode(String? id) {
    _selectedNodeId = id;
    notifyListeners();
  }

  void setNodeVm(String nodeId, String? vmId) {
    final idx = _nodes.indexWhere((n) => n.id == nodeId);
    if (idx >= 0) {
      _nodes[idx] = _nodes[idx].copyWith(vmId: vmId);
      notifyListeners();
    }
  }

  void setNodePayload(String nodeId, String? payload, String? payloadPath) {
    final idx = _nodes.indexWhere((n) => n.id == nodeId);
    if (idx >= 0) {
      _nodes[idx] = WorkflowNode(
        id: _nodes[idx].id,
        toolId: _nodes[idx].toolId,
        x: _nodes[idx].x,
        y: _nodes[idx].y,
        vmId: _nodes[idx].vmId,
        payload: payload,
        payloadPath: payloadPath,
        status: _nodes[idx].status,
        notes: _nodes[idx].notes,
      );
      notifyListeners();
    }
  }

  void setNodeStatus(String nodeId, NodeStatus status) {
    final idx = _nodes.indexWhere((n) => n.id == nodeId);
    if (idx >= 0) {
      _nodes[idx] = _nodes[idx].copyWith(status: status);
      notifyListeners();
    }
  }

  // ── Connection Operations ──

  void startConnecting(String fromNodeId) {
    _isConnecting = true;
    _connectingFromNodeId = fromNodeId;
    notifyListeners();
  }

  void cancelConnecting() {
    _isConnecting = false;
    _connectingFromNodeId = null;
    notifyListeners();
  }

  bool addConnection(String fromNodeId, String toNodeId) {
    if (fromNodeId == toNodeId) return false;
    final exists = _connections.any(
      (c) => c.fromNodeId == fromNodeId && c.toNodeId == toNodeId,
    );
    if (exists) return false;

    final id = 'c${_uuid.v4().substring(0, 8)}';
    _connections.add(WorkflowConnection(id: id, fromNodeId: fromNodeId, toNodeId: toNodeId));
    _isConnecting = false;
    _connectingFromNodeId = null;

    final fromNode = _nodes.where((n) => n.id == fromNodeId).firstOrNull;
    final toNode = _nodes.where((n) => n.id == toNodeId).firstOrNull;
    final fromTool = fromNode != null ? kTools.where((t) => t.id == fromNode.toolId).firstOrNull : null;
    final toTool = toNode != null ? kTools.where((t) => t.id == toNode.toolId).firstOrNull : null;
    addLog('success', '连线: [${fromTool?.name ?? fromNodeId}] → [${toTool?.name ?? toNodeId}]');
    notifyListeners();
    return true;
  }

  void deleteConnection(String id) {
    _connections.removeWhere((c) => c.id == id);
    addLog('warning', '连线已删除');
    notifyListeners();
  }

  // ── Canvas Operations ──

  void setScale(double scale) {
    _scale = scale.clamp(0.1, 3.0);
    notifyListeners();
  }

  void setOffset(Offset offset) {
    _offset = offset;
    notifyListeners();
  }

  void fitView(Size canvasSize) {
    if (_nodes.isEmpty) {
      _scale = 1.0;
      _offset = Offset.zero;
      notifyListeners();
      return;
    }

    final xs = _nodes.map((n) => n.x).toList();
    final ys = _nodes.map((n) => n.y).toList();
    final minX = xs.reduce((a, b) => a < b ? a : b) - 20;
    final maxX = xs.reduce((a, b) => a > b ? a : b) + 240;
    final minY = ys.reduce((a, b) => a < b ? a : b) - 20;
    final maxY = ys.reduce((a, b) => a > b ? a : b) + 180;

    final scaleX = canvasSize.width / (maxX - minX);
    final scaleY = canvasSize.height / (maxY - minY);
    _scale = (scaleX < scaleY ? scaleX : scaleY) * 0.9;
    _scale = _scale.clamp(0.1, 3.0);

    _offset = Offset(
      (canvasSize.width - (maxX - minX) * _scale) / 2 - minX * _scale,
      (canvasSize.height - (maxY - minY) * _scale) / 2 - minY * _scale,
    );
    notifyListeners();
  }

  void autoLayout() {
    if (_nodes.isEmpty) return;

    // Simple auto layout: arrange nodes in a grid
    const colWidth = 280.0;
    const rowHeight = 180.0;
    const cols = 3;

    for (int i = 0; i < _nodes.length; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      _nodes[i] = _nodes[i].copyWith(
        x: 80.0 + col * colWidth,
        y: 80.0 + row * rowHeight,
      );
    }
    addLog('info', '已应用自动布局');
    notifyListeners();
  }

  void clearCanvas() {
    _nodes.clear();
    _connections.clear();
    _selectedNodeId = null;
    addLog('warning', '画布已清空');
    notifyListeners();
  }

  void setTargetDomain(String domain) {
    _targetDomain = domain;
    notifyListeners();
  }

  // ── Attack Chains ──

  void loadAttackChain(Map<String, dynamic> chain) {
    clearCanvas();
    final chainNodes = (chain['nodes'] as List).cast<Map<String, dynamic>>();
    final chainConns = (chain['connections'] as List).cast<Map<String, dynamic>>();

    final nodeIds = <String>[];
    for (final n in chainNodes) {
      final id = addNode(n['toolId'] as String, (n['x'] as num).toDouble(), (n['y'] as num).toDouble());
      nodeIds.add(id);
    }

    for (final c in chainConns) {
      final fromIdx = c['from'] as int;
      final toIdx = c['to'] as int;
      if (fromIdx < nodeIds.length && toIdx < nodeIds.length) {
        addConnection(nodeIds[fromIdx], nodeIds[toIdx]);
      }
    }

    addLog('success', '已加载攻击链: ${chain['name']}');
    notifyListeners();
  }

  // ── Logs ──

  void addLog(String type, String message) {
    _logs.insert(0, LogEntry(
      id: _uuid.v4(),
      type: type,
      message: message,
      timestamp: DateTime.now(),
    ));
    if (_logs.length > 200) _logs.removeLast();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  // ── Persistence ──

  Future<void> saveWorkflow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'nodes': _nodes.map((n) => n.toJson()).toList(),
        'connections': _connections.map((c) => c.toJson()).toList(),
        'targetDomain': _targetDomain,
      };
      await prefs.setString('workflow', jsonEncode(data));
      addLog('success', '工作流已保存');
      notifyListeners();
    } catch (e) {
      addLog('error', '保存失败: $e');
    }
  }

  Future<void> loadWorkflow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('workflow');
      if (json == null) {
        addLog('warning', '没有找到已保存的工作流');
        return;
      }
      final data = jsonDecode(json) as Map<String, dynamic>;
      _nodes = (data['nodes'] as List).map((n) => WorkflowNode.fromJson(n)).toList();
      _connections = (data['connections'] as List)
          .map((c) => WorkflowConnection.fromJson(c))
          .toList();
      _targetDomain = data['targetDomain'] ?? 'corp.local';
      _selectedNodeId = null;
      addLog('success', '工作流已加载 (${_nodes.length} 节点, ${_connections.length} 连线)');
      notifyListeners();
    } catch (e) {
      addLog('error', '加载失败: $e');
    }
  }

  String exportWorkflow() {
    final data = {
      'version': '1.0',
      'exportTime': DateTime.now().toIso8601String(),
      'targetDomain': _targetDomain,
      'nodes': _nodes.map((n) => n.toJson()).toList(),
      'connections': _connections.map((c) => c.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  void importWorkflow(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      _nodes = (data['nodes'] as List).map((n) => WorkflowNode.fromJson(n)).toList();
      _connections = (data['connections'] as List)
          .map((c) => WorkflowConnection.fromJson(c))
          .toList();
      _targetDomain = data['targetDomain'] ?? 'corp.local';
      _selectedNodeId = null;
      addLog('success', '工作流已导入 (${_nodes.length} 节点, ${_connections.length} 连线)');
      notifyListeners();
    } catch (e) {
      addLog('error', '导入失败: $e');
    }
  }
}
