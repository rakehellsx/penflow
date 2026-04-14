import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/workflow_provider.dart';
import '../models/tool_model.dart';
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
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  border: isDropTarget
                      ? Border.all(color: AppColors.blue.withOpacity(0.5), width: 2)
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
          onEnterVM: () {
            widget.onOpenVMPanel(node.id);
          },
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final double scale;
  final Offset offset;

  GridPainter({required this.scale, required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withOpacity(0.3)
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
      oldDelegate.scale != scale || oldDelegate.offset != offset;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '🎯',
          style: TextStyle(
            fontSize: 48,
            color: AppColors.text3.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '从左侧工具箱拖拽工具到此处',
          style: TextStyle(color: AppColors.text3, fontSize: 13),
        ),
        const SizedBox(height: 4),
        const Text(
          '或点击「加载攻击链」快速开始',
          style: TextStyle(color: AppColors.text3, fontSize: 11),
        ),
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
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.card : AppColors.panel.withOpacity(0.8),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _hovered ? AppColors.blue : AppColors.border),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? AppColors.blue : AppColors.text2,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
