import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../providers/workflow_provider.dart';
import '../providers/vm_manager_provider.dart';
import '../services/dufs_service.dart';
import '../services/payload_store.dart';
import '../services/task_service.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 载荷列表 Tab
// 上传载荷到虚拟机内 dufs /payloads/ 目录，并在宿主机持久化记录
// ─────────────────────────────────────────────────────────────────────────────
class PayloadTab extends StatefulWidget {
  const PayloadTab({super.key});

  @override
  State<PayloadTab> createState() => _PayloadTabState();
}

class _PayloadTabState extends State<PayloadTab> {
  List<PayloadRecord> _records = [];
  bool   _loading  = false;
  String _filterVm = '';   // 空 = 全部

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _loading = true);
    final all = await PayloadStore.loadAll();
    if (mounted) setState(() { _records = all; _loading = false; });
  }

   // ── 获取当前选中节点的 VM 信息 ────────────────────────────────────
  _VmContext? _getVmContext() {
    final wp  = context.read<WorkflowProvider>();
    final vmp = context.read<VmManagerProvider>();
    final node = wp.selectedNode;
    if (node == null) return null;

    String? vmIp;
    String  vmId   = '';
    String  vmName = '';

    if (node.vmId != null && node.vmId!.isNotEmpty) {
      vmId = node.vmId!;
      // 优先从 NodeVmBind 获取 IP
      final bind = wp.getNodeVmBind(node.id);
      if (bind != null && bind.vmIp.isNotEmpty) {
        vmIp   = bind.vmIp;
        vmName = bind.vmName;
      } else {
        // 回退到 VmManagerProvider 实时列表
        final vm = vmp.vms.where((v) => v.id == node.vmId).firstOrNull;
        if (vm != null) {
          vmIp   = vm.ipAddress.isNotEmpty ? vm.ipAddress : null;
          vmName = vm.name;
        }
      }
    }
    if (vmIp == null || vmIp.isEmpty) return null;
    return _VmContext(vmId: vmId, vmName: vmName, vmIp: vmIp);
  }

  // ── 上传载荷 ──────────────────────────────────────────────────────────────
  Future<void> _upload() async {
    final vm = _getVmContext();
    if (vm == null) {
      _showSnack('请先选择绑定了虚拟机的节点', isError: true);
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final dufs = DufsService.fromVm(vmIp: vm.vmIp);
    // 确保 /payloads 目录存在
    try { await dufs.mkdir('/payloads'); } catch (_) {}

    for (final file in result.files) {
      if (file.bytes == null) continue;
      final remotePath = '/payloads/${file.name}';
      try {
        await dufs.upload(remotePath: remotePath, bytes: file.bytes!);
        final record = PayloadRecord(
          id:         const Uuid().v4(),
          fileName:   file.name,
          fileSize:   file.bytes!.length,
          vmId:       vm.vmId,
          vmName:     vm.vmName,
          vmIp:       vm.vmIp,
          remotePath: remotePath,
          uploadedAt: DateTime.now().toIso8601String(),
        );
        await PayloadStore.add(record);
      } catch (e) {
        if (mounted) _showSnack('上传 ${file.name} 失败: $e', isError: true);
        continue;
      }
    }
    await _loadRecords();
    if (mounted) _showSnack('载荷上传完成');
  }

  // ── 下载载荷 ──────────────────────────────────────────────────────────────
  Future<void> _download(PayloadRecord record) async {
    final dufs = DufsService.fromVm(vmIp: record.vmIp);
    try {
      final bytes = await dufs.download(record.remotePath);
      final dir   = await getDownloadsDirectory() ??
                    await getApplicationDocumentsDirectory();
      final file  = File(p.join(dir.path, record.fileName));
      await file.writeAsBytes(bytes);
      if (mounted) _showSnack('已保存到 ${file.path}');
    } catch (e) {
      if (mounted) _showSnack('下载失败: $e', isError: true);
    }
  }

  // ── 删除载荷（同时删除远程文件 + 本地记录）────────────────────────────────
  Future<void> _delete(PayloadRecord record) async {
    final t = context.appTheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.panel,
        title: Text('确认删除', style: TextStyle(color: t.text, fontSize: 13)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('载荷：${record.fileName}',
                style: TextStyle(color: t.text2, fontSize: 11)),
            const SizedBox(height: 4),
            Text('虚拟机：${record.vmName} (${record.vmIp})',
                style: TextStyle(color: t.text3, fontSize: 10)),
            const SizedBox(height: 4),
            Text('路径：${record.remotePath}',
                style: TextStyle(
                    color: t.text3, fontSize: 10, fontFamily: 'Consolas')),
            const SizedBox(height: 8),
            Text('将同时删除虚拟机内的文件，此操作不可撤销。',
                style: TextStyle(color: AppAccent.red, fontSize: 10)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppAccent.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // 删除远程文件
    try {
      final dufs = DufsService.fromVm(vmIp: record.vmIp);
      await dufs.delete(record.remotePath);
    } catch (_) {
      // 远程删除失败不阻止本地记录删除
    }
    await PayloadStore.remove(record.id);
    await _loadRecords();
    if (mounted) _showSnack('已删除 ${record.fileName}');
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 11)),
      backgroundColor: isError ? AppAccent.red : AppAccent.green,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    context.watch<WorkflowProvider>();
    context.watch<VmManagerProvider>();

    final vm = _getVmContext();
    final filtered = _filterVm.isEmpty
        ? _records
        : _records.where((r) => r.vmId == _filterVm).toList();

    return Column(
      children: [
        _buildToolbar(t, vm),
        if (_records.isNotEmpty) _buildVmFilter(t),
        Expanded(child: _buildList(t, filtered)),
      ],
    );
  }

  Widget _buildToolbar(AppThemeData t, _VmContext? vm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.border))),
      child: Row(
        children: [
          Text('载荷列表',
              style: TextStyle(
                  color: t.text2,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppAccent.blue.withOpacity(0.15),
            ),
            child: Text('${_records.length}',
                style: TextStyle(
                    color: AppAccent.blue, fontSize: 9)),
          ),
          const Spacer(),
          // 上传按钮
          _UploadBtn(
            enabled: vm != null,
            tooltip: vm == null ? '请先选择绑定了虚拟机的节点' : '上传载荷到 ${vm.vmName}',
            onTap: _upload,
          ),
          const SizedBox(width: 4),
          // 刷新
          GestureDetector(
            onTap: _loadRecords,
            child: Icon(Icons.refresh, size: 14, color: t.text3),
          ),
        ],
      ),
    );
  }

  Widget _buildVmFilter(AppThemeData t) {
    // 收集所有不重复的 VM
    final vms = <String, String>{};
    for (final r in _records) {
      vms[r.vmId] = '${r.vmName} (${r.vmIp})';
    }
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.border))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: '全部',
              active: _filterVm.isEmpty,
              onTap: () => setState(() => _filterVm = ''),
            ),
            ...vms.entries.map((e) => _FilterChip(
                  label: e.value,
                  active: _filterVm == e.key,
                  onTap: () => setState(() => _filterVm = e.key),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildList(AppThemeData t, List<PayloadRecord> records) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📦', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text('暂无载荷记录',
                style: TextStyle(color: t.text3, fontSize: 12)),
            const SizedBox(height: 4),
            Text('选择绑定了虚拟机的节点后点击上传',
                style: TextStyle(color: t.text3, fontSize: 10)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: records.length,
      itemBuilder: (ctx, i) => _PayloadCard(
        record: records[i],
        onDownload: () => _download(records[i]),
        onDelete:   () => _delete(records[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 载荷卡片
// ─────────────────────────────────────────────────────────────────────────────
class _PayloadCard extends StatefulWidget {
  final PayloadRecord record;
  final VoidCallback  onDownload;
  final VoidCallback  onDelete;
  const _PayloadCard({
    required this.record,
    required this.onDownload,
    required this.onDelete,
  });
  @override
  State<_PayloadCard> createState() => _PayloadCardState();
}
class _PayloadCardState extends State<_PayloadCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final r = widget.record;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: _hovered ? t.card : t.bg,
          border: Border.all(
              color: _hovered ? t.borderHi : t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📦', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(r.fileName,
                      style: TextStyle(
                          color: t.text,
                          fontSize: 11,
                          fontFamily: 'Consolas',
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(r.sizeLabel,
                    style: TextStyle(color: t.text3, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.computer, size: 10, color: t.text3),
                const SizedBox(width: 3),
                Text('${r.vmName}  ${r.vmIp}',
                    style: TextStyle(color: t.text3, fontSize: 9)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.folder_outlined, size: 10, color: t.text3),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(r.remotePath,
                      style: TextStyle(
                          color: t.text3,
                          fontSize: 9,
                          fontFamily: 'Consolas'),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            if (_hovered) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionBtn(
                    icon: Icons.download_outlined,
                    label: '下载',
                    color: AppAccent.blue,
                    onTap: widget.onDownload,
                  ),
                  const SizedBox(width: 6),
                  _ActionBtn(
                    icon: Icons.delete_outline,
                    label: '删除',
                    color: AppAccent.red,
                    onTap: widget.onDelete,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 辅助组件
// ─────────────────────────────────────────────────────────────────────────────
class _UploadBtn extends StatefulWidget {
  final bool     enabled;
  final String   tooltip;
  final VoidCallback onTap;
  const _UploadBtn({required this.enabled, required this.tooltip, required this.onTap});
  @override
  State<_UploadBtn> createState() => _UploadBtnState();
}
class _UploadBtnState extends State<_UploadBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: widget.enabled
                  ? (_hovered
                      ? AppAccent.blue
                      : AppAccent.blue.withOpacity(0.15))
                  : t.card,
              border: Border.all(
                  color: widget.enabled ? AppAccent.blue : t.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.upload_file,
                    size: 11,
                    color: widget.enabled
                        ? (_hovered ? Colors.white : AppAccent.blue)
                        : t.text3),
                const SizedBox(width: 3),
                Text('上传载荷',
                    style: TextStyle(
                        fontSize: 10,
                        color: widget.enabled
                            ? (_hovered ? Colors.white : AppAccent.blue)
                            : t.text3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool   active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: active
              ? AppAccent.blue.withOpacity(0.2)
              : Colors.transparent,
          border: Border.all(
              color: active ? AppAccent.blue : t.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9,
                color: active ? AppAccent.blue : t.text3)),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: color.withOpacity(0.12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 内部数据类
// ─────────────────────────────────────────────────────────────────────────────
class _VmContext {
  final String vmId;
  final String vmName;
  final String vmIp;
  const _VmContext({required this.vmId, required this.vmName, required this.vmIp});
}
