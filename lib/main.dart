import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/workflow_provider.dart';
import 'providers/vm_manager_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'providers/tool_provider.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'utils/app_theme.dart';
import 'services/vmrest_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PenFlowApp());
}

class PenFlowApp extends StatefulWidget {
  const PenFlowApp({super.key});

  @override
  State<PenFlowApp> createState() => _PenFlowAppState();
}

class _PenFlowAppState extends State<PenFlowApp> {
  final _themeProvider  = ThemeProvider();
  final _authProvider   = AuthProvider();
  final _vmProvider     = VmManagerProvider();

  @override
  void initState() {
    super.initState();
    _authProvider.initialize();
    // Windows 下在后台异步初始化 vmrest（不阻断 UI）
    _vmProvider.initialize();
  }

  @override
  void dispose() {
    _themeProvider.dispose();
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _themeProvider),
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _vmProvider),
        ChangeNotifierProvider(create: (_) => WorkflowProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => ToolProvider()),
      ],
      child: AppThemeScope(
        provider: _themeProvider,
        child: Builder(
          builder: (ctx) {
            final t = ctx.appTheme;
            return AnimatedBuilder(
              animation: _themeProvider,
              builder: (_, __) => MaterialApp(
                title: 'PenFlow',
                debugShowCheckedModeBanner: false,
                theme: AppMaterialTheme.build(t),
                home: const _AppRoot(),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 根据认证状态决定显示登录页还是主界面
class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.state) {
          case AuthState.loading:
            return const _LoadingScreen();
          case AuthState.unauthenticated:
            return const LoginScreen();
          case AuthState.authenticated:
            return const MainScreen();
        }
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 启动加载屏幕（显示 vmrest 启动进度）
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;

    return Scaffold(
      backgroundColor: t.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            Text(
              '⚡',
              style: TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              'PenFlow',
              style: TextStyle(
                color: AppAccent.blue,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Penetration Testing Workflow',
              style: TextStyle(
                color: t.text3,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 32),

            // 进度条
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: AppAccent.blue.withOpacity(0.15),
                color: AppAccent.blue,
                minHeight: 2,
              ),
            ),
            const SizedBox(height: 16),

            // Windows 下显示 vmrest 启动状态
            if (Platform.isWindows)
              Consumer<VmManagerProvider>(
                builder: (_, vm, __) {
                  if (vm.vmrestStatus == VmrestStatus.notApplicable ||
                      vm.vmrestStatus == VmrestStatus.running ||
                      vm.vmrestStatus == VmrestStatus.started) {
                    return const SizedBox.shrink();
                  }
                  return _VmrestStatusWidget(
                    status: vm.vmrestStatus,
                    message: vm.vmrestMessage,
                    textColor: t.text3,
                  );
                },
              )
            else
              Text(
                '正在初始化...',
                style: TextStyle(color: t.text3, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// vmrest 启动状态显示组件
// ─────────────────────────────────────────────────────────────────────────────

class _VmrestStatusWidget extends StatelessWidget {
  final VmrestStatus status;
  final String message;
  final Color textColor;

  const _VmrestStatusWidget({
    required this.status,
    required this.message,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final pair = _iconAndColor(status);
    final icon = pair.$1;
    final color = pair.$2;

    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 动画图标（检测/启动中）或静态图标
          if (status == VmrestStatus.checking ||
              status == VmrestStatus.starting)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: color,
              ),
            )
          else
            Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _shortMessage(status, message),
              style: TextStyle(
                color: color,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _iconAndColor(VmrestStatus s) {
    switch (s) {
      case VmrestStatus.checking:
        return ('🔍', Colors.blue);
      case VmrestStatus.running:
        return ('✅', Colors.green);
      case VmrestStatus.starting:
        return ('🚀', Colors.orange);
      case VmrestStatus.started:
        return ('✅', Colors.green);
      case VmrestStatus.notFound:
        return ('⚠️', Colors.orange);
      case VmrestStatus.failed:
        return ('❌', Colors.red);
      case VmrestStatus.notApplicable:
        return ('', Colors.grey);
    }
  }

  String _shortMessage(VmrestStatus s, String full) {
    switch (s) {
      case VmrestStatus.checking:
        return '正在检测 vmrest.exe...';
      case VmrestStatus.starting:
        return '正在启动 vmrest.exe...';
      case VmrestStatus.notFound:
        return '未找到 vmrest.exe，VMware 管理接口不可用';
      case VmrestStatus.failed:
        return 'vmrest.exe 启动失败，请以管理员身份运行';
      default:
        return full.split('\n').first;
    }
  }
}
