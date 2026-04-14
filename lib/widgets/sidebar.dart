import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tool_model.dart';
import '../models/task_model.dart';
import '../providers/workflow_provider.dart';
import '../providers/task_provider.dart';
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
    // 初始化任务列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().initialize();
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
                const SizedBox(height: 8),
                // Tab Bar
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
          // ── Tab Content ─────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
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
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showCreateTaskDialog(context),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('新建任务', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppAccent.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
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
                  ? _EmptyTaskList(t: t)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      itemCount: taskProvider.tasks.length,
                      itemBuilder: (ctx, i) => _TaskCard(task: taskProvider.tasks[i]),
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
}

class _EmptyTaskList extends StatelessWidget {
  final AppThemeData t;
  const _EmptyTaskList({required this.t});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open, color: t.text3, size: 36),
          const SizedBox(height: 8),
          Text('暂无任务', style: TextStyle(color: t.text3, fontSize: 12)),
          const SizedBox(height: 4),
          Text('点击「新建任务」开始', style: TextStyle(color: t.text3, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── 任务卡片 ──────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final taskProvider = context.watch<TaskProvider>();
    final workflowProvider = context.read<WorkflowProvider>();
    final isActive = taskProvider.activeTask?.id == task.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isActive ? AppAccent.blue.withOpacity(0.12) : t.card,
        border: Border.all(
          color: isActive ? AppAccent.blue.withOpacity(0.5) : t.border,
          width: isActive ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: () => taskProvider.activateTask(task, workflowProvider),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Icon(
                    isActive ? Icons.folder_open : Icons.folder,
                    color: isActive ? AppAccent.blue : t.text3,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.name,
                      style: TextStyle(
                        color: isActive ? AppAccent.blue : t.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 删除按钮
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _confirmDelete(context, taskProvider, workflowProvider),
                      child: Tooltip(
                        message: '删除任务',
                        child: Icon(Icons.close, color: t.text3, size: 13),
                      ),
                    ),
                  ),
                ],
              ),
              // 描述
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.description,
                  style: TextStyle(color: t.text2, fontSize: 10),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              // 统计信息
              Row(
                children: [
                  _StatChip(
                    icon: Icons.account_tree,
                    label: '${_countNodes(task.workflowJson)} 节点',
                    t: t,
                  ),
                  const SizedBox(width: 4),
                  _StatChip(
                    icon: Icons.attach_file,
                    label: '${task.payloads.length} 载荷',
                    t: t,
                  ),
                  const SizedBox(width: 4),
                  _StatChip(
                    icon: Icons.description,
                    label: '${task.docs.length} 文档',
                    t: t,
                  ),
                ],
              ),
              // 创建时间
              const SizedBox(height: 4),
              Text(
                _formatDate(task.createdAt),
                style: TextStyle(color: t.text3, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _countNodes(String workflowJson) {
    try {
      final data = Map<String, dynamic>.from(
        (workflowJson.isNotEmpty ? workflowJson : '{}') as dynamic,
      );
      return (data['nodes'] as List?)?.length ?? 0;
    } catch (_) {
      return 0;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _confirmDelete(
    BuildContext context,
    TaskProvider taskProvider,
    WorkflowProvider workflowProvider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        final t = ctx.appTheme;
        return AlertDialog(
          backgroundColor: t.panel,
          title: Text('删除任务', style: TextStyle(color: t.text, fontSize: 14)),
          content: Text(
            '确定要删除任务「${task.name}」吗？\n相关文件将被永久删除。',
            style: TextStyle(color: t.text2, fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: t.text3)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                taskProvider.deleteTask(task.id, workflowProvider);
              },
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppThemeData t;
  const _StatChip({required this.icon, required this.label, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: t.bg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: t.text3, size: 9),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: t.text3, fontSize: 9)),
        ],
      ),
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
              // 标题
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

              // 任务名称
              _FieldLabel('任务名称', t),
              const SizedBox(height: 4),
              _buildTextField(_nameCtrl, '输入任务名称...', t),
              const SizedBox(height: 12),

              // 任务描述
              _FieldLabel('任务描述', t),
              const SizedBox(height: 4),
              _buildTextField(_descCtrl, '输入任务描述（可选）...', t, maxLines: 3),
              const SizedBox(height: 12),

              // 压缩包上传
              _FieldLabel('任务压缩包', t),
              const SizedBox(height: 4),
              _buildZipPicker(t),
              const SizedBox(height: 4),
              Text(
                '压缩包结构：workflow.json（必须）、payloads/（载荷）、docs/（文档）',
                style: TextStyle(color: t.text3, fontSize: 9),
              ),

              // 错误提示
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

              // 按钮
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
                            width: 14,
                            height: 14,
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

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    AppThemeData t, {
    int maxLines = 1,
  }) {
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
            style: _zipPath == null ? BorderStyle.solid : BorderStyle.solid,
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
                style: TextStyle(
                  color: _zipPath != null ? t.text : t.text3,
                  fontSize: 12,
                ),
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
    if (name.isEmpty) {
      setState(() => _error = '请输入任务名称');
      return;
    }
    if (_zipPath == null) {
      setState(() => _error = '请选择任务压缩包');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final taskProvider = context.read<TaskProvider>();
    final workflowProvider = context.read<WorkflowProvider>();

    final result = await taskProvider.createTask(
      name: name,
      description: _descCtrl.text.trim(),
      zipPath: _zipPath!,
      workflowProvider: workflowProvider,
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
// Tab 2：工具箱
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
    final workflowProvider = context.watch<WorkflowProvider>();
    final allTools = workflowProvider.allTools;
    final allCategories = workflowProvider.allCategories;

    // 搜索过滤
    final filtered = _searchQuery.isEmpty
        ? allTools
        : allTools.where((tool) =>
            tool.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            tool.desc.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            tool.tags.any((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()))
          ).toList();

    // 按分类分组
    final grouped = <String, List<ToolDefinition>>{};
    for (final tool in filtered) {
      grouped.putIfAbsent(tool.catId, () => []).add(tool);
    }

    return Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
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
        // 工具列表
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            children: allCategories.entries
                .where((e) => grouped.containsKey(e.key))
                .map((e) => _CategorySection(
                      category: e.value,
                      tools: grouped[e.key]!,
                      collapsed: _collapsed[e.key] ?? false,
                      onToggle: () => setState(() {
                        _collapsed[e.key] = !(_collapsed[e.key] ?? false);
                      }),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ── 分类区块 ──────────────────────────────────────────────────────────────────

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
        // 分类标题
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
                Text(
                  '${tools.length}',
                  style: TextStyle(color: t.text3, fontSize: 9),
                ),
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
        // 工具列表
        if (!collapsed)
          ...tools.map((tool) => _ToolItem(tool: tool)),
        const SizedBox(height: 2),
      ],
    );
  }
}

// ── 工具条目（可拖拽） ────────────────────────────────────────────────────────

class _ToolItem extends StatelessWidget {
  final ToolDefinition tool;
  const _ToolItem({required this.tool});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final cat = context.read<WorkflowProvider>().allCategories[tool.catId];

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
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
            ),
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
                // 风险标签
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
                // 分类颜色条
                if (cat != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: cat.color.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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
    final allCategories = context.watch<WorkflowProvider>().allCategories;

    return Container(
      width: 44,
      decoration: BoxDecoration(
        color: t.panel,
        border: Border(right: BorderSide(color: t.border)),
      ),
      child: Column(
        children: [
          // 展开按钮
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
          // 任务图标
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Tooltip(
              message: '任务管理',
              child: Icon(Icons.task_alt, color: t.text3, size: 16),
            ),
          ),
          Divider(color: t.border, height: 1),
          // 分类图标
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: allCategories.values.map((cat) => Padding(
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
