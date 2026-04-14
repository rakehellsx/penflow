import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/workflow_provider.dart';
import 'providers/vm_manager_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'utils/app_theme.dart';

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
  final _themeProvider = ThemeProvider();
  final _authProvider  = AuthProvider();

  @override
  void initState() {
    super.initState();
    _authProvider.initialize();
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
        ChangeNotifierProvider(create: (_) => WorkflowProvider()),
        ChangeNotifierProvider(create: (_) => VmManagerProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
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
            return _LoadingScreen();
          case AuthState.unauthenticated:
            return const LoginScreen();
          case AuthState.authenticated:
            return const MainScreen();
        }
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Scaffold(
      backgroundColor: t.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚡', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              'PenFlow',
              style: TextStyle(
                color: AppAccent.blue,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                backgroundColor: AppAccent.blue.withOpacity(0.2),
                color: AppAccent.blue,
                minHeight: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
