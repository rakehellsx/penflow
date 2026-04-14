import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey  = GlobalKey<FormState>();
  bool _obscure   = true;
  bool _loading   = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    await auth.login(_userCtrl.text, _passCtrl.text);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Scaffold(
      backgroundColor: t.bg,
      body: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (e) {
          if (e is KeyDownEvent &&
              e.logicalKey == LogicalKeyboardKey.enter) {
            _submit();
          }
        },
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: t.panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Logo ──────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('⚡',
                            style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 10),
                        Text(
                          'PenFlow',
                          style: TextStyle(
                            color: t.isDark
                                ? AppAccent.blue
                                : const Color(0xFF0969DA),
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '渗透测试工作流管理系统',
                      style: TextStyle(
                          color: t.text3, fontSize: 11),
                    ),
                    const SizedBox(height: 32),

                    // ── 用户名 ─────────────────────────────
                    _buildField(
                      controller: _userCtrl,
                      label: '用户名',
                      hint: '请输入用户名',
                      icon: Icons.person_outline,
                      t: t,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? '请输入用户名'
                              : null,
                    ),
                    const SizedBox(height: 14),

                    // ── 密码 ───────────────────────────────
                    _buildField(
                      controller: _passCtrl,
                      label: '密码',
                      hint: '请输入密码',
                      icon: Icons.lock_outline,
                      t: t,
                      obscure: _obscure,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: t.text3,
                          size: 18,
                        ),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty)
                              ? '请输入密码'
                              : null,
                    ),
                    const SizedBox(height: 8),

                    // ── 错误提示 ───────────────────────────
                    Consumer<AuthProvider>(
                      builder: (_, auth, __) {
                        if (auth.error == null) {
                          return const SizedBox(height: 20);
                        }
                        return Container(
                          height: 20,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            auth.error!,
                            style: TextStyle(
                              color: AppAccent.red,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // ── 登录按钮 ───────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppAccent.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('登 录',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 版本信息 ───────────────────────────
                    Text(
                      'PenFlow v1.0  ·  默认账号 admin / admin',
                      style: TextStyle(
                          color: t.text3, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required AppThemeData t,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: t.text2,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(color: t.text, fontSize: 13),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: t.text3, fontSize: 12),
            prefixIcon: Icon(icon, color: t.text3, size: 18),
            suffixIcon: suffixIcon,
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
                horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
