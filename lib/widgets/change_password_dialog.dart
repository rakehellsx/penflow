import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _oldCtrl     = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  bool _obscureOld     = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  String? _localError;
  bool _success = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _localError = null);

    final auth = context.read<AuthProvider>();
    final ok = auth.changePassword(
      _oldCtrl.text,
      _newCtrl.text,
      _confirmCtrl.text,
    );

    if (ok) {
      setState(() => _success = true);
    } else {
      setState(() => _localError = auth.error ?? '修改失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;

    return AlertDialog(
      backgroundColor: t.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Row(
        children: [
          Icon(Icons.lock_reset, color: AppAccent.blue, size: 18),
          const SizedBox(width: 8),
          Text('修改密码',
              style: TextStyle(color: t.text, fontSize: 14)),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: _success ? _buildSuccess(t) : _buildForm(t),
      ),
      actions: _success
          ? [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppAccent.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('完成'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('取消',
                    style: TextStyle(color: t.text3)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppAccent.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _submit,
                child: const Text('确认修改'),
              ),
            ],
    );
  }

  Widget _buildSuccess(AppThemeData t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Icon(Icons.check_circle_outline,
            color: AppAccent.green, size: 48),
        const SizedBox(height: 12),
        Text('密码修改成功！',
            style: TextStyle(
                color: t.text, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('下次登录时请使用新密码',
            style: TextStyle(color: t.text3, fontSize: 11)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildForm(AppThemeData t) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PwdField(
            controller: _oldCtrl,
            label: '原密码',
            obscure: _obscureOld,
            onToggle: () => setState(() => _obscureOld = !_obscureOld),
            t: t,
            validator: (v) =>
                (v == null || v.isEmpty) ? '请输入原密码' : null,
          ),
          const SizedBox(height: 12),
          _PwdField(
            controller: _newCtrl,
            label: '新密码',
            obscure: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
            t: t,
            validator: (v) {
              if (v == null || v.isEmpty) return '请输入新密码';
              if (v.length < 4) return '密码长度不能少于 4 位';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _PwdField(
            controller: _confirmCtrl,
            label: '确认新密码',
            obscure: _obscureConfirm,
            onToggle: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
            t: t,
            validator: (v) {
              if (v == null || v.isEmpty) return '请再次输入新密码';
              if (v != _newCtrl.text) return '两次密码不一致';
              return null;
            },
          ),
          if (_localError != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppAccent.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppAccent.red.withOpacity(0.3)),
              ),
              child: Text(
                _localError!,
                style: TextStyle(color: AppAccent.red, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PwdField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final AppThemeData t;
  final String? Function(String?)? validator;

  const _PwdField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.t,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: t.text2,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(color: t.text, fontSize: 12),
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.lock_outline, color: t.text3, size: 16),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: t.text3,
                size: 16,
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: t.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: t.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: t.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AppAccent.blue),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AppAccent.red),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 8),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
