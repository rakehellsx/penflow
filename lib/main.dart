import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/workflow_provider.dart';
import 'screens/main_screen.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(const PenFlowApp());
}

class PenFlowApp extends StatelessWidget {
  const PenFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WorkflowProvider(),
      child: MaterialApp(
        title: 'PenFlow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainScreen(),
      ),
    );
  }
}
