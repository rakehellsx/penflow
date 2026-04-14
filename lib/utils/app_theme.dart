import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// 固定语义色（两套主题共用的强调色）
// ─────────────────────────────────────────────
class AppAccent {
  static const blue   = Color(0xFF58A6FF);
  static const green  = Color(0xFF3FB950);
  static const orange = Color(0xFFD29922);
  static const red    = Color(0xFFF85149);
  static const purple = Color(0xFFBC8CFF);
  static const yellow = Color(0xFFE3B341);
  static const cyan   = Color(0xFF39D353);

  // Category colors
  static const catProxy   = Color(0xFF58A6FF);
  static const catRecon   = Color(0xFF3FB950);
  static const catExploit = Color(0xFFF85149);
  static const catCred    = Color(0xFFD29922);
  static const catLateral = Color(0xFFBC8CFF);
  static const catNtlm    = Color(0xFFE3B341);
  static const catDomain  = Color(0xFF39D353);
  static const catDC      = Color(0xFFFF7B72);
  static const catUtil    = Color(0xFF8B949E);

  // Risk colors
  static const riskCritical = Color(0xFFF85149);
  static const riskHigh     = Color(0xFFD29922);
  static const riskMedium   = Color(0xFFE3B341);
  static const riskLow      = Color(0xFF3FB950);
  static const riskNone     = Color(0xFF8B949E);
}

// ─────────────────────────────────────────────
// 主题数据（随主题切换的表面色）
// ─────────────────────────────────────────────
class AppThemeData {
  final bool isDark;

  // Background layers
  final Color bg;
  final Color panel;
  final Color card;
  final Color node;

  // Borders
  final Color border;
  final Color borderHi;

  // Text
  final Color text;
  final Color text2;
  final Color text3;

  // Grid
  final Color gridLine;

  const AppThemeData._({
    required this.isDark,
    required this.bg,
    required this.panel,
    required this.card,
    required this.node,
    required this.border,
    required this.borderHi,
    required this.text,
    required this.text2,
    required this.text3,
    required this.gridLine,
  });

  // ── 暗色主题 ──
  static const dark = AppThemeData._(
    isDark: true,
    bg:       Color(0xFF0D1117),
    panel:    Color(0xFF161B22),
    card:     Color(0xFF1C2333),
    node:     Color(0xFF1E2A3A),
    border:   Color(0xFF30363D),
    borderHi: Color(0xFF58A6FF),
    text:     Color(0xFFE6EDF3),
    text2:    Color(0xFF8B949E),
    text3:    Color(0xFF484F58),
    gridLine: Color(0xFF1C2333),
  );

  // ── 亮色主题 ──
  static const light = AppThemeData._(
    isDark: false,
    bg:       Color(0xFFF0F2F5),
    panel:    Color(0xFFFFFFFF),
    card:     Color(0xFFF6F8FA),
    node:     Color(0xFFEBF0F7),
    border:   Color(0xFFD0D7DE),
    borderHi: Color(0xFF0969DA),
    text:     Color(0xFF1F2328),
    text2:    Color(0xFF57606A),
    text3:    Color(0xFF8C959F),
    gridLine: Color(0xFFE8ECF0),
  );
}

// ─────────────────────────────────────────────
// ThemeProvider — 管理主题切换 & 持久化
// ─────────────────────────────────────────────
class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;

  bool get isDark => _isDark;
  AppThemeData get theme => _isDark ? AppThemeData.dark : AppThemeData.light;

  void toggle() {
    _isDark = !_isDark;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────
// BuildContext 扩展 — 方便访问
// ─────────────────────────────────────────────
extension AppThemeContext on BuildContext {
  AppThemeData get appTheme {
    // 通过 InheritedWidget 注入的 ThemeProvider
    return _AppThemeScope.of(this);
  }
}

// ─────────────────────────────────────────────
// InheritedWidget 作用域
// ─────────────────────────────────────────────
class AppThemeScope extends StatelessWidget {
  final ThemeProvider provider;
  final Widget child;

  const AppThemeScope({
    super.key,
    required this.provider,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: provider,
      builder: (_, __) => _AppThemeScope(
        themeData: provider.theme,
        child: child,
      ),
    );
  }
}

class _AppThemeScope extends InheritedWidget {
  final AppThemeData themeData;

  const _AppThemeScope({
    required this.themeData,
    required super.child,
  });

  static AppThemeData of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_AppThemeScope>();
    assert(scope != null, '_AppThemeScope not found in widget tree');
    return scope!.themeData;
  }

  @override
  bool updateShouldNotify(_AppThemeScope old) => themeData != old.themeData;
}

// ─────────────────────────────────────────────
// MaterialTheme 工厂（传给 MaterialApp）
// ─────────────────────────────────────────────
class AppMaterialTheme {
  static ThemeData build(AppThemeData t) {
    return ThemeData(
      brightness: t.isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: t.bg,
      colorScheme: ColorScheme(
        brightness: t.isDark ? Brightness.dark : Brightness.light,
        primary:    AppAccent.blue,
        onPrimary:  Colors.white,
        secondary:  AppAccent.green,
        onSecondary: Colors.white,
        surface:    t.panel,
        onSurface:  t.text,
        error:      AppAccent.red,
        onError:    Colors.white,
      ),
      fontFamily: 'Consolas',
      textTheme: TextTheme(
        bodyLarge:  TextStyle(color: t.text,  fontSize: 13),
        bodyMedium: TextStyle(color: t.text2, fontSize: 11),
        bodySmall:  TextStyle(color: t.text3, fontSize: 10),
        labelLarge: TextStyle(color: t.text,  fontSize: 11, fontWeight: FontWeight.w600),
      ),
      dividerColor: t.border,
      cardColor: t.card,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.bg,
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
          borderSide: const BorderSide(color: AppAccent.blue),
        ),
        hintStyle: TextStyle(color: t.text3, fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(t.border),
        thickness:  WidgetStateProperty.all(3),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 向后兼容：保留 AppColors 作为静态别名
// ─────────────────────────────────────────────
class AppColors {
  // 固定语义色（直接转发到 AppAccent）
  static const blue   = AppAccent.blue;
  static const green  = AppAccent.green;
  static const orange = AppAccent.orange;
  static const red    = AppAccent.red;
  static const purple = AppAccent.purple;
  static const yellow = AppAccent.yellow;
  static const cyan   = AppAccent.cyan;

  static const catProxy   = AppAccent.catProxy;
  static const catRecon   = AppAccent.catRecon;
  static const catExploit = AppAccent.catExploit;
  static const catCred    = AppAccent.catCred;
  static const catLateral = AppAccent.catLateral;
  static const catNtlm    = AppAccent.catNtlm;
  static const catDomain  = AppAccent.catDomain;
  static const catDC      = AppAccent.catDC;
  static const catUtil    = AppAccent.catUtil;

  static const riskCritical = AppAccent.riskCritical;
  static const riskHigh     = AppAccent.riskHigh;
  static const riskMedium   = AppAccent.riskMedium;
  static const riskLow      = AppAccent.riskLow;
  static const riskNone     = AppAccent.riskNone;

  // 暗色主题默认值（兼容旧代码，新代码请用 context.appTheme）
  static const bg      = Color(0xFF0D1117);
  static const panel   = Color(0xFF161B22);
  static const card    = Color(0xFF1C2333);
  static const node    = Color(0xFF1E2A3A);
  static const border  = Color(0xFF30363D);
  static const borderHi = Color(0xFF58A6FF);
  static const text    = Color(0xFFE6EDF3);
  static const text2   = Color(0xFF8B949E);
  static const text3   = Color(0xFF484F58);
}
