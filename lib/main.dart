import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/workflow_provider.dart';
import 'screens/main_screen.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(const PenFlowApp());
}

class PenFlowApp extends StatefulWidget {
  const PenFlowApp({super.key});

  @override
  State<PenFlowApp> createState() => _PenFlowAppState();
}

class _PenFlowAppState extends State<PenFlowApp> {
  final _themeProvider = ThemeProvider();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _themeProvider),
        ChangeNotifierProvider(create: (_) => WorkflowProvider()),
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
                home: const MainScreen(),
              ),
            );
          },
        ),
      ),
    );
  }
}
