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
    final cat = _cat;
    if (tool == null || cat == null) return const SizedBox.shrink();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 230,
          decoration: BoxDecoration(
            color: AppColors.node,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.blue
                  : (_hovered ? AppColors.borderHi : AppColors.border),
              width: widget.isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(widget.isSelected ? 0.7 : 0.5),
                blurRadius: widget.isSelected ? 22 : 16,
                offset: const Offset(0, 3),
              ),
              if (widget.isSelected)
                BoxShadow(
                  color: AppColors.blue.withOpacity(0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(tool, cat),
              _buildBody(tool),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ToolDefinition tool, ToolCategory cat) {
    return GestureDetector(
      onPanUpdate: (details) => widget.onMove(details.delta),
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
          decoration: BoxDecoration(
            color: cat.color.withOpacity(0.16),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: const Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
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
                  style: const TextStyle(
                    color: AppColors.text,
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
              _IconBtn(
                icon: '✕',
                hoverColor: AppColors.red,
                onTap: widget.onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ToolDefinition tool) {
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
              context.read<WorkflowProvider>().setNodePayload(widget.node.id, null, null);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
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
          _OutPort(
            nodeId: widget.node.id,
            onDragStart: widget.onPortDragStart,
          ),
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
      final parts = result.split('/');
      final fileName = parts.last;
      context.read<WorkflowProvider>().setNodePayload(widget.node.id, fileName, result);
    }
  }
}

// ── Sub-widgets ──

class _StatusDot extends StatelessWidget {
  final NodeStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case NodeStatus.running: color = AppColors.yellow; break;
      case NodeStatus.done: color = AppColors.green; break;
      case NodeStatus.error: color = AppColors.red; break;
      default: color = AppColors.text3;
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
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
            style: TextStyle(color: _hovered ? Colors.white : AppColors.text3, fontSize: 10)),
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
    final hasVm = widget.vm != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _hovered ? AppColors.blue : AppColors.border),
            color: AppColors.bg,
          ),
          child: Row(
            children: [
              Text(hasVm ? widget.vm!.icon : '🖥', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasVm ? '${widget.vm!.name} · ${widget.vm!.ip}' : '选择目标虚拟机...',
                  style: TextStyle(
                    color: hasVm ? (_hovered ? AppColors.blue : AppColors.text2) : AppColors.text3,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasVm)
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: widget.vm!.statusColor),
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
  const _PayloadSelector({this.payload, required this.onTap, required this.onClear});

  @override
  State<_PayloadSelector> createState() => _PayloadSelectorState();
}

class _PayloadSelectorState extends State<_PayloadSelector> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hasPayload = widget.payload != null;
    return Row(
      children: [
        Expanded(
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _hovered ? AppColors.orange : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    const Text('📁', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hasPayload ? widget.payload! : '从平台文件系统选择载荷...',
                        style: TextStyle(
                          color: hasPayload
                              ? (_hovered ? AppColors.orange : AppColors.text2)
                              : AppColors.text3,
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
          _IconBtn(icon: '✕', hoverColor: AppColors.red, onTap: widget.onClear),
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
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: widget.hasVm
                  ? (_hovered ? AppColors.blue : AppColors.blue.withOpacity(0.5))
                  : AppColors.text3,
            ),
            color: widget.hasVm && _hovered
                ? AppColors.blue.withOpacity(0.2)
                : AppColors.blue.withOpacity(0.08),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🖥', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 4),
              Text(
                '进入虚拟机',
                style: TextStyle(
                  color: widget.hasVm ? AppColors.blue : AppColors.text3,
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: _hovered ? AppColors.blue : AppColors.border),
          ),
          child: Text('⧉',
            style: TextStyle(color: _hovered ? AppColors.blue : AppColors.text3, fontSize: 10)),
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onDragStart(widget.nodeId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 14, height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hovered ? AppColors.blue : AppColors.bg,
            border: Border.all(
              color: _hovered ? AppColors.blue : AppColors.border,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Payload Dialog ──

class _PayloadDialog extends StatefulWidget {
  final String nodeId;
  final String? currentPayload;
  const _PayloadDialog({required this.nodeId, this.currentPayload});

  @override
  State<_PayloadDialog> createState() => _PayloadDialogState();
}

class _PayloadDialogState extends State<_PayloadDialog> {
  String _currentPath = '/pentest/exploits';
  String? _selectedFile;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: 680, height: 520,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: _FsTree(
                      currentPath: _currentPath,
                      onPathChange: (p) => setState(() => _currentPath = p),
                    ),
                  ),
                  Container(width: 1, color: AppColors.border),
                  Expanded(
                    child: _FsFiles(
                      path: _currentPath,
                      selectedFile: _selectedFile,
                      onSelect: (f) => setState(() => _selectedFile = f),
                    ),
                  ),
                ],
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Text('📁', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          const Text('平台文件系统',
            style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.text3, size: 16),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            _selectedFile != null ? '已选择: $_selectedFile' : '未选择文件',
            style: const TextStyle(color: AppColors.text2, fontSize: 11),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: AppColors.text2, fontSize: 11)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _selectedFile != null
                ? () => Navigator.pop(context, '$_currentPath/$_selectedFile')
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(fontSize: 11),
            ),
            child: const Text('确认选择'),
          ),
        ],
      ),
    );
  }
}

class _FsTree extends StatelessWidget {
  final String currentPath;
  final Function(String) onPathChange;
  const _FsTree({required this.currentPath, required this.onPathChange});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (final root in kFsTree['/'] ?? []) {
      final rootPath = '/$root';
      items.add(_FsTreeItem(
        label: root, path: rootPath, icon: '📁',
        isActive: currentPath.startsWith(rootPath), indent: 0,
        onTap: () => onPathChange(rootPath),
      ));
      for (final sub in kFsTree[rootPath] ?? []) {
        final subPath = '$rootPath/$sub';
        items.add(_FsTreeItem(
          label: sub, path: subPath, icon: '📂',
          isActive: currentPath == subPath, indent: 1,
          onTap: () => onPathChange(subPath),
        ));
      }
    }
    return Container(color: AppColors.bg, child: ListView(children: items));
  }
}

class _FsTreeItem extends StatefulWidget {
  final String label, path, icon;
  final bool isActive;
  final int indent;
  final VoidCallback onTap;
  const _FsTreeItem({
    required this.label, required this.path, required this.icon,
    required this.isActive, required this.indent, required this.onTap,
  });

  @override
  State<_FsTreeItem> createState() => _FsTreeItemState();
}

class _FsTreeItemState extends State<_FsTreeItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(8.0 + widget.indent * 16, 6, 8, 6),
          color: widget.isActive
              ? AppColors.blue.withOpacity(0.15)
              : (_hovered ? AppColors.card : Colors.transparent),
          child: Row(
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(widget.label,
                  style: TextStyle(
                    color: widget.isActive ? AppColors.blue : AppColors.text2,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FsFiles extends StatelessWidget {
  final String path;
  final String? selectedFile;
  final Function(String) onSelect;
  const _FsFiles({required this.path, this.selectedFile, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final files = kFsFiles[path] ?? [];
    if (files.isEmpty) {
      return const Center(
        child: Text('该目录为空', style: TextStyle(color: AppColors.text3, fontSize: 11)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return _FsFileItem(
          file: file,
          isSelected: selectedFile == file.name,
          onTap: () => onSelect(file.name),
        );
      },
    );
  }
}

class _FsFileItem extends StatefulWidget {
  final PlatformFile file;
  final bool isSelected;
  final VoidCallback onTap;
  const _FsFileItem({required this.file, required this.isSelected, required this.onTap});

  @override
  State<_FsFileItem> createState() => _FsFileItemState();
}

class _FsFileItemState extends State<_FsFileItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: widget.isSelected
                ? AppColors.blue.withOpacity(0.15)
                : (_hovered ? AppColors.card : Colors.transparent),
            border: Border.all(
              color: widget.isSelected ? AppColors.blue.withOpacity(0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Text(widget.file.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.file.name,
                      style: TextStyle(
                        color: widget.isSelected ? AppColors.blue : AppColors.text,
                        fontSize: 11,
                      )),
                    Text('${widget.file.date} · ${widget.file.type.toUpperCase()}',
                      style: const TextStyle(color: AppColors.text3, fontSize: 10)),
                  ],
                ),
              ),
              Text(widget.file.size,
                style: const TextStyle(color: AppColors.text3, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
