import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/vm_manager_provider.dart';
import '../services/vmrest_config.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VMware REST API 连接配置对话框
// 配置项：主机地址、端口、用户名、密码
// 保存后立即持久化并重新连接
// ─────────────────────────────────────────────────────────────────────────────

class VmrestConfigDialog extends StatefulWidget {
  const VmrestConfigDialog({super.key});

  @override
  State<VmrestConfigDialog> createState() => _VmrestConfigDialogState();
}

class _VmrestConfigDialogState extends State<VmrestConfigDialog> {
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _userCtrl;
  late TextEditingController _passCtrl;

  bool _obscurePass = true;
  bool _saving      = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    final cfg = context.read<VmManagerProvider>().config;
    _hostCtrl = TextEditingController(text: cfg.host);
    _portCtrl = TextEditingController(text: cfg.port.toString());
    _userCtrl = TextEditingController(text: cfg.username);
    _passCtrl = TextEditingController(text: cfg.password);
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  VmrestConfig _buildConfig() => VmrestConfig(
        host:     _hostCtrl.text.trim().isEmpty ? '127.0.0.1' : _hostCtrl.text.trim(),
        port:     int.tryParse(_portCtrl.text.trim()) ?? 8697,
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
      );

  Future<void> _testConnection() async {
    setState(() {
      _testResult = null;
      _saving     = true;
    });

    final cfg = _buildConfig();
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final uri = Uri.parse('${cfg.baseUrl}/vms');
      final req = await client.openUrl('GET', uri);

      // Basic Auth
      final credentials = '${cfg.username}:${cfg.password}';
      final encoded = _base64(credentials);
      req.headers.set('Authorization', 'Basic $encoded');
      req.headers.set('Accept', 'application/json');

      final resp = await req.close();
      await resp.drain<void>();

      setState(() {
        _saving    = false;
        _testOk    = resp.statusCode == 200;
        _testResult = _testOk
            ? '连接成功（HTTP ${resp.statusCode}）'
            : '连接失败（HTTP ${resp.statusCode}），请检查用户名和密码';
      });
    } catch (e) {
      setState(() {
        _saving     = false;
        _testOk     = false;
        _testResult = '无法连接到 ${cfg.baseUrl}：$e';
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final cfg = _buildConfig();
    await context.read<VmManagerProvider>().updateConfig(cfg);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    }
  }

  String _base64(String input) {
    final bytes = input.codeUnits;
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final result = StringBuffer();
    for (var i = 0; i < bytes.length; i += 3) {
      final b0 = bytes[i];
      final b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      result.write(chars[(b0 >> 2) & 0x3F]);
      result.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      result.write(i + 1 < bytes.length ? chars[((b1 << 2) | (b2 >> 6)) & 0x3F] : '=');
      result.write(i + 2 < bytes.length ? chars[b2 & 0x3F] : '=');
    }
    return result.toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Dialog(
      backgroundColor: t.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: t.border),
      ),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 标题 ──
              Row(
                children: [
                  Icon(Icons.settings_ethernet, color: AppAccent.blue, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'VMware REST API 连接配置',
                    style: TextStyle(
                      color: t.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close, color: t.text3, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'vmrest.exe 默认监听 127.0.0.1:8697，首次使用需在 VMware Workstation 中设置凭据',
                style: TextStyle(color: t.text3, fontSize: 10),
              ),
              const SizedBox(height: 16),

              // ── 地址 + 端口 ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _Field(
                      label: '主机地址',
                      hint: '127.0.0.1',
                      controller: _hostCtrl,
                      t: t,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: _Field(
                      label: '端口',
                      hint: '8697',
                      controller: _portCtrl,
                      t: t,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── 用户名 ──
              _Field(
                label: '用户名',
                hint: 'vmrest 用户名',
                controller: _userCtrl,
                t: t,
              ),
              const SizedBox(height: 10),

              // ── 密码 ──
              _PasswordField(
                label: '密码',
                hint: 'vmrest 密码',
                controller: _passCtrl,
                obscure: _obscurePass,
                onToggle: () => setState(() => _obscurePass = !_obscurePass),
                t: t,
              ),
              const SizedBox(height: 6),

              // ── 提示文字 ──
              Text(
                '凭据在 VMware Workstation → Edit → Preferences → Shared VMs 中设置',
                style: TextStyle(color: t.text3, fontSize: 9),
              ),

              // ── 测试结果 ──
              if (_testResult != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: (_testOk ? AppAccent.green : AppAccent.red).withOpacity(0.12),
                    border: Border.all(
                      color: (_testOk ? AppAccent.green : AppAccent.red).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testOk ? Icons.check_circle_outline : Icons.error_outline,
                        color: _testOk ? AppAccent.green : AppAccent.red,
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            color: _testOk ? AppAccent.green : AppAccent.red,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ── 按钮行 ──
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _Btn(
                    label: '测试连接',
                    onTap: _saving ? null : _testConnection,
                    t: t,
                    outlined: true,
                  ),
                  const SizedBox(width: 8),
                  _Btn(
                    label: '取消',
                    onTap: _saving ? null : () => Navigator.of(context).pop(),
                    t: t,
                    outlined: true,
                  ),
                  const SizedBox(width: 8),
                  _Btn(
                    label: _saving ? '保存中…' : '保存并重连',
                    onTap: _saving ? null : _save,
                    t: t,
                    primary: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 内部小组件
// ─────────────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final AppThemeData t;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.t,
    this.inputFormatters,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: t.text2, fontSize: 10)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          inputFormatters: inputFormatters,
          keyboardType: keyboardType,
          style: TextStyle(color: t.text, fontSize: 11),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: t.text3, fontSize: 11),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: t.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: t.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: t.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: AppAccent.blue),
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final AppThemeData t;

  const _PasswordField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.obscure,
    required this.onToggle,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: t.text2, fontSize: 10)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(color: t.text, fontSize: 11),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: t.text3, fontSize: 11),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: t.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: t.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: t.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: AppAccent.blue),
            ),
            suffixIcon: GestureDetector(
              onTap: onToggle,
              child: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: t.text3,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final AppThemeData t;
  final bool outlined;
  final bool primary;

  const _Btn({
    required this.label,
    required this.onTap,
    required this.t,
    this.outlined = false,
    this.primary  = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final bgColor = primary
        ? (disabled ? AppAccent.blue.withOpacity(0.4) : AppAccent.blue)
        : Colors.transparent;
    final fgColor = primary
        ? Colors.white
        : (disabled ? t.text3 : t.text2);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: bgColor,
          border: Border.all(
            color: primary
                ? Colors.transparent
                : (disabled ? t.border : t.borderHi),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(color: fgColor, fontSize: 11),
        ),
      ),
    );
  }
}


