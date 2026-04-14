import 'package:flutter/material.dart';
import '../services/auth_service.dart';

enum AuthState { loading, unauthenticated, authenticated }

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.loading;
  String?   _username;
  String?   _role;
  String?   _error;

  AuthState get state    => _state;
  String?   get username => _username;
  String?   get role     => _role;
  String?   get error    => _error;
  bool      get isAdmin  => _role == 'admin';

  /// 初始化：等待 AuthService 完成数据库初始化
  Future<void> initialize() async {
    await AuthService.instance.init();
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  /// 登录
  Future<bool> login(String username, String password) async {
    _error = null;
    if (username.trim().isEmpty || password.isEmpty) {
      _error = '用户名和密码不能为空';
      notifyListeners();
      return false;
    }

    final ok = AuthService.instance.verify(username.trim(), password);
    if (ok) {
      _username = username.trim();
      _role     = AuthService.instance.getRole(_username!);
      _state    = AuthState.authenticated;
      _error    = null;
    } else {
      _error = '用户名或密码错误';
    }
    notifyListeners();
    return ok;
  }

  /// 登出
  void logout() {
    _username = null;
    _role     = null;
    _state    = AuthState.unauthenticated;
    _error    = null;
    notifyListeners();
  }

  /// 修改密码
  bool changePassword(String oldPwd, String newPwd, String confirmPwd) {
    _error = null;
    if (newPwd != confirmPwd) {
      _error = '两次输入的新密码不一致';
      notifyListeners();
      return false;
    }
    if (newPwd.length < 4) {
      _error = '新密码长度不能少于 4 位';
      notifyListeners();
      return false;
    }
    final ok = AuthService.instance.changePassword(
      username: _username!,
      oldPassword: oldPwd,
      newPassword: newPwd,
    );
    if (!ok) {
      _error = '原密码错误';
      notifyListeners();
    }
    return ok;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
