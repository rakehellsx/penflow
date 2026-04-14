import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/tools_data.dart';
import '../models/tool_model.dart';
import '../providers/workflow_provider.dart';
import '../utils/app_theme.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  String _searchQuery = '';
  final Map<String, bool> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 7),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🛠 工具箱',
                  style: TextStyle(
                    color: AppColors.text3,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: AppColors.text, fontSize: 11),
                  decoration: const InputDecoration(
                    hintText: '搜索工具...',
                    prefixIcon: Icon(Icons.search, color: AppColors.text3, size: 14),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          // Tool List
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
      final cat = entry.value;
      final tools = kTools.where((t) {
        if (t.catId != catId) return false;
        if (_searchQuery.isEmpty) return true;
        final q = _searchQuery.toLowerCase();
        return t.name.toLowerCase().contains(q) || t.desc.toLowerCase().contains(q);
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          child: Row(
            children: [
              Text(widget.cat.icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
              Text(
                widget.cat.label,
                style: TextStyle(
                  color: _hovered ? AppColors.text2 : widget.cat.color,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: widget.isCollapsed ? -0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Text('▾', style: TextStyle(color: AppColors.text3, fontSize: 9)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 1, 5, 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.grab,
        child: Draggable<String>(
          data: widget.tool.id,
          onDragStarted: () {},
          onDragEnd: (_) {},
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: widget.cat.color.withOpacity(0.5)),
              ),
              child: Text(
                '${widget.tool.icon} ${widget.tool.name}',
                style: const TextStyle(color: AppColors.text, fontSize: 11),
              ),
            ),
          ),
          child: GestureDetector(
            onTap: () {
              // Show docs in right panel
              context.read<WorkflowProvider>().selectNode(null);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: _hovered ? AppColors.card : Colors.transparent,
                border: Border.all(
                  color: _hovered ? AppColors.border : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: widget.cat.color.withOpacity(0.13),
                      border: Border.all(color: widget.cat.color.withOpacity(0.25)),
                    ),
                    alignment: Alignment.center,
                    child: Text(widget.tool.icon, style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 7),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.tool.name,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.tool.desc,
                          style: const TextStyle(
                            color: AppColors.text3,
                            fontSize: 10,
                          ),
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
