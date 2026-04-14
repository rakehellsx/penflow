import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workflow_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/top_bar.dart';
import '../widgets/sidebar.dart';
import '../widgets/canvas_area.dart';
import '../widgets/right_panel.dart';
import '../widgets/vm_panel.dart';
import '../widgets/attack_chain_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _vmPanelOpen = false;
  String? _vmPanelNodeId;
  int _rightPanelTab = 0;

  void _openVMPanel(String nodeId) {
    setState(() {
      _vmPanelOpen = true;
      _vmPanelNodeId = nodeId;
    });
  }

  void _closeVMPanel() {
    setState(() {
      _vmPanelOpen = false;
      _vmPanelNodeId = null;
    });
  }

  void _switchRightTab(int tab) {
    setState(() => _rightPanelTab = tab);
  }

  void _showAttackChainDialog() {
    showDialog(
      context: context,
      builder: (_) => AttackChainDialog(
        onChainSelected: (chain) {
          context.read<WorkflowProvider>().loadAttackChain(chain);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          TopBar(
            onSave:       () => context.read<WorkflowProvider>().saveWorkflow(),
            onLoad:       () => context.read<WorkflowProvider>().loadWorkflow(),
            onExport:     _showExportDialog,
            onAutoLayout: () => context.read<WorkflowProvider>().autoLayout(),
            onFitView: () {
              final size = MediaQuery.of(context).size;
              context.read<WorkflowProvider>().fitView(Size(
                size.width - 260 - 300,
                size.height - 44,
              ));
            },
            onClear:     _showClearConfirm,
            onLoadChain: _showAttackChainDialog,
          ),
          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 260, child: Sidebar()),
                    Expanded(
                      child: CanvasArea(
                        onOpenVMPanel: _openVMPanel,
                        onSwitchTab:   _switchRightTab,
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: RightPanel(
                        activeTab:   _rightPanelTab,
                        onTabChange: _switchRightTab,
                      ),
                    ),
                  ],
                ),
                if (_vmPanelOpen)
                  Positioned(
                    bottom: 0,
                    left:   260,
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

  void _showExportDialog() {
    final t    = context.appTheme;
    final json = context.read<WorkflowProvider>().exportWorkflow();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.panel,
        title: Text('导出工作流',
            style: TextStyle(color: t.text, fontSize: 14)),
        content: SizedBox(
          width: 600,
          height: 400,
          child: SelectableText(
            json,
            style: TextStyle(
              color: t.text2,
              fontSize: 11,
              fontFamily: 'Consolas',
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
}
