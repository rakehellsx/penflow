import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tool_model.dart';
import '../data/tools_data.dart';
import '../providers/workflow_provider.dart';
import '../utils/app_theme.dart';

class NodeCard extends StatefulWidget {
  final WorkflowNode node;
  final bool isSelected;
  final bool isConnecting;
  final VoidCallback onTap;
  final Function(Offset delta) onMove;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onOpenVMPanel;
  final Function(String nodeId) onPortDragStart;
  final Function(String targetNodeId) onPortDrop;
  final VoidCallback onEnterVM;

  const NodeCard({
    super.key,
    required this.node,
    required this.isSelected,
    required this.isConnecting,
    required this.onTap,
    required this.onMove,
    required this.onDelete,
    required this.onDuplicate,
    required this.onOpenVMPanel,
    required this.onPortDragStart,
    required this.onPortDrop,
    required this.onEnterVM,
  });

  @override
  State<NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends State<NodeCard> {
  bool _hovered = false;

  ToolDefinition? get _tool =>
      kTools.where((t) => t.id == widget.node.toolId).firstOrNull;
  ToolCategory? get _cat =>
      _tool != null ? kCategories[_tool!.catId] : null;
  VirtualMachine? get _vm =>
      widget.node.vmId != null
          ? kVirtualMachines.where((v) => v.id == widget.node.vmId).firstOrNull
          : null;

  @override
  Widget build(BuildContext context) {
    final tool = _tool;
    final cat  = _cat;
    if (tool == null || cat == null) return const SizedBox.shrink();
    final t = context.appTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 230,
          decoration: BoxDecoration(
            color: t.node,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? AppAccent.blue
                  : (_hovered ? t.borderHi : t.border),
              width: widget.isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (t.isDark ? Colors.black : Colors.grey.shade400)
                    .withOpacity(widget.isSelected ? 0.6 : 0.3),
                blurRadius: widget.isSelected ? 22 : 12,
                offset: const Offset(0, 3),
              ),
              if (widget.isSelected)
                BoxShadow(
                  color: AppAccent.blue.withOpacity(0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(tool, cat, t),
              _buildBody(t),
              _buildFooter(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ToolDefinition tool, ToolCategory cat, AppThemeData t) {
    return GestureDetector(
      onPanUpdate: (details) => widget.onMove(details.delta),
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
          decoration: BoxDecoration(
            color: cat.color.withOpacity(t.isDark ? 0.16 : 0.10),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: cat.color.withOpacity(0.25),
                ),
                alignment: Alignment.center,
                child: Text(tool.icon, style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tool.name,
                  style: TextStyle(
                    color: t.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: cat.color.withOpacity(0.17),
                ),
                child: Text(
                  cat.label,
                  style: TextStyle(
                    color: cat.color,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _StatusDot(status: widget.node.status),
              const SizedBox(width: 4),
              _IconBtn(icon: '✕', hoverColor: AppAccent.red, onTap: widget.onDelete),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.all(9),
      child: Column(
        children: [
          _VmSelector(vm: _vm, onTap: widget.onOpenVMPanel),
          const SizedBox(height: 6),
          _PayloadSelector(
            payload: widget.node.payload,
            onTap: () => _showPayloadDialog(context),
            onClear: () {
              context.read<WorkflowProvider>()
                  .setNodePayload(widget.node.id, null, null);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _EnterVmButton(
              hasVm: widget.node.vmId != null,
              onTap: widget.onEnterVM,
            ),
          ),
          const SizedBox(width: 5),
          _DupButton(onTap: widget.onDuplicate),
          const SizedBox(width: 5),
          _OutPort(nodeId: widget.node.id, onDragStart: widget.onPortDragStart),
        ],
      ),
    );
  }

  void _showPayloadDialog(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _PayloadDialog(
        nodeId: widget.node.id,
        currentPayload: widget.node.payload,
      ),
    );
    if (result != null && context.mounted) {
      // 兼容 Windows (\) 和 Linux (/) 路径分隔符
      final sep = Platform.pathSeparator;
      final fileName = result.split(sep).last;
      context.read<WorkflowProvider>()
          .setNodePayload(widget.node.id, fileName, result);
    }
  }
}

// ── Sub-widgets ──────────────────────────────

class _StatusDot extends StatelessWidget {
  final NodeStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case NodeStatus.running: color = AppAccent.yellow; break;
      case NodeStatus.done:    color = AppAccent.green;  break;
      case NodeStatus.error:   color = AppAccent.red;    break;
      default:                 color = context.appTheme.text3;
    }
    return Container(
      width: 6, height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle, color: color,
        boxShadow: status != NodeStatus.idle
            ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 4)]
            : null,
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  final String icon;
  final Color hoverColor;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.hoverColor, required this.onTap});

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 15, height: 15,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: _hovered ? widget.hoverColor : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(widget.icon,
              style: TextStyle(
                  color: _hovered ? Colors.white : t.text3, fontSize: 10)),
        ),
      ),
    );
  }
}

class _VmSelector extends StatefulWidget {
  final VirtualMachine? vm;
  final VoidCallback onTap;
  const _VmSelector({this.vm, required this.onTap});

  @override
  State<_VmSelector> createState() => _VmSelectorState();
}

class _VmSelectorState extends State<_VmSelector> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final hasVm = widget.vm != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: _hovered ? AppAccent.blue : t.border),
            color: t.bg,
          ),
          child: Row(
            children: [
              Text(hasVm ? widget.vm!.icon : '🖥',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasVm
                      ? '${widget.vm!.name} · ${widget.vm!.ip}'
                      : '选择目标虚拟机...',
                  style: TextStyle(
                    color: hasVm
                        ? (_hovered ? AppAccent.blue : t.text2)
                        : t.text3,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasVm)
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.vm!.statusColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayloadSelector extends StatefulWidget {
  final String? payload;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _PayloadSelector(
      {this.payload, required this.onTap, required this.onClear});

  @override
  State<_PayloadSelector> createState() => _PayloadSelectorState();
}

class _PayloadSelectorState extends State<_PayloadSelector> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final hasPayload = widget.payload != null;
    return Row(
      children: [
        Expanded(
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit:  (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _hovered ? AppAccent.orange : t.border,
                  ),
                  color: t.bg,
                ),
                child: Row(
                  children: [
                    const Text('📁', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hasPayload
                            ? widget.payload!
                            : '从平台文件系统选择载荷...',
                        style: TextStyle(
                          color: hasPayload
                              ? (_hovered ? AppAccent.orange : t.text2)
                              : t.text3,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasPayload) ...[
          const SizedBox(width: 4),
          _IconBtn(
              icon: '✕', hoverColor: AppAccent.red, onTap: widget.onClear),
        ],
      ],
    );
  }
}

class _EnterVmButton extends StatefulWidget {
  final bool hasVm;
  final VoidCallback onTap;
  const _EnterVmButton({required this.hasVm, required this.onTap});

  @override
  State<_EnterVmButton> createState() => _EnterVmButtonState();
}

class _EnterVmButtonState extends State<_EnterVmButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: widget.hasVm
                  ? (_hovered
                      ? AppAccent.blue
                      : AppAccent.blue.withOpacity(0.5))
                  : context.appTheme.text3,
            ),
            color: widget.hasVm && _hovered
                ? AppAccent.blue.withOpacity(0.2)
                : AppAccent.blue.withOpacity(0.08),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🖥', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 4),
              Text(
                '进入虚拟机',
                style: TextStyle(
                  color: widget.hasVm
                      ? AppAccent.blue
                      : context.appTheme.text3,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DupButton extends StatefulWidget {
  final VoidCallback onTap;
  const _DupButton({required this.onTap});

  @override
  State<_DupButton> createState() => _DupButtonState();
}

class _DupButtonState extends State<_DupButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
                color: _hovered ? AppAccent.blue : t.border),
          ),
          child: Text('⧉',
              style: TextStyle(
                  color: _hovered ? AppAccent.blue : t.text3,
                  fontSize: 10)),
        ),
      ),
    );
  }
}

class _OutPort extends StatefulWidget {
  final String nodeId;
  final Function(String nodeId) onDragStart;
  const _OutPort({required this.nodeId, required this.onDragStart});

  @override
  State<_OutPort> createState() => _OutPortState();
}

class _OutPortState extends State<_OutPort> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onDragStart(widget.nodeId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 14, height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hovered ? AppAccent.blue : t.bg,
            border: Border.all(
              color: _hovered ? AppAccent.blue : t.border,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}


// ── Payload Dialog ────────────────────────────
// 对接本地真实文件系统，默认路径为桌面

class _PayloadDialog extends StatefulWidget {
  final String nodeId;
  final String? currentPayload;
  const _PayloadDialog({required this.nodeId, this.currentPayload});

  @override
  State<_PayloadDialog> createState() => _PayloadDialogState();
}

class _PayloadDialogState extends State<_PayloadDialog> {
  late String _currentPath;
  String? _selectedFilePath;  // 完整路径
  String? _selectedFileName;  // 文件名
  List<FileSystemEntity> _dirs = [];
  List<FileSystemEntity> _files = [];
  bool _loading = false;
  String? _error;
  final TextEditingController _pathCtrl = TextEditingController();

  // 快捷入口
  late List<_QuickEntry> _quickEntries;

  @override
  void initState() {
    super.initState();
    _currentPath = _getDesktopPath();
    _pathCtrl.text = _currentPath;
    _loadDir(_currentPath);
    _quickEntries = _buildQuickEntries();
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  /// 获取桌面路径（跨平台）
  static String _getDesktopPath() {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\User';
      return '$userProfile\\Desktop';
    } else {
      final home = Platform.environment['HOME'] ?? '/root';
      return '$home/Desktop';
    }
  }

  /// 构建快捷入口列表
  List<_QuickEntry> _buildQuickEntries() {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\User';
      return [
        _QuickEntry('🖥', '桌面', '$userProfile\\Desktop'),
        _QuickEntry('🏠', '主目录', userProfile),
        _QuickEntry('📥', 'Downloads', '$userProfile\\Downloads'),
        _QuickEntry('📄', 'Documents', '$userProfile\\Documents'),
        _QuickEntry('💾', 'C:\\', 'C:\\'),
      ];
    } else {
      final home = Platform.environment['HOME'] ?? '/root';
      return [
        _QuickEntry('🖥', '桌面', '$home/Desktop'),
        _QuickEntry('🏠', '主目录', home),
        _QuickEntry('📥', 'Downloads', '$home/Downloads'),
        _QuickEntry('📄', 'Documents', '$home/Documents'),
        _QuickEntry('💾', '根目录', '/'),
        _QuickEntry('🔧', '/opt', '/opt'),
        _QuickEntry('📦', '/tmp', '/tmp'),
      ];
    }
  }

  /// 加载目录内容
  Future<void> _loadDir(String path) async {
    setState(() { _loading = true; _error = null; });
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        setState(() { _error = '目录不存在: $path'; _loading = false; });
        return;
      }
      final entities = await dir.list(followLinks: false).toList();
      entities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return a.path.split(Platform.pathSeparator).last
            .toLowerCase()
            .compareTo(b.path.split(Platform.pathSeparator).last.toLowerCase());
      });
      setState(() {
        _dirs = entities.whereType<Directory>().toList();
        _files = entities.whereType<File>().toList();
        _loading = false;
        _selectedFilePath = null;
        _selectedFileName = null;
      });
    } catch (e) {
      setState(() { _error = '无法读取目录: $e'; _loading = false; });
    }
  }

  void _navigateTo(String path) {
    setState(() { _currentPath = path; });
    _pathCtrl.text = path;
    _loadDir(path);
  }

  void _navigateUp() {
    final sep = Platform.pathSeparator;
    final parts = _currentPath.split(sep);
    if (parts.length <= 1) return;
    parts.removeLast();
    if (parts.isEmpty || (parts.length == 1 && parts[0].isEmpty)) {
      _navigateTo('/');
    } else {
      _navigateTo(parts.join(sep));
    }
  }

  String _basename(String path) =>
      path.split(Platform.pathSeparator).last;

  String _fileIcon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'py': return '🐍';
      case 'sh': return '📜';
      case 'exe': case 'elf': return '⚙️';
      case 'ps1': return '🔷';
      case 'rb': return '💎';
      case 'pl': return '🐪';
      case 'jar': return '☕';
      case 'zip': case 'tar': case 'gz': case '7z': return '📦';
      case 'txt': case 'md': return '📄';
      case 'json': case 'yaml': case 'yml': return '📋';
      case 'pdf': return '📕';
      case 'png': case 'jpg': case 'jpeg': case 'gif': return '🖼';
      default: return '📄';
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Dialog(
      backgroundColor: t.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: 760, height: 560,
        child: Column(
          children: [
            _buildHeader(t),
            _buildAddressBar(t),
            Expanded(
              child: Row(
                children: [
                  // 左侧快捷入口
                  SizedBox(
                    width: 160,
                    child: _buildQuickPanel(t),
                  ),
                  Container(width: 1, color: t.border),
                  // 右侧文件列表
                  Expanded(child: _buildFileList(t)),
                ],
              ),
            ),
            _buildFooter(context, t),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          const Text('📁', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text('选择载荷文件',
              style: TextStyle(
                  color: t.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close, color: t.text3, size: 16),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressBar(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
        color: t.bg,
      ),
      child: Row(
        children: [
          // 返回上级
          _NavBtn(
            icon: Icons.arrow_upward,
            tooltip: '返回上级',
            onTap: _navigateUp,
            t: t,
          ),
          const SizedBox(width: 6),
          // 刷新
          _NavBtn(
            icon: Icons.refresh,
            tooltip: '刷新',
            onTap: () => _loadDir(_currentPath),
            t: t,
          ),
          const SizedBox(width: 8),
          // 路径输入框
          Expanded(
            child: TextField(
              controller: _pathCtrl,
              style: TextStyle(color: t.text, fontSize: 11),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                filled: true,
                fillColor: t.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: t.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: AppAccent.blue),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: t.border),
                ),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) _navigateTo(v.trim());
              },
            ),
          ),
          const SizedBox(width: 6),
          // 跳转按钮
          ElevatedButton(
            onPressed: () {
              final v = _pathCtrl.text.trim();
              if (v.isNotEmpty) _navigateTo(v);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppAccent.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              textStyle: const TextStyle(fontSize: 11),
            ),
            child: const Text('跳转'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPanel(AppThemeData t) {
    return Container(
      color: t.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Text('快捷入口',
                style: TextStyle(
                    color: t.text3, fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
          ),
          ..._quickEntries.map((e) => _QuickEntryItem(
            entry: e,
            isActive: _currentPath == e.path,
            onTap: () => _navigateTo(e.path),
            t: t,
          )),
        ],
      ),
    );
  }

  Widget _buildFileList(AppThemeData t) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppAccent.blue),
            ),
            const SizedBox(height: 8),
            Text('加载中...', style: TextStyle(color: t.text3, fontSize: 11)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: AppAccent.red, fontSize: 11),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _navigateTo(_getDesktopPath()),
              child: Text('返回桌面',
                  style: TextStyle(color: AppAccent.blue, fontSize: 11)),
            ),
          ],
        ),
      );
    }
    if (_dirs.isEmpty && _files.isEmpty) {
      return Center(
        child: Text('该目录为空',
            style: TextStyle(color: t.text3, fontSize: 11)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        // 目录列表
        ..._dirs.map((d) {
          final name = _basename(d.path);
          return _RealFsItem(
            icon: '📁',
            name: name,
            subtitle: '目录',
            isSelected: false,
            isDir: true,
            onTap: () => _navigateTo(d.path),
            t: t,
          );
        }),
        // 文件列表
        ..._files.map((f) {
          final name = _basename(f.path);
          final file = f as File;
          String size = '';
          try {
            size = _formatSize(file.lengthSync());
          } catch (_) {}
          final isSelected = _selectedFilePath == f.path;
          return _RealFsItem(
            icon: _fileIcon(name),
            name: name,
            subtitle: size,
            isSelected: isSelected,
            isDir: false,
            onTap: () => setState(() {
              _selectedFilePath = f.path;
              _selectedFileName = name;
            }),
            t: t,
          );
        }),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, AppThemeData t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _selectedFileName != null
                  ? '已选择: $_selectedFileName'
                  : '未选择文件',
              style: TextStyle(
                  color: _selectedFileName != null ? t.text2 : t.text3,
                  fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消',
                style: TextStyle(color: t.text2, fontSize: 11)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _selectedFilePath != null
                ? () => Navigator.pop(context, _selectedFilePath)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppAccent.blue,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(fontSize: 11),
            ),
            child: const Text('确认选择'),
          ),
        ],
      ),
    );
  }
}

// ── 快捷入口数据模型 ──────────────────────────

class _QuickEntry {
  final String icon;
  final String label;
  final String path;
  const _QuickEntry(this.icon, this.label, this.path);
}

// ── 快捷入口列表项 ────────────────────────────

class _QuickEntryItem extends StatefulWidget {
  final _QuickEntry entry;
  final bool isActive;
  final VoidCallback onTap;
  final AppThemeData t;
  const _QuickEntryItem({
    required this.entry, required this.isActive,
    required this.onTap, required this.t,
  });

  @override
  State<_QuickEntryItem> createState() => _QuickEntryItemState();
}

class _QuickEntryItemState extends State<_QuickEntryItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: widget.isActive
              ? AppAccent.blue.withOpacity(0.15)
              : (_hovered ? t.card : Colors.transparent),
          child: Row(
            children: [
              Text(widget.entry.icon,
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.entry.label,
                    style: TextStyle(
                      color: widget.isActive ? AppAccent.blue : t.text2,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 真实文件系统列表项 ────────────────────────

class _RealFsItem extends StatefulWidget {
  final String icon;
  final String name;
  final String subtitle;
  final bool isSelected;
  final bool isDir;
  final VoidCallback onTap;
  final AppThemeData t;
  const _RealFsItem({
    required this.icon, required this.name, required this.subtitle,
    required this.isSelected, required this.isDir,
    required this.onTap, required this.t,
  });

  @override
  State<_RealFsItem> createState() => _RealFsItemState();
}

class _RealFsItemState extends State<_RealFsItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: widget.isDir
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: widget.isSelected
                ? AppAccent.blue.withOpacity(0.15)
                : (_hovered
                    ? (widget.isDir
                        ? AppAccent.blue.withOpacity(0.08)
                        : t.card)
                    : Colors.transparent),
            border: Border.all(
              color: widget.isSelected
                  ? AppAccent.blue.withOpacity(0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Text(widget.icon,
                  style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name,
                        style: TextStyle(
                          color: widget.isSelected
                              ? AppAccent.blue
                              : (widget.isDir ? t.text : t.text),
                          fontSize: 11,
                          fontWeight: widget.isDir
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis),
                    if (widget.subtitle.isNotEmpty)
                      Text(widget.subtitle,
                          style: TextStyle(
                              color: t.text3, fontSize: 10)),
                  ],
                ),
              ),
              if (widget.isDir)
                Icon(Icons.chevron_right,
                    color: t.text3, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 导航按钮 ──────────────────────────────────

class _NavBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final AppThemeData t;
  const _NavBtn({
    required this.icon, required this.tooltip,
    required this.onTap, required this.t,
  });

  @override
  State<_NavBtn> createState() => _NavBtnState();
}

class _NavBtnState extends State<_NavBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 26, height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: _hovered
                  ? AppAccent.blue.withOpacity(0.15)
                  : Colors.transparent,
              border: Border.all(
                  color: _hovered ? AppAccent.blue : t.border),
            ),
            child: Icon(widget.icon,
                color: _hovered ? AppAccent.blue : t.text3,
                size: 14),
          ),
        ),
      ),
    );
  }
}
