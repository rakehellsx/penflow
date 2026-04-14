import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workflow_provider.dart';
import '../providers/vm_manager_provider.dart';
import '../data/tools_data.dart';
import '../models/tool_model.dart';
import '../services/vm_backend.dart';
import '../utils/app_theme.dart';
import 'create_vm_dialog.dart';

class VmPanel extends StatefulWidget {
  final String nodeId;
  final VoidCallback onClose;

  const VmPanel({super.key, required this.nodeId, required this.onClose});

  @override
  State<VmPanel> createState() => _VmPanelState();
}

class _VmPanelState extends State<VmPanel>
    with SingleTickerProviderStateMixin {
  String _filter = 'all';
  String _searchQuery = '';
  // 0 = 静态列表(tools_data), 1 = 真实VM(backend)
  int _tab = 0;

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
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    // 初始化真实 VM 后端
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VmManagerProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _openCreateVmDialog() async {
    await showDialog<VmInfo>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<VmManagerProvider>(),
        child: const CreateVmDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return SlideTransition(
      position: _slideAnim,
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          color: t.panel,
          border: Border(top: BorderSide(color: AppAccent.blue, width: 2)),
          boxShadow: [
            BoxShadow(
              color: (t.isDark ? Colors.black : Colors.grey.shade400)
                  .withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: Column(
          children: [
            _buildHeader(context, t),
            _buildTabAndFilter(t),
            Expanded(child: _buildContent(context, t)),
          ],
        ),
      ),
    );
  }

  // ── 头部：标题 + 搜索 + 新建 + 关闭 ──────────────────────────────────────
  Widget _buildHeader(BuildContext context, AppThemeData t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
      child: Row(
        children: [
          const Text('🖥', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text('选择目标虚拟机',
              style: TextStyle(
                  color: t.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: t.text, fontSize: 11),
              decoration: InputDecoration(
                hintText: '搜索虚拟机...',
                prefixIcon: Icon(Icons.search, color: t.text3, size: 14),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                isDense: true,
              ),
            ),
          ),
          const Spacer(),

          // ── 新建虚拟机按钮 ──────────────────────────────
          _NewVmButton(onTap: _openCreateVmDialog),
          const SizedBox(width: 10),

          // ── 关闭按钮 ────────────────────────────────────
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: t.border),
                ),
                child: Text('✕ 关闭',
                    style: TextStyle(color: t.text2, fontSize: 11)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 切换 + 过滤栏 ─────────────────────────────────────────────────────
  Widget _buildTabAndFilter(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
      child: Row(
        children: [
          // Tab 切换
          _TabBtn(
              label: '预设列表',
              index: 0,
              current: _tab,
              onTap: (i) => setState(() => _tab = i)),
          const SizedBox(width: 6),
          _TabBtn(
              label: '真实虚拟机',
              index: 1,
              current: _tab,
              onTap: (i) => setState(() => _tab = i)),
          const SizedBox(width: 16),
          const _Divider(),
          const SizedBox(width: 16),
          // 过滤按钮
          _FilterBtn(
              label: '全部',
              value: 'all',
              current: _filter,
              onTap: (v) => setState(() => _filter = v)),
          const SizedBox(width: 6),
          _FilterBtn(
              label: '🐧 Linux',
              value: 'linux',
              current: _filter,
              onTap: (v) => setState(() => _filter = v)),
          const SizedBox(width: 6),
          _FilterBtn(
              label: '🪟 Windows',
              value: 'windows',
              current: _filter,
              onTap: (v) => setState(() => _filter = v)),
          const SizedBox(width: 6),
          _FilterBtn(
              label: '🟢 运行中',
              value: 'running',
              current: _filter,
              onTap: (v) => setState(() => _filter = v)),
          const Spacer(),
          // 刷新按钮（真实VM时）
          if (_tab == 1)
            _RefreshButton(
              onTap: () => context.read<VmManagerProvider>().refresh(),
            ),
        ],
      ),
    );
  }

  // ── 内容区 ────────────────────────────────────────────────────────────────
  Widget _buildContent(BuildContext context, AppThemeData t) {
    if (_tab == 0) {
      return _buildStaticVmList(context, t);
    } else {
      return _buildRealVmList(context, t);
    }
  }

  // 预设 VM 列表（来自 tools_data）
  Widget _buildStaticVmList(BuildContext context, AppThemeData t) {
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
      return Center(
        child: Text('没有找到匹配的虚拟机',
            style: TextStyle(color: t.text3, fontSize: 11)),
      );
    }

    return Scrollbar(
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(10),
        itemCount: vms.length,
        itemBuilder: (context, index) {
          final vm = vms[index];
          return _StaticVmCard(
            vm: vm,
            nodeId: widget.nodeId,
            onSelect: () {
              context.read<WorkflowProvider>().setNodeVm(
                widget.nodeId, vm.id,
                vmName: vm.name,
                vmIp: vm.ip,
                vmOsType: vm.osType,
                vmTag: vm.tag,
                vmBackend: 'preset',
              );
              widget.onClose();
            },
          );
        },
      ),
    );
  }

  // 真实 VM 列表（来自后端）
  Widget _buildRealVmList(BuildContext context, AppThemeData t) {
    final manager = context.watch<VmManagerProvider>();

    if (manager.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
                strokeWidth: 2, color: AppAccent.blue),
            const SizedBox(height: 8),
            Text('正在连接 ${manager.backendName}...',
                style: TextStyle(color: t.text3, fontSize: 11)),
          ],
        ),
      );
    }

    if (!manager.available) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text('虚拟机后端不可用',
                style: TextStyle(
                    color: t.text, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(manager.backendName,
                style: TextStyle(color: AppAccent.blue, fontSize: 10)),
            const SizedBox(height: 8),
            Text(
              '请确认已安装并启动虚拟机管理服务\n'
              '• Linux: 安装 libvirt，运行 sudo systemctl start libvirtd\n'
              '• Windows: 运行 vmrest.exe 并配置凭据',
              style: TextStyle(color: t.text3, fontSize: 10),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppAccent.blue,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () => manager.refresh(),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('重新检测', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      );
    }

    final vms = manager.vms.where((vm) {
      if (_filter == 'linux' && vm.osType != 'linux') return false;
      if (_filter == 'windows' && vm.osType != 'windows') return false;
      if (_filter == 'running' && vm.powerState != VmPowerState.poweredOn)
        return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!vm.name.toLowerCase().contains(q) &&
            !vm.ipAddress.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();

    if (vms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('没有找到虚拟机',
                style: TextStyle(color: t.text3, fontSize: 11)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _openCreateVmDialog,
              icon: const Icon(Icons.add_circle_outline,
                  size: 14, color: AppAccent.green),
              label: const Text('新建虚拟机',
                  style:
                      TextStyle(color: AppAccent.green, fontSize: 11)),
            ),
          ],
        ),
      );
    }

    return Scrollbar(
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(10),
        itemCount: vms.length,
        itemBuilder: (context, index) {
          final vm = vms[index];
          return _RealVmCard(
            vm: vm,
            nodeId: widget.nodeId,
            onSelect: () {
              context.read<WorkflowProvider>().setNodeVm(
                widget.nodeId, vm.id,
                vmName: vm.name,
                vmIp: vm.ipAddress,
                vmOsType: vm.osType,
                vmTag: vm.name,
                vmBackend: 'real',
              );
              widget.onClose();
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 新建 VM 按钮
// ─────────────────────────────────────────────────────────────────────────────

class _NewVmButton extends StatefulWidget {
  final VoidCallback onTap;
  const _NewVmButton({required this.onTap});

  @override
  State<_NewVmButton> createState() => _NewVmButtonState();
}

class _NewVmButtonState extends State<_NewVmButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: _hovered
                ? AppAccent.green.withOpacity(0.15)
                : AppAccent.green.withOpacity(0.08),
            border: Border.all(
              color: _hovered
                  ? AppAccent.green
                  : AppAccent.green.withOpacity(0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline,
                  color: AppAccent.green, size: 13),
              const SizedBox(width: 5),
              Text('新建虚拟机',
                  style: TextStyle(
                    color: AppAccent.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 真实 VM 卡片（带操作菜单）
// ─────────────────────────────────────────────────────────────────────────────

class _RealVmCard extends StatefulWidget {
  final VmInfo vm;
  final String nodeId;
  final VoidCallback onSelect;

  const _RealVmCard(
      {required this.vm, required this.nodeId, required this.onSelect});

  @override
  State<_RealVmCard> createState() => _RealVmCardState();
}

class _RealVmCardState extends State<_RealVmCard> {
  bool _hovered = false;
  bool _operating = false;

  Color get _stateColor {
    switch (widget.vm.powerState) {
      case VmPowerState.poweredOn:
        return AppAccent.green;
      case VmPowerState.suspended:
      case VmPowerState.paused:
        return AppAccent.orange;
      case VmPowerState.poweredOff:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String get _stateLabel {
    switch (widget.vm.powerState) {
      case VmPowerState.poweredOn:
        return '运行中';
      case VmPowerState.suspended:
        return '已挂起';
      case VmPowerState.paused:
        return '已暂停';
      case VmPowerState.poweredOff:
        return '已关机';
      default:
        return '未知';
    }
  }

  String get _osIcon {
    switch (widget.vm.osType) {
      case 'windows':
        return '🪟';
      case 'kali':
        return '🐉';
      case 'ubuntu':
        return '🟠';
      case 'parrot':
        return '🦜';
      default:
        return '🐧';
    }
  }

  Future<void> _doAction(
      BuildContext context, String action) async {
    final manager = context.read<VmManagerProvider>();
    setState(() => _operating = true);

    bool ok = false;
    String msg = '';

    switch (action) {
      case 'powerOn':
        ok = await manager.powerOn(widget.vm.id);
        msg = ok ? '已开机' : '开机失败';
        break;
      case 'powerOff':
        ok = await manager.powerOff(widget.vm.id);
        msg = ok ? '已关机' : '关机失败';
        break;
      case 'reboot':
        ok = await manager.reboot(widget.vm.id);
        msg = ok ? '已重启' : '重启失败';
        break;
      case 'suspend':
        ok = await manager.suspend(widget.vm.id);
        msg = ok ? '已挂起' : '挂起失败';
        break;
      case 'delete':
        // 二次确认
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.appTheme.panel,
            title: Text('确认删除',
                style: TextStyle(
                    color: context.appTheme.text, fontSize: 13)),
            content: Text(
              '确定要删除虚拟机 "${widget.vm.name}" 吗？\n此操作不可撤销，虚拟机磁盘也将被删除。',
              style: TextStyle(
                  color: context.appTheme.text2, fontSize: 11),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppAccent.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          ok = await manager.delete(widget.vm.id);
          msg = ok ? '已删除' : '删除失败';
        } else {
          if (mounted) setState(() => _operating = false);
          return;
        }
        break;
    }

    if (mounted) {
      setState(() => _operating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 11)),
        backgroundColor: ok ? AppAccent.green : AppAccent.red,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final provider = context.watch<WorkflowProvider>();
    final node =
        provider.nodes.where((n) => n.id == widget.nodeId).firstOrNull;
    final isSelected = node?.vmId == widget.vm.id;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 210,
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? AppAccent.blue.withOpacity(0.12)
                : (_hovered ? t.card : t.bg),
            border: Border.all(
              color: isSelected
                  ? AppAccent.blue
                  : (_hovered ? t.borderHi : t.border),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 顶部：图标 + 状态点 + 操作菜单 ──────────
              Row(
                children: [
                  Text(_osIcon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 4),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _stateColor,
                      boxShadow: [
                        BoxShadow(
                          color: _stateColor.withOpacity(0.5),
                          blurRadius: 4,
                        )
                      ],
                    ),
                  ),
                  const Spacer(),
                  // 操作菜单按钮
                  if (_operating)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppAccent.blue),
                    )
                  else
                    _VmActionMenu(
                      vm: widget.vm,
                      onAction: (action) => _doAction(context, action),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // ── VM 名称 ──────────────────────────────────
              Text(
                widget.vm.name,
                style: TextStyle(
                    color: t.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // ── IP 地址 ──────────────────────────────────
              Text(
                widget.vm.ipAddress.isNotEmpty
                    ? widget.vm.ipAddress
                    : '无 IP',
                style: TextStyle(
                  color: t.isDark
                      ? AppAccent.cyan
                      : const Color(0xFF0550AE),
                  fontSize: 10,
                  fontFamily: 'Consolas',
                ),
              ),
              const SizedBox(height: 4),

              // ── CPU / 内存 ───────────────────────────────
              Text(
                '${widget.vm.cpuCount} vCPU  ${widget.vm.memoryMB >= 1024 ? "${widget.vm.memoryMB ~/ 1024}GB" : "${widget.vm.memoryMB}MB"} RAM',
                style: TextStyle(color: t.text3, fontSize: 9),
              ),
              const Spacer(),

              // ── 底部标签 ─────────────────────────────────
              Row(
                children: [
                  _Tag(widget.vm.osType.toUpperCase(), t),
                  const SizedBox(width: 4),
                  _Tag(
                    _stateLabel,
                    t,
                    color: _stateColor,
                  ),
                  if (isSelected) ...[
                    const Spacer(),
                    const Text('✓',
                        style: TextStyle(
                            color: AppAccent.green, fontSize: 12)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VM 操作菜单
// ─────────────────────────────────────────────────────────────────────────────

class _VmActionMenu extends StatelessWidget {
  final VmInfo vm;
  final Function(String) onAction;

  const _VmActionMenu({required this.vm, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final isOn = vm.powerState == VmPowerState.poweredOn;
    final isOff = vm.powerState == VmPowerState.poweredOff;
    final isSuspended = vm.powerState == VmPowerState.suspended ||
        vm.powerState == VmPowerState.paused;

    return PopupMenuButton<String>(
      onSelected: onAction,
      tooltip: '虚拟机操作',
      color: t.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: t.border),
      ),
      offset: const Offset(0, 20),
      itemBuilder: (_) => [
        if (isOff || isSuspended)
          PopupMenuItem(
            value: 'powerOn',
            child: _MenuItem(
                icon: Icons.play_circle_outline,
                label: '开机',
                color: AppAccent.green),
          ),
        if (isOn)
          PopupMenuItem(
            value: 'reboot',
            child: _MenuItem(
                icon: Icons.restart_alt,
                label: '重启',
                color: AppAccent.blue),
          ),
        if (isOn)
          PopupMenuItem(
            value: 'suspend',
            child: _MenuItem(
                icon: Icons.pause_circle_outline,
                label: '挂起',
                color: AppAccent.orange),
          ),
        if (isOn)
          PopupMenuItem(
            value: 'powerOff',
            child: _MenuItem(
                icon: Icons.power_settings_new,
                label: '关机',
                color: AppAccent.red),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: _MenuItem(
              icon: Icons.delete_outline,
              label: '删除虚拟机',
              color: AppAccent.red),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: t.border),
        ),
        child: Icon(Icons.more_horiz, color: t.text3, size: 12),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MenuItem(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: context.appTheme.text, fontSize: 11)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 静态 VM 卡片（原有预设列表）
// ─────────────────────────────────────────────────────────────────────────────

class _StaticVmCard extends StatefulWidget {
  final VirtualMachine vm;
  final String nodeId;
  final VoidCallback onSelect;

  const _StaticVmCard(
      {required this.vm, required this.nodeId, required this.onSelect});

  @override
  State<_StaticVmCard> createState() => _StaticVmCardState();
}

class _StaticVmCardState extends State<_StaticVmCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final provider = context.watch<WorkflowProvider>();
    final node =
        provider.nodes.where((n) => n.id == widget.nodeId).firstOrNull;
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
                ? AppAccent.blue.withOpacity(0.12)
                : (_hovered ? t.card : t.bg),
            border: Border.all(
              color: isSelected
                  ? AppAccent.blue
                  : (_hovered ? t.borderHi : t.border),
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
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.vm.statusColor,
                      boxShadow: [
                        BoxShadow(
                          color: widget.vm.statusColor.withOpacity(0.5),
                          blurRadius: 4,
                        )
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(widget.vm.name,
                  style: TextStyle(
                      color: t.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(widget.vm.ip,
                  style: TextStyle(
                    color: t.isDark
                        ? AppAccent.cyan
                        : const Color(0xFF0550AE),
                    fontSize: 10,
                    fontFamily: 'Consolas',
                  )),
              const SizedBox(height: 4),
              Text(widget.vm.tag,
                  style: TextStyle(color: t.text3, fontSize: 10)),
              const Spacer(),
              Row(
                children: [
                  _Tag(widget.vm.osType.toUpperCase(), t),
                  const SizedBox(width: 4),
                  _Tag(_statusLabel(widget.vm.status), t,
                      color: widget.vm.statusColor),
                  if (isSelected) ...[
                    const Spacer(),
                    const Text('✓',
                        style: TextStyle(
                            color: AppAccent.green, fontSize: 12)),
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
      case 'on':
        return '运行中';
      case 'busy':
        return '繁忙';
      case 'off':
        return '已关机';
      default:
        return status;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 通用小组件
// ─────────────────────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;
  final AppThemeData t;
  final Color? color;

  const _Tag(this.label, this.t, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: t.card,
        border: Border.all(color: t.border),
      ),
      child: Text(label,
          style: TextStyle(color: color ?? t.text3, fontSize: 8)),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final int index;
  final int current;
  final Function(int) onTap;

  const _TabBtn(
      {required this.label,
      required this.index,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final isActive = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: isActive ? AppAccent.blue.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
              color: isActive ? AppAccent.blue : t.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppAccent.blue : t.text2,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _FilterBtn extends StatefulWidget {
  final String label;
  final String value;
  final String current;
  final Function(String) onTap;

  const _FilterBtn(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});

  @override
  State<_FilterBtn> createState() => _FilterBtnState();
}

class _FilterBtnState extends State<_FilterBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final isActive = widget.value == widget.current;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onTap(widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? AppAccent.blue.withOpacity(0.2)
                : Colors.transparent,
            border: Border.all(
              color: isActive
                  ? AppAccent.blue
                  : (_hovered ? t.borderHi : t.border),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: isActive ? AppAccent.blue : t.text2,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}

class _RefreshButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RefreshButton({required this.onTap});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: _hovered ? t.card : Colors.transparent,
            border: Border.all(color: _hovered ? t.borderHi : t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, color: t.text2, size: 12),
              const SizedBox(width: 4),
              Text('刷新', style: TextStyle(color: t.text2, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      color: context.appTheme.border,
    );
  }
}
