import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workflow_provider.dart';
import '../utils/app_theme.dart';

class TopBar extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onLoad;
  final VoidCallback onExport;
  final VoidCallback onAutoLayout;
  final VoidCallback onFitView;
  final VoidCallback onClear;
  final VoidCallback onLoadChain;

  const TopBar({
    super.key,
    required this.onSave,
    required this.onLoad,
    required this.onExport,
    required this.onAutoLayout,
    required this.onFitView,
    required this.onClear,
    required this.onLoadChain,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkflowProvider>(
      builder: (context, provider, _) {
        return Container(
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.panel,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // Logo
              const Row(
                children: [
                  Text('⚡', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text(
                    'PenFlow',
                    style: TextStyle(
                      color: AppColors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const _Divider(),
              // Action buttons
              _TbButton(label: '💾 保存', color: AppColors.green, onTap: onSave),
              const SizedBox(width: 4),
              _TbButton(label: '📂 加载', onTap: onLoad),
              const SizedBox(width: 4),
              _TbButton(label: '📤 导出', color: AppColors.orange, onTap: onExport),
              const _Divider(),
              _TbButton(label: '⚡ 自动布局', onTap: onAutoLayout),
              const SizedBox(width: 4),
              _TbButton(label: '🔭 适应视图', onTap: onFitView),
              const SizedBox(width: 4),
              _TbButton(label: '🗑 清空', hoverRed: true, onTap: onClear),
              const _Divider(),
              _TbButton(
                label: '🔗 加载攻击链',
                color: AppColors.purple,
                onTap: onLoadChain,
              ),
              const Spacer(),
              // Status
              const _StatusDot(),
              const SizedBox(width: 8),
              Text(
                '节点:${provider.nodes.length}',
                style: const TextStyle(color: AppColors.text3, fontSize: 11),
              ),
              const SizedBox(width: 12),
              Text(
                '连线:${provider.connections.length}',
                style: const TextStyle(color: AppColors.text3, fontSize: 11),
              ),
              const SizedBox(width: 12),
              Text(
                '缩放:${(provider.scale * 100).round()}%',
                style: const TextStyle(color: AppColors.yellow, fontSize: 11),
              ),
              const SizedBox(width: 12),
              const Text(
                '滚轮缩放 · 空格拖动',
                style: TextStyle(color: AppColors.text3, fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.border,
    );
  }
}

class _TbButton extends StatefulWidget {
  final String label;
  final Color? color;
  final bool hoverRed;
  final VoidCallback onTap;

  const _TbButton({
    required this.label,
    required this.onTap,
    this.color,
    this.hoverRed = false,
  });

  @override
  State<_TbButton> createState() => _TbButtonState();
}

class _TbButtonState extends State<_TbButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Color textColor = widget.color ?? AppColors.text2;
    if (_hovered) {
      textColor = widget.hoverRed ? AppColors.red : (widget.color ?? AppColors.blue);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _hovered
                  ? (widget.hoverRed ? AppColors.red : (widget.color ?? AppColors.blue))
                  : AppColors.border,
            ),
            color: _hovered && widget.color != null
                ? widget.color!.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontFamily: 'Consolas',
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatefulWidget {
  const _StatusDot();

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 0.3).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Opacity(
        opacity: _animation.value,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.green,
            boxShadow: [BoxShadow(color: AppColors.green.withOpacity(0.6), blurRadius: 5)],
          ),
        ),
      ),
    );
  }
}
