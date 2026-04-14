import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tool_model.dart';
import '../models/task_model.dart';
import '../providers/workflow_provider.dart';
import '../providers/task_provider.dart';
import '../providers/tool_provider.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 左侧面板：双 Tab（任务管理 / 工具箱）
// ─────────────────────────────────────────────────────────────────────────────

class Sidebar extends StatefulWidget {
  final bool collapsed;
  final VoidCallback onToggle;

  const Sidebar({
    super.key,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().initialize();
      context.read<ToolProvider>().init();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.collapsed) {
      return _CollapsedSidebar(onToggle: widget.onToggle);
    }

    final t = context.appTheme;

    return Container(
      decoration: BoxDecoration(
        color: t.panel,
        border: Border(right: BorderSide(color: t.border)),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(11, 9, 8, 0),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.border)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'PENFLOW',
                      style: TextStyle(
                        color: t.text3,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: widget.onToggle,
                        child: Tooltip(
                          message: '收起侧边栏',
                          child: Icon(Icons.chevron_left, color: t.text3, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TabBar(
                  controller: _tabController,
                  labelColor: AppAccent.blue,
                  unselectedLabelColor: t.text3,
                  indicatorColor: AppAccent.blue,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 11),
                  tabs: const [
                    Tab(text: '任务管理'),
                    Tab(text: '工具箱'),
                  ],
                ),
              ],
            ),
          ),

          // ── Tab Content ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _TaskTab(),
                _ToolboxTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1：任务管理
// ─────────────────────────────────────────────────────────────────────────────

class _TaskTab extends StatelessWidget {
  const _TaskTab();

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final taskProvider = context.watch<TaskProvider>();

    return Column(
      children: [
        // 新建任务按钮
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showCreateTaskDialog(context),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('新建任务', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppAccent.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ),

        // 任务列表
        Expanded(
          child: taskProvider.isLoading
              ? Center(child: CircularProgressIndicator(color: AppAccent.blue, strokeWidth: 2))
              : taskProvider.tasks.isEmpty
                  ? _EmptyTaskHint(t: t)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
                      itemCount: taskProvider.tasks.length,
                      itemBuilder: (ctx, i) {
                        final task = taskProvider.tasks[i];
                        final isActive = taskProvider.activeTask?.id == task.id;
                        return _TaskCard(
                          task: task,
                          isActive: isActive,
                          onTap: () {
                            final workflowProvider = context.read<WorkflowProvider>();
                            final toolProvider = context.read<ToolProvider>();
                            taskProvider.activateTask(task, workflowProvider, toolProvider);
                          },
                          onDelete: () => _confirmDelete(context, task, taskProvider),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showCreateTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateTaskDialog(),
    );
  }

  void _confirmDelete(BuildContext context, TaskModel task, TaskProvider taskProvider) {
    final t = context.appTheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text('删除任务', style: TextStyle(color: t.text, fontSize: 14)),
        content: Text(
          '确定要删除任务「${task.name}」吗？\n相关文件和工具数据将一并删除。',
          style: TextStyle(color: t.text2, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: t.text3)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final workflowProvider = context.read<WorkflowProvider>();
              final toolProvider = context.read<ToolProvider>();
              taskProvider.deleteTask(task.id, workflowProvider, toolProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('删除', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _EmptyTaskHint extends StatelessWidget {
  final AppThemeData t;
  const _EmptyTaskHint({required this.t});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.task_alt, color: t.text3, size: 32),
          const SizedBox(height: 8),
          Text('暂无任务', style: TextStyle(color: t.text3, fontSize: 12)),
          const SizedBox(height: 4),
          Text('点击上方按钮新建任务', style: TextStyle(color: t.text3, fontSize: 10)),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? AppAccent.blue.withOpacity(0.12) : t.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? AppAccent.blue.withOpacity(0.5) : t.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.folder_open,
                  color: isActive ? AppAccent.blue : t.text3,
                  size: 13,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    task.name,
                    style: TextStyle(
                      color: isActive ? AppAccent.blue : t.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppAccent.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '活跃',
                      style: TextStyle(color: AppAccent.blue, fontSize: 8, fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(Icons.delete_outline, color: t.text3, size: 13),
                ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                task.description,
                style: TextStyle(color: t.text3, fontSize: 9),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                _FileChip('📦 ${task.payloads.length} 载荷', t),
                const SizedBox(width: 4),
                _FileChip('📝 ${task.docs.length} 文档', t),
                const Spacer(),
                Text(
                  _formatDate(task.createdAt),
                  style: TextStyle(color: t.text3, fontSize: 8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _FileChip extends StatelessWidget {
  final String label;
  final AppThemeData t;
  const _FileChip(this.label, this.t);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: t.border),
      ),
      child: Text(label, style: TextStyle(color: t.text3, fontSize: 8)),
    );
  }
}

// ── 新建任务对话框 ─────────────────────────────────────────────────────────────

class _CreateTaskDialog extends StatefulWidget {
  const _CreateTaskDialog();

  @override
  State<_CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<_CreateTaskDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _zipPath;
  String? _zipName;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;

    return Dialog(
      backgroundColor: t.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: 440,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.add_box, color: AppAccent.blue, size: 18),
                  const SizedBox(width: 8),
                  Text('新建任务', style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: t.text3, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _FieldLabel('任务名称', t),
              const SizedBox(height: 4),
              _buildTextField(_nameCtrl, '输入任务名称...', t),
              const SizedBox(height: 12),
              _FieldLabel('任务描述', t),
              const SizedBox(height: 4),
              _buildTextField(_descCtrl, '输入任务描述（可选）...', t, maxLines: 3),
              const SizedBox(height: 12),
              _FieldLabel('任务压缩包', t),
              const SizedBox(height: 4),
              _buildZipPicker(t),
              const SizedBox(height: 4),
              Text(
                '压缩包结构：workflow.json（必须）、payloads/（载荷）、docs/（文档）',
                style: TextStyle(color: t.text3, fontSize: 9),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: Text('取消', style: TextStyle(color: t.text3)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppAccent.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('创建', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _FieldLabel(String text, AppThemeData t) {
    return Text(text, style: TextStyle(color: t.text2, fontSize: 11, fontWeight: FontWeight.w500));
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, AppThemeData t, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(color: t.text, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: t.text3, fontSize: 12),
        filled: true,
        fillColor: t.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppAccent.blue),
        ),
      ),
    );
  }

  Widget _buildZipPicker(AppThemeData t) {
    return GestureDetector(
      onTap: _pickZip,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: t.bg,
          border: Border.all(
            color: _zipPath != null ? AppAccent.blue.withOpacity(0.5) : t.border,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              _zipPath != null ? Icons.check_circle : Icons.upload_file,
              color: _zipPath != null ? AppColors.green : t.text3,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _zipName ?? '点击选择 .zip 压缩包...',
                style: TextStyle(color: _zipPath != null ? t.text : t.text3, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_zipPath != null)
              GestureDetector(
                onTap: () => setState(() { _zipPath = null; _zipName = null; }),
                child: Icon(Icons.close, color: t.text3, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickZip() async {
    final taskProvider = context.read<TaskProvider>();
    final path = await taskProvider.pickZipFile();
    if (path != null) {
      setState(() {
        _zipPath = path;
        _zipName = path.split(Platform.pathSeparator).last;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { setState(() => _error = '请输入任务名称'); return; }
    if (_zipPath == null) { setState(() => _error = '请选择任务压缩包'); return; }

    setState(() { _loading = true; _error = null; });

    final taskProvider = context.read<TaskProvider>();
    final workflowProvider = context.read<WorkflowProvider>();
    final toolProvider = context.read<ToolProvider>();

    final result = await taskProvider.createTask(
      name: name,
      description: _descCtrl.text.trim(),
      zipPath: _zipPath!,
      workflowProvider: workflowProvider,
      toolProvider: toolProvider,
    );

    if (!mounted) return;

    if (result != null && result.success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('任务「$name」创建成功，工作流已加载'),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      setState(() {
        _loading = false;
        _error = result?.error ?? '创建失败，请重试';
      });
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2：工具箱（从 ToolProvider / SQLite 读取）
// ─────────────────────────────────────────────────────────────────────────────

class _ToolboxTab extends StatefulWidget {
  const _ToolboxTab();

  @override
  State<_ToolboxTab> createState() => _ToolboxTabState();
}

class _ToolboxTabState extends State<_ToolboxTab> {
  String _searchQuery = '';
  final Map<String, bool> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final toolProvider = context.watch<ToolProvider>();

    if (!toolProvider.initialized) {
      return Center(
        child: CircularProgressIndicator(color: AppAccent.blue, strokeWidth: 2),
      );
    }

    final allTools = _searchQuery.isEmpty
        ? toolProvider.tools
        : toolProvider.searchTools(_searchQuery);

    // 按分类分组
    final grouped = <String, List<ToolDefinition>>{};
    for (final tool in allTools) {
      grouped.putIfAbsent(tool.catId, () => []).add(tool);
    }

    return Column(
      children: [
        // 搜索框 + 工具管理按钮
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: TextStyle(color: t.text, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: '搜索工具...',
                    hintStyle: TextStyle(color: t.text3, fontSize: 11),
                    prefixIcon: Icon(Icons.search, color: t.text3, size: 14),
                    filled: true,
                    fillColor: t.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: t.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: t.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: AppAccent.blue),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // 工具管理菜单按钮
              PopupMenuButton<String>(
                tooltip: '工具管理',
                color: t.panel,
                icon: Icon(Icons.more_vert, color: t.text3, size: 16),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'add_tool',
                    child: Row(children: [
                      Icon(Icons.add, color: AppAccent.blue, size: 14),
                      const SizedBox(width: 8),
                      Text('新增工具', style: TextStyle(color: t.text, fontSize: 12)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'import_json',
                    child: Row(children: [
                      Icon(Icons.upload_file, color: AppAccent.green, size: 14),
                      const SizedBox(width: 8),
                      Text('导入工具配置', style: TextStyle(color: t.text, fontSize: 12)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'export_json',
                    child: Row(children: [
                      Icon(Icons.download, color: t.text3, size: 14),
                      const SizedBox(width: 8),
                      Text('导出工具配置', style: TextStyle(color: t.text, fontSize: 12)),
                    ]),
                  ),
                ],
                onSelected: (val) {
                  switch (val) {
                    case 'add_tool':
                      _showAddToolDialog(context);
                      break;
                    case 'import_json':
                      _showImportJsonDialog(context);
                      break;
                    case 'export_json':
                      _showExportJsonDialog(context);
                      break;
                  }
                },
              ),
            ],
          ),
        ),

        // 工具列表
        Expanded(
          child: grouped.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isEmpty ? '工具箱为空' : '未找到匹配工具',
                    style: TextStyle(color: t.text3, fontSize: 12),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                  children: toolProvider.categories
                      .where((cat) => grouped.containsKey(cat.id))
                      .map((cat) => _CategorySection(
                            category: cat,
                            tools: grouped[cat.id]!,
                            collapsed: _collapsed[cat.id] ?? false,
                            onToggle: () => setState(() {
                              _collapsed[cat.id] = !(_collapsed[cat.id] ?? false);
                            }),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }

  // ── 新增工具对话框 ──────────────────────────────────────────────────────────

  void _showAddToolDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AddEditToolDialog(toolProvider: context.read<ToolProvider>()),
    );
  }

  // ── 导入 JSON 对话框 ────────────────────────────────────────────────────────

  void _showImportJsonDialog(BuildContext context) {
    final t = context.appTheme;
    final ctrl = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: t.panel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: SizedBox(
            width: 520,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.upload_file, color: AppAccent.green, size: 18),
                      const SizedBox(width: 8),
                      Text('导入工具配置', style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close, color: t.text3, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('粘贴工具配置 JSON：', style: TextStyle(color: t.text2, fontSize: 11)),
                  const SizedBox(height: 6),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: t.bg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: t.border),
                    ),
                    child: TextField(
                      controller: ctrl,
                      maxLines: null,
                      expands: true,
                      style: TextStyle(color: t.text, fontSize: 11, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        hintText: '{"categories": [...], "tools": [...]}',
                        hintStyle: TextStyle(color: t.text3, fontSize: 10),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red, fontSize: 11)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('取消', style: TextStyle(color: t.text3)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final json = ctrl.text.trim();
                          if (json.isEmpty) {
                            setS(() => error = '请输入 JSON 内容');
                            return;
                          }
                          try {
                            final toolProvider = context.read<ToolProvider>();
                            final result = await toolProvider.importFromJson(json);
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '导入成功：${result['categories']} 个分类，${result['tools']} 个工具',
                                ),
                                backgroundColor: AppColors.green,
                              ),
                            );
                          } catch (e) {
                            setS(() => error = '导入失败：$e');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppAccent.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('导入', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 导出 JSON 对话框 ────────────────────────────────────────────────────────

  void _showExportJsonDialog(BuildContext context) {
    final t = context.appTheme;
    final toolProvider = context.read<ToolProvider>();
    final json = toolProvider.exportToolsJson();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: t.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: SizedBox(
          width: 520,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.download, color: t.text3, size: 18),
                    const SizedBox(width: 8),
                    Text('导出工具配置', style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close, color: t.text3, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('工具配置 JSON（可复制后导入其他实例）：', style: TextStyle(color: t.text2, fontSize: 11)),
                const SizedBox(height: 6),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: t.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: t.border),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(10),
                    child: SelectableText(
                      json,
                      style: TextStyle(color: t.text, fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppAccent.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('关闭', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 分类区块
// ─────────────────────────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final ToolCategory category;
  final List<ToolDefinition> tools;
  final bool collapsed;
  final VoidCallback onToggle;

  const _CategorySection({
    required this.category,
    required this.tools,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Row(
              children: [
                Text(category.icon, style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    category.label,
                    style: TextStyle(
                      color: t.text3,
                      fontSize: 10,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text('${tools.length}', style: TextStyle(color: t.text3, fontSize: 9)),
                const SizedBox(width: 4),
                Icon(
                  collapsed ? Icons.chevron_right : Icons.expand_more,
                  color: t.text3,
                  size: 13,
                ),
              ],
            ),
          ),
        ),
        if (!collapsed)
          ...tools.map((tool) => _ToolItem(tool: tool, category: category)),
        const SizedBox(height: 2),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 工具条目（可拖拽，右键菜单编辑/删除）
// ─────────────────────────────────────────────────────────────────────────────

class _ToolItem extends StatelessWidget {
  final ToolDefinition tool;
  final ToolCategory category;
  const _ToolItem({required this.tool, required this.category});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;

    return Draggable<String>(
      data: tool.id,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 160,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppAccent.blue.withOpacity(0.5)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tool.icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  tool.name,
                  style: TextStyle(color: t.text, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      child: GestureDetector(
        onSecondaryTapUp: (details) => _showContextMenu(context, details.globalPosition),
        child: Container(
          margin: const EdgeInsets.only(bottom: 1),
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
              child: Row(
                children: [
                  Text(tool.icon, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tool.name,
                          style: TextStyle(color: t.text, fontSize: 11, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          tool.desc,
                          style: TextStyle(color: t.text3, fontSize: 9),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  if (tool.risk != RiskLevel.none)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: tool.risk.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        tool.risk.label,
                        style: TextStyle(color: tool.risk.color, fontSize: 8),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final t = context.appTheme;
    final toolProvider = context.read<ToolProvider>();

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      color: t.panel,
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit, color: AppAccent.blue, size: 14),
            const SizedBox(width: 8),
            Text('编辑工具', style: TextStyle(color: t.text, fontSize: 12)),
          ]),
        ),
        if (!tool.isBuiltin)
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              const Icon(Icons.delete_outline, color: Colors.red, size: 14),
              const SizedBox(width: 8),
              const Text('删除工具', style: TextStyle(color: Colors.red, fontSize: 12)),
            ]),
          ),
      ],
    ).then((val) {
      if (val == 'edit') {
        showDialog(
          context: context,
          builder: (_) => _AddEditToolDialog(toolProvider: toolProvider, editTool: tool),
        );
      } else if (val == 'delete') {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: t.panel,
            title: Text('删除工具', style: TextStyle(color: t.text, fontSize: 14)),
            content: Text('确定删除「${tool.name}」？', style: TextStyle(color: t.text2, fontSize: 12)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('取消', style: TextStyle(color: t.text3)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  toolProvider.deleteTool(tool.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('删除', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 新增/编辑工具对话框
// ─────────────────────────────────────────────────────────────────────────────

class _AddEditToolDialog extends StatefulWidget {
  final ToolProvider toolProvider;
  final ToolDefinition? editTool;

  const _AddEditToolDialog({required this.toolProvider, this.editTool});

  @override
  State<_AddEditToolDialog> createState() => _AddEditToolDialogState();
}

class _AddEditToolDialogState extends State<_AddEditToolDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _iconCtrl;
  late TextEditingController _versionCtrl;
  late TextEditingController _usageCtrl;
  String? _selectedCatId;
  RiskLevel _risk = RiskLevel.low;
  bool _loading = false;
  String? _error;

  bool get isEdit => widget.editTool != null;

  @override
  void initState() {
    super.initState();
    final tool = widget.editTool;
    _nameCtrl    = TextEditingController(text: tool?.name ?? '');
    _descCtrl    = TextEditingController(text: tool?.desc ?? '');
    _iconCtrl    = TextEditingController(text: tool?.icon ?? '🔧');
    _versionCtrl = TextEditingController(text: tool?.version ?? '');
    _usageCtrl   = TextEditingController(text: tool?.usage ?? '');
    _selectedCatId = tool?.catId;
    _risk = tool?.risk ?? RiskLevel.low;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _iconCtrl.dispose();
    _versionCtrl.dispose();
    _usageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final categories = widget.toolProvider.categories;

    return Dialog(
      backgroundColor: t.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isEdit ? Icons.edit : Icons.add, color: AppAccent.blue, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? '编辑工具' : '新增工具',
                    style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: t.text3, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 名称 + 图标
              Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: _buildField('图标', _iconCtrl, '🔧', t),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _buildField('工具名称', _nameCtrl, '输入工具名称...', t)),
                ],
              ),
              const SizedBox(height: 10),

              // 描述
              _buildField('描述', _descCtrl, '工具简短描述...', t),
              const SizedBox(height: 10),

              // 分类 + 版本
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('分类', style: TextStyle(color: t.text2, fontSize: 11, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: t.bg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: t.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCatId,
                              hint: Text('选择分类', style: TextStyle(color: t.text3, fontSize: 11)),
                              dropdownColor: t.panel,
                              isExpanded: true,
                              style: TextStyle(color: t.text, fontSize: 11),
                              items: categories.map((cat) => DropdownMenuItem(
                                value: cat.id,
                                child: Text('${cat.icon} ${cat.label}', style: TextStyle(color: t.text, fontSize: 11)),
                              )).toList(),
                              onChanged: (v) => setState(() => _selectedCatId = v),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildField('版本', _versionCtrl, '1.0.0', t),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 风险等级
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('风险等级', style: TextStyle(color: t.text2, fontSize: 11, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Row(
                    children: RiskLevel.values.where((r) => r != RiskLevel.none).map((r) {
                      final selected = _risk == r;
                      return GestureDetector(
                        onTap: () => setState(() => _risk = r),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: selected ? r.color.withOpacity(0.2) : t.bg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: selected ? r.color : t.border,
                            ),
                          ),
                          child: Text(
                            r.label,
                            style: TextStyle(
                              color: selected ? r.color : t.text3,
                              fontSize: 10,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 使用文档
              _buildField('使用文档（Markdown）', _usageCtrl, '## 工具名\n\n工具使用说明...', t, maxLines: 4),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 11)),
              ],

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('取消', style: TextStyle(color: t.text3)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppAccent.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(isEdit ? '保存' : '添加', style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, AppThemeData t, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: t.text2, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: TextStyle(color: t.text, fontSize: 12),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: t.text3, fontSize: 11),
            filled: true,
            fillColor: t.bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: t.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: t.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AppAccent.blue),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { setState(() => _error = '请输入工具名称'); return; }
    if (_selectedCatId == null) { setState(() => _error = '请选择工具分类'); return; }

    setState(() { _loading = true; _error = null; });

    try {
      if (isEdit) {
        await widget.toolProvider.updateTool(
          widget.editTool!.id,
          name: name,
          desc: _descCtrl.text.trim(),
          icon: _iconCtrl.text.trim().isEmpty ? '🔧' : _iconCtrl.text.trim(),
          catId: _selectedCatId,
          version: _versionCtrl.text.trim(),
          risk: _risk,
          usage: _usageCtrl.text.trim(),
        );
      } else {
        await widget.toolProvider.addTool(
          name: name,
          desc: _descCtrl.text.trim(),
          icon: _iconCtrl.text.trim().isEmpty ? '🔧' : _iconCtrl.text.trim(),
          catId: _selectedCatId!,
          version: _versionCtrl.text.trim(),
          risk: _risk,
          usage: _usageCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _loading = false; _error = '操作失败：$e'; });
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 收缩模式侧边栏
// ─────────────────────────────────────────────────────────────────────────────

class _CollapsedSidebar extends StatelessWidget {
  final VoidCallback onToggle;
  const _CollapsedSidebar({required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final categories = context.watch<ToolProvider>().categories;

    return Container(
      width: 44,
      decoration: BoxDecoration(
        color: t.panel,
        border: Border(right: BorderSide(color: t.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onToggle,
                child: Tooltip(
                  message: '展开侧边栏',
                  child: Icon(Icons.chevron_right, color: t.text3, size: 18),
                ),
              ),
            ),
          ),
          Divider(color: t.border, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Tooltip(
              message: '任务管理',
              child: Icon(Icons.task_alt, color: t.text3, size: 16),
            ),
          ),
          Divider(color: t.border, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: categories.map((cat) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Tooltip(
                  message: cat.label,
                  child: Center(
                    child: Text(cat.icon, style: const TextStyle(fontSize: 14)),
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
