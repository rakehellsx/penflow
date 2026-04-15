import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../providers/workflow_provider.dart';
import '../providers/vm_manager_provider.dart';
import '../services/dufs_service.dart';
import '../services/task_service.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 文件管理 Tab
// 对接虚拟机内部署的 dufs 服务，支持浏览、上传、下载、删除、创建目录
// ─────────────────────────────────────────────────────────────────────────────
class FileManagerTab extends StatefulWidget {
  const FileManagerTab({super.key});

  @override
  State<FileManagerTab> createState() => _FileManagerTabState();
}

class _FileManagerTabState extends State<FileManagerTab> {
  String        _currentPath = '/';
  List<DufsEntry> _entries  = [];
  bool          _loading     = false;
  String?       _error;
  DufsService?  _dufs;
  String        _vmLabel     = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuildService();
  }

  void _rebuildService() {
    final wp  = context.read<WorkflowProvider>();
    final vmp = context.read<VmManagerProvider>();
    final node = wp.selectedNode;
    if (node == null) {
      setState(() { _dufs = null; _vmLabel = ''; _entries = []; });
      return;
    }
    // 优先从 NodeVmBind 获取 IP（setNodeVm 时已存入 SQLite）
    String? vmIp;
    String  vmName = '';
    if (node.vmId != null && node.vmId!.isNotEmpty) {
      final bind = wp.getNodeVmBind(node.id);
      if (bind != null && bind.vmIp.isNotEmpty) {
        vmIp   = bind.vmIp;
        vmName = bind.vmName;
      } else {
        // 回退到 VmManagerProvider 中的实时 VM 列表
        final vm = vmp.vms.where((v) => v.id == node.vmId).firstOrNull;
        if (vm != null) {
          vmIp   = vm.ipAddress.isNotEmpty ? vm.ipAddress : null;
          vmName = vm.name;
        }
      }
    }
    if (vmIp == null || vmIp.isEmpty) {
      setState(() { _dufs = null; _vmLabel = vmName; _entries = []; });
      return;
    }
    final newDufs = DufsService.fromVm(vmIp: vmIp);
    if (_dufs?.baseUrl != newDufs.baseUrl) {
      _dufs    = newDufs;
      _vmLabel = vmName;
      _currentPath = '/';
      _loadDir();
    }
  }

  Future<void> _loadDir([String? path]) async {
    if (_dufs == null) return;
    final target = path ?? _currentPath;
    setState(() { _loading = true; _error = null; });
    try {
      final entries = await _dufs!.listDir(target);
      if (mounted) {
        setState(() {
          _entries     = entries;
          _currentPath = target;
          _loading     = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _navigate(DufsEntry entry) {
    if (!entry.isDir) return;
    final next = _currentPath.endsWith('/')
        ? '${_currentPath}${entry.name}'
        : '$_currentPath/${entry.name}';
    _loadDir(next);
  }

  void _goUp() {
    if (_currentPath == '/' || _currentPath.isEmpty) return;
    final parent = p.dirname(_currentPath);
    _loadDir(parent.isEmpty ? '/' : parent);
  }

  Future<void> _upload() async {
    if (_dufs == null) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    for (final file in result.files) {
      if (file.bytes == null) continue;
      final remotePath = _currentPath == '/'
          ? '/${file.name}'
          : '$_currentPath/${file.name}';
      try {
        await _dufs!.upload(
          remotePath: remotePath,
          bytes: file.bytes!,
        );
      } catch (e) {
        if (mounted) {
          _showSnack('上传 ${file.name} 失败: $e', isError: true);
        }
        continue;
      }
    }
    _loadDir();
    if (mounted) _showSnack('上传完成');
  }

  Future<void> _download(DufsEntry entry) async {
    if (_dufs == null || entry.isDir) return;
    final remotePath = _currentPath == '/'
        ? '/${entry.name}'
        : '$_currentPath/${entry.name}';
    try {
      final bytes = await _dufs!.download(remotePath);
      // 保存到下载目录
      final dir  = await getDownloadsDirectory() ??
                   await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, entry.name));
      await file.writeAsBytes(bytes);
      if (mounted) _showSnack('已保存到 ${file.path}');
    } catch (e) {
      if (mounted) _showSnack('下载失败: $e', isError: true);
    }
  }

  Future<void> _delete(DufsEntry entry) async {
    if (_dufs == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = ctx.appTheme;
        return AlertDialog(
          backgroundColor: t.panel,
          title: Text('确认删除', style: TextStyle(color: t.text, fontSize: 13)),
          content: Text('删除 ${entry.name}？此操作不可撤销。',
              style: TextStyle(color: t.text2, fontSize: 11)),
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
        );
      },
    );
    if (ok != true) return;
    final remotePath = _currentPath == '/'
        ? '/${entry.name}'
        : '$_currentPath/${entry.name}';
    try {
      await _dufs!.delete(remotePath);
      _loadDir();
      if (mounted) _showSnack('已删除 ${entry.name}');
    } catch (e) {
      if (mounted) _showSnack('删除失败: $e', isError: true);
    }
  }

  Future<void> _mkdir() async {
    final t = context.appTheme;
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.panel,
        title: Text('新建目录', style: TextStyle(color: t.text, fontSize: 13)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: t.text, fontSize: 11),
          decoration: const InputDecoration(hintText: '目录名称', isDense: true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final remotePath = _currentPath == '/'
        ? '/$name'
        : '$_currentPath/$name';
    try {
      await _dufs!.mkdir(remotePath);
      _loadDir();
      if (mounted) _showSnack('目录已创建');
    } catch (e) {
      if (mounted) _showSnack('创建失败: $e', isError: true);
    }
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
    // 监听 selectedNode 变化
    context.watch<WorkflowProvider>();
    context.watch<VmManagerProvider>();

    if (_dufs == null) {
      return _buildPlaceholder(t);
    }

    return Column(
      children: [
        _buildToolbar(t),
        _buildBreadcrumb(t),
        Expanded(child: _buildContent(t)),
      ],
    );
  }

  Widget _buildPlaceholder(AppThemeData t) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📁', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text('请先选择绑定了虚拟机的节点',
              style: TextStyle(color: t.text3, fontSize: 12)),
          const SizedBox(height: 4),
          Text('文件管理将连接虚拟机内的 dufs 服务',
              style: TextStyle(color: t.text3, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildToolbar(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.border))),
      child: Row(
        children: [
          Text(_vmLabel,
              style: TextStyle(
                  color: AppAccent.cyan, fontSize: 10,
                  fontFamily: 'Consolas')),
          const Spacer(),
          _ToolBtn(
              icon: Icons.create_new_folder_outlined,
              tooltip: '新建目录',
              onTap: _mkdir),
          const SizedBox(width: 4),
          _ToolBtn(
              icon: Icons.upload_file,
              tooltip: '上传文件',
              onTap: _upload),
          const SizedBox(width: 4),
          _ToolBtn(
              icon: Icons.refresh,
              tooltip: '刷新',
              onTap: () => _loadDir()),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(AppThemeData t) {
    final parts = _currentPath.split('/').where((s) => s.isNotEmpty).toList();
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.border))),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _loadDir('/'),
            child: Text('/',
                style: TextStyle(
                    color: AppAccent.blue,
                    fontSize: 11,
                    fontFamily: 'Consolas')),
          ),
          ...parts.asMap().entries.map((e) {
            final idx  = e.key;
            final part = e.value;
            final path = '/${parts.sublist(0, idx + 1).join('/')}';
            return Row(children: [
              Text(' / ',
                  style: TextStyle(color: t.text3, fontSize: 11)),
              GestureDetector(
                onTap: () => _loadDir(path),
                child: Text(part,
                    style: TextStyle(
                        color: idx == parts.length - 1
                            ? t.text
                            : AppAccent.blue,
                        fontSize: 11,
                        fontFamily: 'Consolas')),
              ),
            ]);
          }),
        ],
      ),
    );
  }

  Widget _buildContent(AppThemeData t) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text('连接失败', style: TextStyle(color: t.text, fontSize: 12)),
            const SizedBox(height: 4),
            Text(_error!,
                style: TextStyle(color: t.text3, fontSize: 9),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => _loadDir(),
                child: const Text('重试')),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return Center(
        child: Text('空目录', style: TextStyle(color: t.text3, fontSize: 11)),
      );
    }

    final dirs  = _entries.where((e) => e.isDir).toList();
    final files = _entries.where((e) => !e.isDir).toList();
    final all   = [...dirs, ...files];

    return ListView.builder(
      itemCount: all.length + (_currentPath != '/' ? 1 : 0),
      itemBuilder: (ctx, i) {
        // 返回上级
        if (_currentPath != '/' && i == 0) {
          return _EntryTile(
            icon: Icons.arrow_upward,
            iconColor: t.text3,
            name: '..',
            subtitle: '返回上级',
            onTap: _goUp,
          );
        }
        final entry = all[_currentPath != '/' ? i - 1 : i];
        return _EntryTile(
          icon: entry.isDir ? Icons.folder : _fileIcon(entry.name),
          iconColor: entry.isDir ? AppAccent.yellow : t.text2,
          name: entry.name,
          subtitle: entry.isDir ? '目录' : entry.sizeLabel,
          onTap: () => entry.isDir ? _navigate(entry) : null,
          actions: [
            if (!entry.isDir)
              IconButton(
                icon: Icon(Icons.download_outlined,
                    size: 14, color: AppAccent.blue),
                tooltip: '下载',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _download(entry),
              ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 14, color: AppAccent.red),
              tooltip: '删除',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _delete(entry),
            ),
          ],
        );
      },
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'exe': case 'dll': case 'bat': case 'ps1':
        return Icons.terminal;
      case 'sh': case 'py': case 'rb': case 'pl':
        return Icons.code;
      case 'zip': case 'tar': case 'gz': case '7z':
        return Icons.folder_zip_outlined;
      case 'txt': case 'log': case 'md':
        return Icons.description_outlined;
      case 'png': case 'jpg': case 'jpeg': case 'gif':
        return Icons.image_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 工具按钮
// ─────────────────────────────────────────────────────────────────────────────
class _ToolBtn extends StatefulWidget {
  final IconData icon;
  final String   tooltip;
  final VoidCallback onTap;
  const _ToolBtn({required this.icon, required this.tooltip, required this.onTap});
  @override
  State<_ToolBtn> createState() => _ToolBtnState();
}
class _ToolBtnState extends State<_ToolBtn> {
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
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: _hovered ? t.card : Colors.transparent,
              border: Border.all(
                  color: _hovered ? t.borderHi : Colors.transparent),
            ),
            child: Icon(widget.icon, size: 14, color: t.text2),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 文件/目录条目
// ─────────────────────────────────────────────────────────────────────────────
class _EntryTile extends StatefulWidget {
  final IconData   icon;
  final Color      iconColor;
  final String     name;
  final String     subtitle;
  final VoidCallback? onTap;
  final List<Widget> actions;
  const _EntryTile({
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.subtitle,
    this.onTap,
    this.actions = const [],
  });
  @override
  State<_EntryTile> createState() => _EntryTileState();
}
class _EntryTileState extends State<_EntryTile> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: _hovered ? t.card.withOpacity(0.6) : Colors.transparent,
          child: Row(
            children: [
              Icon(widget.icon, size: 14, color: widget.iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name,
                        style: TextStyle(
                            color: t.text,
                            fontSize: 11,
                            fontFamily: 'Consolas'),
                        overflow: TextOverflow.ellipsis),
                    Text(widget.subtitle,
                        style: TextStyle(color: t.text3, fontSize: 9)),
                  ],
                ),
              ),
              if (_hovered) ...widget.actions,
            ],
          ),
        ),
      ),
    );
  }
}
