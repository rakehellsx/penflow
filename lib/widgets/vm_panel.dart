import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workflow_provider.dart';
import '../data/tools_data.dart';
import '../models/tool_model.dart';
import '../utils/app_theme.dart';

class VmPanel extends StatefulWidget {
  final String nodeId;
  final VoidCallback onClose;

  const VmPanel({super.key, required this.nodeId, required this.onClose});

  @override
  State<VmPanel> createState() => _VmPanelState();
}

class _VmPanelState extends State<VmPanel> with SingleTickerProviderStateMixin {
  String _filter = 'all';
  String _searchQuery = '';
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: Container(
        height: 280,
        decoration: const BoxDecoration(
          color: AppColors.panel,
          border: Border(top: BorderSide(color: AppColors.blue, width: 2)),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: Column(
          children: [
            _buildHeader(context),
            _buildFilterBar(),
            Expanded(child: _buildVmList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Text('🖥', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          const Text('选择目标虚拟机',
            style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: AppColors.text, fontSize: 11),
              decoration: const InputDecoration(
                hintText: '搜索虚拟机...',
                prefixIcon: Icon(Icons.search, color: AppColors.text3, size: 14),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                isDense: true,
              ),
            ),
          ),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text('✕ 关闭',
                  style: TextStyle(color: AppColors.text2, fontSize: 11)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _FilterBtn(label: '全部', value: 'all', current: _filter,
            onTap: (v) => setState(() => _filter = v)),
          const SizedBox(width: 6),
          _FilterBtn(label: '🐧 Linux', value: 'linux', current: _filter,
            onTap: (v) => setState(() => _filter = v)),
          const SizedBox(width: 6),
          _FilterBtn(label: '🪟 Windows', value: 'windows', current: _filter,
            onTap: (v) => setState(() => _filter = v)),
          const SizedBox(width: 6),
          _FilterBtn(label: '🟢 运行中', value: 'running', current: _filter,
            onTap: (v) => setState(() => _filter = v)),
        ],
      ),
    );
  }

  Widget _buildVmList(BuildContext context) {
    final vms = kVirtualMachines.where((vm) {
      if (_filter == 'linux' && vm.osType != 'linux') return false;
      if (_filter == 'windows' && vm.osType != 'windows') return false;
      if (_filter == 'running' && vm.status != 'on') return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!vm.name.toLowerCase().contains(q) &&
            !vm.ip.toLowerCase().contains(q) &&
            !vm.tag.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();

    if (vms.isEmpty) {
      return const Center(
        child: Text('没有找到匹配的虚拟机', style: TextStyle(color: AppColors.text3, fontSize: 11)),
      );
    }

    return Scrollbar(
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(10),
        itemCount: vms.length,
        itemBuilder: (context, index) {
          final vm = vms[index];
          return _VmCard(
            vm: vm,
            nodeId: widget.nodeId,
            onSelect: () {
              context.read<WorkflowProvider>().setNodeVm(widget.nodeId, vm.id);
              widget.onClose();
            },
          );
        },
      ),
    );
  }
}

class _FilterBtn extends StatefulWidget {
  final String label;
  final String value;
  final String current;
  final Function(String) onTap;

  const _FilterBtn({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  State<_FilterBtn> createState() => _FilterBtnState();
}

class _FilterBtnState extends State<_FilterBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.value == widget.current;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onTap(widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive ? AppColors.blue.withOpacity(0.2) : Colors.transparent,
            border: Border.all(
              color: isActive ? AppColors.blue : (_hovered ? AppColors.borderHi : AppColors.border),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: isActive ? AppColors.blue : AppColors.text2,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}

class _VmCard extends StatefulWidget {
  final VirtualMachine vm;
  final String nodeId;
  final VoidCallback onSelect;

  const _VmCard({required this.vm, required this.nodeId, required this.onSelect});

  @override
  State<_VmCard> createState() => _VmCardState();
}

class _VmCardState extends State<_VmCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkflowProvider>();
    final node = provider.nodes.where((n) => n.id == widget.nodeId).firstOrNull;
    final isSelected = node?.vmId == widget.vm.id;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 200,
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? AppColors.blue.withOpacity(0.12)
                : (_hovered ? AppColors.card : AppColors.bg),
            border: Border.all(
              color: isSelected
                  ? AppColors.blue
                  : (_hovered ? AppColors.borderHi : AppColors.border),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(widget.vm.icon, style: const TextStyle(fontSize: 20)),
                  const Spacer(),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.vm.statusColor,
                      boxShadow: [BoxShadow(
                        color: widget.vm.statusColor.withOpacity(0.5),
                        blurRadius: 4,
                      )],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(widget.vm.name,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
              const SizedBox(height: 2),
              Text(widget.vm.ip,
                style: const TextStyle(
                  color: AppColors.cyan,
                  fontSize: 10,
                  fontFamily: 'Consolas',
                )),
              const SizedBox(height: 4),
              // Tag as role indicator
              Text(widget.vm.tag,
                style: const TextStyle(color: AppColors.text3, fontSize: 10)),
              const Spacer(),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: AppColors.card,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(widget.vm.osType.toUpperCase(),
                      style: const TextStyle(color: AppColors.text3, fontSize: 8)),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: AppColors.card,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      _statusLabel(widget.vm.status),
                      style: TextStyle(color: widget.vm.statusColor, fontSize: 8),
                    ),
                  ),
                  if (isSelected) ...[
                    const Spacer(),
                    const Text('✓', style: TextStyle(color: AppColors.green, fontSize: 12)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'on': return '运行中';
      case 'busy': return '繁忙';
      case 'off': return '已关机';
      default: return status;
    }
  }
}
