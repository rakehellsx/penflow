import 'package:flutter/material.dart';
import '../models/tool_model.dart';
import '../utils/app_theme.dart';

class ConnectionPainter extends CustomPainter {
  final List<WorkflowNode> nodes;
  final List<WorkflowConnection> connections;
  final double scale;
  final Offset offset;
  final String? draggingFromNodeId;
  final Offset? draggingEnd;

  static const nodeWidth = 230.0;
  static const nodeHeight = 140.0;

  ConnectionPainter({
    required this.nodes,
    required this.connections,
    required this.scale,
    required this.offset,
    this.draggingFromNodeId,
    this.draggingEnd,
  });

  Offset _nodeOutPort(WorkflowNode node) {
    return Offset(
      node.x * scale + offset.dx + nodeWidth * scale,
      node.y * scale + offset.dy + (nodeHeight / 2) * scale,
    );
  }

  Offset _nodeInPort(WorkflowNode node) {
    return Offset(
      node.x * scale + offset.dx,
      node.y * scale + offset.dy + (nodeHeight / 2) * scale,
    );
  }

  Path _bezierPath(Offset start, Offset end) {
    final dx = (end.dx - start.dx).abs() * 0.55;
    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx + dx, start.dy,
        end.dx - dx, end.dy,
        end.dx, end.dy,
      );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.blue.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = AppColors.blue
      ..style = PaintingStyle.fill;

    // Draw existing connections
    for (final conn in connections) {
      final fromNode = nodes.where((n) => n.id == conn.fromNodeId).firstOrNull;
      final toNode = nodes.where((n) => n.id == conn.toNodeId).firstOrNull;
      if (fromNode == null || toNode == null) continue;

      final start = _nodeOutPort(fromNode);
      final end = _nodeInPort(toNode);
      final path = _bezierPath(start, end);

      canvas.drawPath(path, linePaint);
      canvas.drawCircle(end, 3 * scale.clamp(0.5, 2.0), dotPaint);
    }

    // Draw dragging connection
    if (draggingFromNodeId != null && draggingEnd != null) {
      final fromNode = nodes.where((n) => n.id == draggingFromNodeId).firstOrNull;
      if (fromNode != null) {
        final start = _nodeOutPort(fromNode);
        final dashPaint = Paint()
          ..color = AppColors.blue
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

        final path = _bezierPath(start, draggingEnd!);

        // Draw dashed line
        _drawDashedPath(canvas, path, dashPaint);
      }
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLength = 8.0;
    const gapLength = 4.0;
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(ConnectionPainter oldDelegate) => true;
}
