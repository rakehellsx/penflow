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
    final t = context.appTheme;
    return Consumer<WorkflowProvider>(
      builder: (context, provider, _) {
        return Container(
          height: 44,
          decoration: BoxDecoration(
            color: t.panel,
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // Logo
              Row(
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    'PenFlow',
                    style: TextStyle(
                      color: t.isDark ? AppAccent.blue : const Color(0xFF0969DA),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              _Divider(color: t.border),
              // Action buttons
              _TbButton(label: '💾 保存',  color: AppAccent.green,  onTap: onSave),
              const SizedBox(width: 4),
              _TbButton(label: '📂 加载',  onTap: onLoad),
              const SizedBox(width: 4),
              _TbButton(label: '📤 导出',  color: AppAccent.orange, onTap: onExport),
              _Divider(color: t.border),
              _TbButton(label: '⚡ 自动布局', onTap: onAutoLayout),
              const SizedBox(width: 4),
              _TbButton(label: '🔭 适应视图', onTap: onFitView),
              const SizedBox(width: 4),
              _TbButton(label: '🗑 清空',  hoverRed: true, onTap: onClear),
              _Divider(color: t.border),
              _TbButton(
                label: '🔗 加载攻击链',
                color: AppAccent.purple,
                onTap: onLoadChain,
              ),
              const Spacer(),
              // ── 主题切换按钮 ──
              _ThemeToggleButton(),
              _Divider(color: t.border),
              // Status
              _StatusDot(),
              const SizedBox(width: 8),
              Text(
                '节点:${provider.nodes.length}',
                style: TextStyle(color: t.text3, fontSize: 11),
              ),
              const SizedBox(width: 12),
              Text(
                '连线:${provider.connections.length}',
                style: TextStyle(color: t.text3, fontSize: 11),
              ),
              const SizedBox(width: 12),
              Text(
                '缩放:${(provider.scale * 100).round()}%',
                style: TextStyle(color: AppAccent.yellow, fontSize: 11),
              ),
              const SizedBox(width: 12),
              Text(
                '滚轮缩放 · 空格拖动',
                style: TextStyle(color: t.text3, fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── 主题切换按钮 ──────────────────────────────
class _ThemeToggleButton extends StatefulWidget {
  @override
  State<_ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<_ThemeToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rotate;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _rotate = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle(ThemeProvider tp) {
    tp.toggle();
    if (_ctrl.isCompleted) {
      _ctrl.reverse();
    } else {
      _ctrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t  = context.appTheme;
    final tp = context.watch<ThemeProvider>();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _toggle(tp),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _hovered ? AppAccent.blue : t.border,
            ),
            color: _hovered ? AppAccent.blue.withOpacity(0.1) : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _rotate,
                child: Text(
                  tp.isDark ? '☀️' : '🌙',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 5),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  tp.isDark ? '亮色' : '暗色',
                  key: ValueKey(tp.isDark),
                  style: TextStyle(
                    color: _hovered ? AppAccent.blue : t.text2,
                    fontSize: 11,
                    fontFamily: 'Consolas',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 分隔线 ────────────────────────────────────
class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: color,
    );
  }
}

// ── 工具栏按钮 ────────────────────────────────
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
    final t = context.appTheme;
    Color textColor = widget.color ?? t.text2;
    if (_hovered) {
      textColor = widget.hoverRed ? AppAccent.red : (widget.color ?? AppAccent.blue);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _hovered
                  ? (widget.hoverRed ? AppAccent.red : (widget.color ?? AppAccent.blue))
                  : t.border,
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

// ── 状态指示灯 ────────────────────────────────
class _StatusDot extends StatefulWidget {
  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
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
            color: AppAccent.green,
            boxShadow: [
              BoxShadow(
                color: AppAccent.green.withOpacity(0.6),
                blurRadius: 5,
              )
            ],
          ),
        ),
      ),
    );
  }
}
