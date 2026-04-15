import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VMware REST API 连接配置
// 存储 vmrest 的地址、用户名、密码，通过 SharedPreferences 持久化
// ─────────────────────────────────────────────────────────────────────────────

class VmrestConfig {
  static const String _keyHost     = 'vmrest_host';
  static const String _keyPort     = 'vmrest_port';
  static const String _keyUsername = 'vmrest_username';
  static const String _keyPassword = 'vmrest_password';

  static const String defaultHost     = '127.0.0.1';
  static const int    defaultPort     = 8697;
  static const String defaultUsername = '';
  static const String defaultPassword = '';

  final String host;
  final int    port;
  final String username;
  final String password;

  const VmrestConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  /// 默认配置
  factory VmrestConfig.defaults() => const VmrestConfig(
        host:     defaultHost,
        port:     defaultPort,
        username: defaultUsername,
        password: defaultPassword,
      );

  /// 从 SharedPreferences 加载
  static Future<VmrestConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return VmrestConfig(
      host:     prefs.getString(_keyHost)     ?? defaultHost,
      port:     prefs.getInt(_keyPort)        ?? defaultPort,
      username: prefs.getString(_keyUsername) ?? defaultUsername,
      password: prefs.getString(_keyPassword) ?? defaultPassword,
    );
  }

  /// 保存到 SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHost,     host);
    await prefs.setInt(   _keyPort,     port);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyPassword, password);
  }

  /// 完整 API base URL
  String get baseUrl => 'http://$host:$port/api';

  /// 是否已配置凭据
  bool get hasCredentials => username.isNotEmpty && password.isNotEmpty;

  VmrestConfig copyWith({
    String? host,
    int?    port,
    String? username,
    String? password,
  }) =>
      VmrestConfig(
        host:     host     ?? this.host,
        port:     port     ?? this.port,
        username: username ?? this.username,
        password: password ?? this.password,
      );
}
