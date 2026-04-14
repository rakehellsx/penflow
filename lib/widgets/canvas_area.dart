import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/workflow_provider.dart';
import '../providers/vm_manager_provider.dart';
import '../models/tool_model.dart';
import '../data/tools_data.dart';
import '../services/vm_backend.dart';
import '../utils/app_theme.dart';
import 'node_card.dart';
import 'connection_painter.dart';

class CanvasArea extends StatefulWidget {
  final Function(String nodeId) onOpenVMPanel;
  final Function(int tab) onSwitchTab;

  const CanvasArea({
    super.key,
    required this.onOpenVMPanel,
    required this.onSwitchTab,
  });

  @override
  State<CanvasArea> createState() => _CanvasAreaState();
}

class _CanvasAreaState extends State<CanvasArea> {
  bool _spaceDown = false;
  bool _panning = false;
  Offset _panStart = Offset.zero;
  Offset _panStartOffset = Offset.zero;
  // For connection drawing
  String? _draggingFromPort;
  Offset? _portDragCurrent;

  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkflowProvider>(
      builder: (context, provider, _) {
        return KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.space) {
                setState(() => _spaceDown = true);
              } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                provider.cancelConnecting();
                setState(() {
                  _draggingFromPort = null;
                  _portDragCurrent = null;
                });
              } else if (event.logicalKey == LogicalKeyboardKey.delete ||
                  event.logicalKey == LogicalKeyboardKey.backspace) {
                if (provider.selectedNodeId != null) {
                  provider.deleteNode(provider.selectedNodeId!);
                }
              }
            } else if (event is KeyUpEvent) {
              if (event.logicalKey == LogicalKeyboardKey.space) {
                setState(() => _spaceDown = false);
              }
            }
          },
          child: DragTarget<String>(
            onAcceptWithDetails: (details) {
              final box = context.findRenderObject() as RenderBox;
              final localPos = box.globalToLocal(details.offset);
              final canvasPos = Offset(
                (localPos.dx - provider.offset.dx) / provider.scale,
                (localPos.dy - provider.offset.dy) / provider.scale,
              );
              provider.addNode(details.data, canvasPos.dx - 115, canvasPos.dy - 50);
            },
            builder: (context, candidateData, rejectedData) {
              final isDropTarget = candidateData.isNotEmpty;
              final t = context.appTheme;
              return Container(
                decoration: BoxDecoration(
                  color: t.bg,
                  border: isDropTarget
                      ? Border.all(color: AppAccent.blue.withOpacity(0.5), width: 2)
                      : null,
                ),
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      final delta = event.scrollDelta.dy;
                      final factor = delta > 0 ? 0.9 : 1.1;
                      final newScale = (provider.scale * factor).clamp(0.1, 3.0);
                      final box = context.findRenderObject() as RenderBox;
                      final localPos = box.globalToLocal(event.position);
                      final newOffset = Offset(
                        localPos.dx - (localPos.dx - provider.offset.dx) * (newScale / provider.scale),
                        localPos.dy - (localPos.dy - provider.offset.dy) * (newScale / provider.scale),
                      );
                      provider.setScale(newScale);
                      provider.setOffset(newOffset);
                    }
                  },
                  child: GestureDetector(
                    onTapDown: (details) {
                      _focusNode.requestFocus();
                      if (_draggingFromPort != null) {
                        // Cancel connection
                setState(() {
                  _draggingFromPort = null;
                  _portDragCurrent = null;
                });
                provider.cancelConnecting();
                      } else {
                        provider.selectNode(null);
                      }
                    },
                    onPanStart: (details) {
                      if (_spaceDown) {
                        setState(() {
                          _panning = true;
                          _panStart = details.globalPosition;
                          _panStartOffset = provider.offset;
                        });
                      }
                    },
                    onPanUpdate: (details) {
                      if (_panning) {
                        final delta = details.globalPosition - _panStart;
                        provider.setOffset(_panStartOffset + delta);
                      } else if (_draggingFromPort != null) {
                        final box = context.findRenderObject() as RenderBox;
                        final localPos = box.globalToLocal(details.globalPosition);
                        setState(() => _portDragCurrent = localPos);
                      }
                    },
                    onPanEnd: (_) {
                      setState(() => _panning = false);
                    },
                    child: MouseRegion(
                      cursor: _spaceDown
                          ? (_panning ? SystemMouseCursors.grabbing : SystemMouseCursors.grab)
                          : SystemMouseCursors.basic,
                      child: Stack(
                        children: [
                          // Grid background
                          Positioned.fill(
                            child: CustomPaint(
                              painter: GridPainter(
                                scale: provider.scale,
                                offset: provider.offset,
                                gridColor: t.gridLine,
                              ),
                            ),
                          ),
                          // Connection lines
                          Positioned.fill(
                            child: CustomPaint(
                              painter: ConnectionPainter(
                                nodes: provider.nodes,
                                connections: provider.connections,
                                scale: provider.scale,
                                offset: provider.offset,
                                draggingFromNodeId: _draggingFromPort,
                                draggingEnd: _portDragCurrent,
                              ),
                            ),
                          ),
                          // Nodes
                          ...provider.nodes.map((node) => _buildNode(context, node, provider)),
                          // Empty state
                          if (provider.nodes.isEmpty)
                            const Center(
                              child: _EmptyState(),
                            ),
                          // Fit view button
                          Positioned(
                            bottom: 12,
                            left: 12,
                            child: _CanvasButton(
                              label: '⊡ 适应全图',
                              onTap: () {
                                final size = (context.findRenderObject() as RenderBox).size;
                                provider.fitView(size);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── 进入虚拟机处理逻辑 ──────────────────────────────────────────────────────
  Future<void> _handleEnterVm(
    BuildContext context,
    WorkflowNode node,
    WorkflowProvider provider,
  ) async {
    // 1. 未选择 VM → 打开 VM 选择面板
    if (node.vmId == null) {
      widget.onOpenVMPanel(node.id);
      return;
    }

    final vmId = node.vmId!;

    // 2. 先尝试从真实后端 VM 列表中查找
    final vmManager = context.read<VmManagerProvider>();
    VmInfo? realVm;
    if (vmManager.available) {
      try {
        realVm = vmManager.vms.where((v) => v.id == vmId).firstOrNull;
      } catch (_) {}
    }

    // 3. 如果找到真实 VM，调用 openConsole
    if (realVm != null) {
      _showConsoleLoading(context);
      final result = await vmManager.openConsole(
        realVm.id,
        vmName: realVm.name,
      );
      if (context.mounted) {
        Navigator.of(context).pop(); // 关闭 loading
        _showConsoleResult(context, result);
      }
      return;
    }

    // 4. 从预设列表查找（静态 VM）
    final staticVm = kVirtualMachines.where((v) => v.id == vmId).firstOrNull;
    if (staticVm != null) {
      // 预设 VM 没有真实后端，显示提示对话框
      if (context.mounted) {
        _showStaticVmDialog(context, staticVm.name, staticVm.ip);
      }
      return;
    }

    // 5. VM ID 无法解析
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('无法找到对应的虚拟机，请重新选择'),
          backgroundColor: AppAccent.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showConsoleLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ConsoleLoadingDialog(),
    );
  }

  void _showConsoleResult(BuildContext context, ConsoleResult result) {
    final t = context.appTheme;
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text('🖥  ', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Text(
                  result.message,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          backgroundColor: AppAccent.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: t.panel,
          title: Row(
            children: [
              const Text('⚠️  ', style: TextStyle(fontSize: 16)),
              Text('无法打开控制台',
                  style: TextStyle(
                      color: t.text, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.message,
                  style: TextStyle(color: t.text2, fontSize: 11)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: t.bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: t.border),
                ),
                child: Text(
                  _getInstallHint(result.method),
                  style: TextStyle(
                      color: AppAccent.cyan, fontSize: 10, fontFamily: 'Consolas'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  void _showStaticVmDialog(BuildContext context, String vmName, String vmIp) {
    final t = context.appTheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.panel,
        title: Row(
          children: [
            const Text('🖥  ', style: TextStyle(fontSize: 16)),
            Text('预设虚拟机',
                style: TextStyle(
                    color: t.text, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前节点绑定的是预设虚拟机，无法直接连接控制台。',
                style: TextStyle(color: t.text2, fontSize: 11)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: t.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: t.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('名称: $vmName',
                      style: TextStyle(
                          color: t.text2, fontSize: 10, fontFamily: 'Consolas')),
                  Text('IP: $vmIp',
                      style: TextStyle(
                          color: AppAccent.cyan,
                          fontSize: 10,
                          fontFamily: 'Consolas')),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text('请在 VM 面板切换到「真实虚拟机」Tab 并选择对应的 VM，即可使用控制台功能。',
                style: TextStyle(color: t.text3, fontSize: 10)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  String _getInstallHint(ConsoleMethod method) {
    switch (method) {
      case ConsoleMethod.notAvailable:
        if (Platform.isLinux) {
          return 'sudo apt install virt-viewer\n# 或\nsudo apt install remote-viewer';
        } else {
          return '请确认 VMware Workstation 已安装\n并运行 vmrest.exe 启动 REST API';
        }
      default:
        return '请检查虚拟机管理服务是否正常运行';
    }
  }

  Widget _buildNode(BuildContext context, WorkflowNode node, WorkflowProvider provider) {
    final screenX = node.x * provider.scale + provider.offset.dx;
    final screenY = node.y * provider.scale + provider.offset.dy;

    return Positioned(
      left: screenX,
      top: screenY,
      child: Transform.scale(
        scale: provider.scale,
        alignment: Alignment.topLeft,
        child: NodeCard(
          node: node,
          isSelected: provider.selectedNodeId == node.id,
          isConnecting: provider.isConnecting,
          onTap: () {
            provider.selectNode(node.id);
            widget.onSwitchTab(0);
          },
          onMove: (delta) {
            provider.updateNodePosition(
              node.id,
              node.x + delta.dx / provider.scale,
              node.y + delta.dy / provider.scale,
            );
          },
          onDelete: () => provider.deleteNode(node.id),
          onDuplicate: () => provider.duplicateNode(node.id),
          onOpenVMPanel: () => widget.onOpenVMPanel(node.id),
          onPortDragStart: (nodeId) {
            setState(() {
              _draggingFromPort = nodeId;
            });
            provider.startConnecting(nodeId);
          },
          onPortDrop: (targetNodeId) {
            if (_draggingFromPort != null) {
              provider.addConnection(_draggingFromPort!, targetNodeId);
              setState(() {
                _draggingFromPort = null;
                _portDragCurrent = null;
              });
            }
          },
          onEnterVM: () => _handleEnterVm(context, node, provider),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final double scale;
  final Offset offset;
  final Color gridColor;

  GridPainter({required this.scale, required this.offset, required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    final gridSize = 30.0 * scale;
    if (gridSize < 5) return;

    final startX = offset.dx % gridSize;
    final startY = offset.dy % gridSize;

    for (double x = startX; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = startY; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) =>
      oldDelegate.scale != scale || oldDelegate.offset != offset || oldDelegate.gridColor != gridColor;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Builder(builder: (ctx) {
          final t = ctx.appTheme;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎯', style: TextStyle(fontSize: 48, color: t.text3.withOpacity(0.5))),
              const SizedBox(height: 12),
              Text('从左侧工具箱拖拽工具到此处', style: TextStyle(color: t.text3, fontSize: 13)),
              const SizedBox(height: 4),
              Text('或点击顶部「加载」导入已有工作流', style: TextStyle(color: t.text3, fontSize: 11)),
            ],
          );
        }),
      ],
    );
  }
}

class _CanvasButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _CanvasButton({required this.label, required this.onTap});

  @override
  State<_CanvasButton> createState() => _CanvasButtonState();
}

class _CanvasButtonState extends State<_CanvasButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Builder(builder: (ctx) {
        final t = ctx.appTheme;
        return GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _hovered ? t.card : t.panel.withOpacity(0.8),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _hovered ? AppAccent.blue : t.border),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: _hovered ? AppAccent.blue : t.text2,
                fontSize: 11,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── 控制台连接加载对话框 ─────────────────────────────────────────────────────

class _ConsoleLoadingDialog extends StatelessWidget {
  const _ConsoleLoadingDialog();

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Dialog(
      backgroundColor: t.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: t.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppAccent.blue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '正在连接虚拟机控制台...',
              style: TextStyle(
                color: t.text,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '正在启动图形化控制台，请稍候',
              style: TextStyle(color: t.text3, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
