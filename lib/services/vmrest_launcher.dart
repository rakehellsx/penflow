import 'dart:io';
import 'dart:async';

// ─────────────────────────────────────────────────────────────────────────────
// vmrest.exe 启动状态
// ─────────────────────────────────────────────────────────────────────────────

enum VmrestStatus {
  /// 仅在 Linux 下，跳过检测
  notApplicable,

  /// 正在检测进程是否运行
  checking,

  /// vmrest.exe 已在运行，API 可用
  running,

  /// vmrest.exe 未运行，正在尝试启动
  starting,

  /// vmrest.exe 已成功启动，API 就绪
  started,

  /// 未找到 vmrest.exe 可执行文件
  notFound,

  /// 启动失败（权限不足 / 崩溃 / 超时）
  failed,
}

// ─────────────────────────────────────────────────────────────────────────────
// vmrest.exe 启动结果
// ─────────────────────────────────────────────────────────────────────────────

class VmrestLaunchResult {
  final VmrestStatus status;
  final String message;
  final String? vmrestPath;

  const VmrestLaunchResult({
    required this.status,
    required this.message,
    this.vmrestPath,
  });

  bool get isAvailable =>
      status == VmrestStatus.running || status == VmrestStatus.started;
}

// ─────────────────────────────────────────────────────────────────────────────
// vmrest.exe 启动器
// ─────────────────────────────────────────────────────────────────────────────

class VmrestLauncher {
  /// vmrest.exe 常见安装路径（按优先级排列）
  static const List<String> _candidatePaths = [
    r'C:\Program Files (x86)\VMware\VMware Workstation\vmrest.exe',
    r'C:\Program Files\VMware\VMware Workstation\vmrest.exe',
    r'C:\Program Files (x86)\VMware\VMware Player\vmrest.exe',
    r'C:\Program Files\VMware\VMware Player\vmrest.exe',
  ];

  /// REST API 地址
  static const String _apiUrl = 'http://127.0.0.1:8697/api/vms';

  /// 进度回调（可选），用于向 UI 汇报状态
  final void Function(VmrestStatus status, String message)? onProgress;

  VmrestLauncher({this.onProgress});

  void _report(VmrestStatus status, String message) {
    onProgress?.call(status, message);
  }

  // ── 公共入口 ──────────────────────────────────────────────────────────────

  /// 在 Windows 下检测并启动 vmrest.exe
  /// 非 Windows 平台直接返回 [VmrestStatus.notApplicable]
  Future<VmrestLaunchResult> ensureRunning() async {
    if (!Platform.isWindows) {
      return const VmrestLaunchResult(
        status: VmrestStatus.notApplicable,
        message: '非 Windows 平台，跳过 vmrest 检测',
      );
    }

    _report(VmrestStatus.checking, '正在检测 vmrest.exe 运行状态...');

    // 1. 先检测进程是否已在运行
    if (await _isProcessRunning()) {
      // 进程存在，再确认 API 是否可响应
      if (await _waitForApi(maxRetries: 3, intervalMs: 500)) {
        _report(VmrestStatus.running, 'vmrest.exe 已在运行，API 可用');
        return const VmrestLaunchResult(
          status: VmrestStatus.running,
          message: 'vmrest.exe 已在运行，VMware REST API 可用',
        );
      }
      // 进程在但 API 未响应（可能刚启动），继续等待
      _report(VmrestStatus.running, 'vmrest.exe 进程存在，等待 API 就绪...');
      if (await _waitForApi(maxRetries: 10, intervalMs: 800)) {
        return const VmrestLaunchResult(
          status: VmrestStatus.running,
          message: 'vmrest.exe 已在运行，VMware REST API 就绪',
        );
      }
    }

    // 2. 进程未运行，查找 vmrest.exe
    final vmrestPath = _findVmrest();
    if (vmrestPath == null) {
      _report(VmrestStatus.notFound,
          '未找到 vmrest.exe，请确认已安装 VMware Workstation');
      return const VmrestLaunchResult(
        status: VmrestStatus.notFound,
        message: '未找到 vmrest.exe\n'
            '请确认已安装 VMware Workstation Pro/Player\n'
            '或手动启动：vmrest.exe（位于 VMware 安装目录）',
      );
    }

    // 3. 启动 vmrest.exe
    _report(VmrestStatus.starting, '正在启动 vmrest.exe...');
    final launched = await _launchVmrest(vmrestPath);
    if (!launched) {
      _report(VmrestStatus.failed, '启动 vmrest.exe 失败');
      return VmrestLaunchResult(
        status: VmrestStatus.failed,
        message: '启动 vmrest.exe 失败\n路径：$vmrestPath\n'
            '请尝试以管理员身份运行 PenFlow',
        vmrestPath: vmrestPath,
      );
    }

    // 4. 等待 API 就绪（最多 15 秒）
    _report(VmrestStatus.starting, 'vmrest.exe 已启动，等待 API 就绪...');
    if (await _waitForApi(maxRetries: 20, intervalMs: 750)) {
      _report(VmrestStatus.started, 'vmrest.exe 启动成功，API 就绪');
      return VmrestLaunchResult(
        status: VmrestStatus.started,
        message: 'vmrest.exe 已成功启动，VMware REST API 就绪',
        vmrestPath: vmrestPath,
      );
    }

    // 超时
    _report(VmrestStatus.failed, 'vmrest.exe 启动超时，API 未响应');
    return VmrestLaunchResult(
      status: VmrestStatus.failed,
      message: 'vmrest.exe 已启动但 API 未在 15 秒内响应\n'
          '请检查 vmrest 凭据配置（运行 vmrest.exe -C 设置凭据）',
      vmrestPath: vmrestPath,
    );
  }

  // ── 私有方法 ──────────────────────────────────────────────────────────────

  /// 通过 tasklist 检测 vmrest.exe 是否在运行
  Future<bool> _isProcessRunning() async {
    try {
      final result = await Process.run(
        'tasklist',
        ['/FI', 'IMAGENAME eq vmrest.exe', '/NH', '/FO', 'CSV'],
        runInShell: true,
      ).timeout(const Duration(seconds: 5));
      final stdout = (result.stdout as String).toLowerCase();
      return stdout.contains('vmrest.exe');
    } catch (_) {
      // tasklist 失败时尝试 WMIC
      try {
        final result = await Process.run(
          'wmic',
          ['process', 'where', 'name="vmrest.exe"', 'get', 'ProcessId'],
          runInShell: true,
        ).timeout(const Duration(seconds: 5));
        final stdout = (result.stdout as String).trim();
        // 有进程时输出包含数字 PID
        return stdout.contains(RegExp(r'\d+'));
      } catch (_) {
        return false;
      }
    }
  }

  /// 在候选路径中查找 vmrest.exe
  String? _findVmrest() {
    for (final path in _candidatePaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    // 尝试从注册表读取 VMware 安装路径（通过 reg query）
    try {
      final result = Process.runSync(
        'reg',
        [
          'query',
          r'HKLM\SOFTWARE\WOW6432Node\VMware, Inc.\VMware Workstation',
          '/v',
          'InstallPath',
        ],
        runInShell: true,
      );
      final stdout = result.stdout as String;
      final match = RegExp(r'InstallPath\s+REG_SZ\s+(.+)').firstMatch(stdout);
      if (match != null) {
        final installDir = match.group(1)!.trim();
        final candidate = '$installDir\\vmrest.exe';
        if (File(candidate).existsSync()) {
          return candidate;
        }
      }
    } catch (_) {}

    return null;
  }

  /// 后台启动 vmrest.exe
  Future<bool> _launchVmrest(String path) async {
    try {
      // 使用 Process.start 后台启动，不等待退出
      await Process.start(
        path,
        [],
        mode: ProcessStartMode.detached,
        runInShell: false,
      );
      // 给进程 1 秒初始化时间
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 轮询 vmrest API 直到响应或超时
  Future<bool> _waitForApi({
    required int maxRetries,
    required int intervalMs,
  }) async {
    for (var i = 0; i < maxRetries; i++) {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 2);
        final uri = Uri.parse(_apiUrl);
        final req = await client.getUrl(uri);
        // vmrest 默认不需要凭据也能返回 401（说明服务已启动）
        final resp = await req.close().timeout(const Duration(seconds: 2));
        await resp.drain<void>();
        client.close();
        // 200 = 已配置凭据且可用；401 = 服务已启动但需要凭据
        if (resp.statusCode == 200 || resp.statusCode == 401) {
          return true;
        }
      } catch (_) {
        // 连接失败，继续等待
      }
      if (i < maxRetries - 1) {
        await Future.delayed(Duration(milliseconds: intervalMs));
      }
    }
    return false;
  }
}
