import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/tools_data.dart';
import '../models/tool_model.dart';
import '../providers/workflow_provider.dart';
import '../utils/app_theme.dart';

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

class _SidebarState extends State<Sidebar> {
  String _searchQuery = '';
  final Map<String, bool> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;

    if (widget.collapsed) {
      return _CollapsedSidebar(onToggle: widget.onToggle);
    }

    return Container(
      decoration: BoxDecoration(
        color: t.panel,
        border: Border(right: BorderSide(color: t.border)),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(11, 9, 8, 7),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '🛠 工具箱',
                      style: TextStyle(
                        color: t.text3,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    // 收起按钮
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: widget.onToggle,
                        child: Tooltip(
                          message: '收起工具箱',
                          child: Icon(Icons.chevron_left,
                              color: t.text3, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: TextStyle(color: t.text, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: '搜索工具...',
                    prefixIcon:
                        Icon(Icons.search, color: t.text3, size: 14),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          // ── Tool List ────────────────────────────────────
          Expanded(
            child: Scrollbar(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: _buildCategories(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategories() {
    final result = <Widget>[];
    for (final entry in kCategories.entries) {
      final catId = entry.key;
      final cat   = entry.value;
      final tools = kTools.where((t) {
        if (t.catId != catId) return false;
        if (_searchQuery.isEmpty) return true;
        final q = _searchQuery.toLowerCase();
        return t.name.toLowerCase().contains(q) ||
            t.desc.toLowerCase().contains(q);
      }).toList();

      if (tools.isEmpty) continue;

      final isCollapsed = _collapsed[catId] ?? false;

      result.add(_CategoryHeader(
        cat: cat,
        isCollapsed: isCollapsed,
        onTap: () => setState(() => _collapsed[catId] = !isCollapsed),
      ));

      if (!isCollapsed) {
        result.addAll(tools.map((t) => _ToolItem(tool: t, cat: cat)));
      }
    }
    return result;
  }
}

// ── 收缩状态侧边栏（仅显示图标）────────────────────────────
class _CollapsedSidebar extends StatelessWidget {
  final VoidCallback onToggle;
  const _CollapsedSidebar({required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
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
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onToggle,
                child: Tooltip(
                  message: '展开工具箱',
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: t.border),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.chevron_right,
                        color: t.text3, size: 16),
                  ),
                ),
              ),
            ),
          ),
          Container(height: 1, color: t.border),
          // 分类图标列表
          Expanded(
            child: Scrollbar(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: kCategories.entries.map((entry) {
                  final cat = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 3, horizontal: 6),
                    child: Tooltip(
                      message: cat.label,
                      preferBelow: false,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: onToggle,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: cat.color.withOpacity(0.1),
                              border: Border.all(
                                  color: cat.color.withOpacity(0.3)),
                            ),
                            alignment: Alignment.center,
                            child: Text(cat.icon,
                                style: const TextStyle(fontSize: 14)),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category Header ──────────────────────────────────────
class _CategoryHeader extends StatefulWidget {
  final ToolCategory cat;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _CategoryHeader({
    required this.cat,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  State<_CategoryHeader> createState() => _CategoryHeaderState();
}

class _CategoryHeaderState extends State<_CategoryHeader> {
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
          padding:
              const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          child: Row(
            children: [
              Text(widget.cat.icon,
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
              Text(
                widget.cat.label,
                style: TextStyle(
                  color: _hovered ? t.text2 : widget.cat.color,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: widget.isCollapsed ? -0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: Text('▾',
                    style: TextStyle(color: t.text3, fontSize: 9)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tool Item ────────────────────────────────────────────
class _ToolItem extends StatefulWidget {
  final ToolDefinition tool;
  final ToolCategory cat;

  const _ToolItem({required this.tool, required this.cat});

  @override
  State<_ToolItem> createState() => _ToolItemState();
}

class _ToolItemState extends State<_ToolItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 1, 5, 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.grab,
        child: Draggable<String>(
          data: widget.tool.id,
          onDragStarted: () {},
          onDragEnd: (_) {},
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: widget.cat.color.withOpacity(0.5)),
              ),
              child: Text(
                '${widget.tool.icon} ${widget.tool.name}',
                style: TextStyle(color: t.text, fontSize: 11),
              ),
            ),
          ),
          child: GestureDetector(
            onTap: () =>
                context.read<WorkflowProvider>().selectNode(null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: _hovered ? t.card : Colors.transparent,
                border: Border.all(
                  color: _hovered ? t.border : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: widget.cat.color.withOpacity(0.13),
                      border: Border.all(
                          color: widget.cat.color.withOpacity(0.25)),
                    ),
                    alignment: Alignment.center,
                    child: Text(widget.tool.icon,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.tool.name,
                          style:
                              TextStyle(color: t.text, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.tool.desc,
                          style: TextStyle(
                              color: t.text3, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
}
