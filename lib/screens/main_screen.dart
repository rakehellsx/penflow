import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workflow_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/top_bar.dart';
import '../widgets/sidebar.dart';
import '../widgets/canvas_area.dart';
import '../widgets/right_panel.dart';
import '../widgets/vm_panel.dart';
import '../widgets/change_password_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _vmPanelOpen  = false;
  String? _vmPanelNodeId;
  int  _rightPanelTab = 0;
  bool _sidebarCollapsed = false;

  void _openVMPanel(String nodeId) =>
      setState(() { _vmPanelOpen = true; _vmPanelNodeId = nodeId; });

  void _closeVMPanel() =>
      setState(() { _vmPanelOpen = false; _vmPanelNodeId = null; });

  void _switchRightTab(int tab) => setState(() => _rightPanelTab = tab);

  void _toggleSidebar() =>
      setState(() => _sidebarCollapsed = !_sidebarCollapsed);

  // ── 加载对话框（JSON 导入）─────────────────────────────
  void _showLoadDialog() {
    final t = context.appTheme;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.panel,
        title: Row(
          children: [
            const Text('📂', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text('加载工作流',
                style: TextStyle(color: t.text, fontSize: 14)),
          ],
        ),
        content: SizedBox(
          width: 640,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '粘贴工作流 JSON 内容（从导出文件复制），或点击"从本地加载"读取上次保存的工作流',
                style: TextStyle(color: t.text3, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: t.bg,
                    border: Border.all(color: t.border),
                  ),
                  child: TextField(
                    controller: ctrl,
                    maxLines: null,
                    expands: true,
                    style: TextStyle(
                        color: t.text2,
                        fontSize: 11,
                        fontFamily: 'Consolas'),
                    decoration: InputDecoration(
                      hintText:
                          '{\n  "version": "1.0",\n  "nodes": [...],\n  ...\n}',
                      hintStyle:
                          TextStyle(color: t.text3, fontSize: 11),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<WorkflowProvider>().loadWorkflow();
            },
            child: Text('从本地加载',
                style: TextStyle(color: t.text2, fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消',
                style: TextStyle(color: t.text3, fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppAccent.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final json = ctrl.text.trim();
              if (json.isEmpty) return;
              context.read<WorkflowProvider>().importWorkflow(json);
              Navigator.pop(ctx);
            },
            child: const Text('导入 JSON',
                style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── 导出对话框 ─────────────────────────────────────────
  void _showExportDialog() {
    final t    = context.appTheme;
    final json = context.read<WorkflowProvider>().exportWorkflow();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.panel,
        title: Row(
          children: [
            const Text('📤', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text('导出工作流',
                style: TextStyle(color: t.text, fontSize: 14)),
          ],
        ),
        content: SizedBox(
          width: 640,
          height: 420,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: t.bg,
              border: Border.all(color: t.border),
            ),
            padding: const EdgeInsets.all(10),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: SelectableText(
                  json,
                  style: TextStyle(
                    color: t.text2,
                    fontSize: 11,
                    fontFamily: 'Consolas',
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭',
                style: TextStyle(color: AppAccent.blue)),
          ),
        ],
      ),
    );
  }

  // ── 清空确认 ───────────────────────────────────────────
  void _showClearConfirm() {
    final t = context.appTheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.panel,
        title: Text('清空画布',
            style: TextStyle(color: t.text, fontSize: 14)),
        content: Text(
          '确定要清空所有节点和连线吗？此操作不可撤销。',
          style: TextStyle(color: t.text2, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: t.text2)),
          ),
          TextButton(
            onPressed: () {
              context.read<WorkflowProvider>().clearCanvas();
              Navigator.pop(ctx);
            },
            child: const Text('清空',
                style: TextStyle(color: AppAccent.red)),
          ),
        ],
      ),
    );
  }

  // ── 修改密码 ───────────────────────────────────────────
  void _showChangePassword() {
    showDialog(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
  }

  // ── 退出登录 ───────────────────────────────────────────
  void _logout() {
    context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    const double sidebarFullWidth     = 260;
    const double sidebarCollapseWidth = 44;
    final double sidebarWidth =
        _sidebarCollapsed ? sidebarCollapseWidth : sidebarFullWidth;

    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          TopBar(
            onSave:       () => context.read<WorkflowProvider>().saveWorkflow(),
            onLoad:       _showLoadDialog,
            onExport:     _showExportDialog,
            onAutoLayout: () => context.read<WorkflowProvider>().autoLayout(),
            onFitView: () {
              final size = MediaQuery.of(context).size;
              context.read<WorkflowProvider>().fitView(Size(
                size.width - sidebarWidth - 300,
                size.height - 44,
              ));
            },
            onClear:          _showClearConfirm,
            onToggleSidebar:  _toggleSidebar,
            sidebarCollapsed: _sidebarCollapsed,
            onChangePassword: _showChangePassword,
            onLogout:         _logout,
          ),
          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    // ── 侧边栏 ──────────────────────────────
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      width: sidebarWidth,
                      child: Sidebar(
                        collapsed: _sidebarCollapsed,
                        onToggle:  _toggleSidebar,
                      ),
                    ),
                    // ── 画布 ────────────────────────────────
                    Expanded(
                      child: CanvasArea(
                        onOpenVMPanel: _openVMPanel,
                        onSwitchTab:   _switchRightTab,
                      ),
                    ),
                    // ── 右侧面板 ────────────────────────────
                    SizedBox(
                      width: 300,
                      child: RightPanel(
                        activeTab:   _rightPanelTab,
                        onTabChange: _switchRightTab,
                      ),
                    ),
                  ],
                ),
                // ── VM 选择面板 ─────────────────────────────
                if (_vmPanelOpen)
                  Positioned(
                    bottom: 0,
                    left:   sidebarWidth,
                    right:  300,
                    child: VmPanel(
                      nodeId:  _vmPanelNodeId!,
                      onClose: _closeVMPanel,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
