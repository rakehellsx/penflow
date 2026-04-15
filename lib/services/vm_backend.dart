import 'dart:io';

// ─────────────────────────────────────────────────────────────────────────────
// 数据模型
// ─────────────────────────────────────────────────────────────────────────────

enum VmPowerState { poweredOn, poweredOff, suspended, paused, unknown }

class VmInfo {
  final String id;
  final String name;
  final String osType;   // linux / windows / unknown
  final int    cpuCount;
  final int    memoryMB;
  final String ipAddress;
  final VmPowerState powerState;
  final String? imagePath;

  const VmInfo({
    required this.id,
    required this.name,
    required this.osType,
    required this.cpuCount,
    required this.memoryMB,
    required this.ipAddress,
    required this.powerState,
    this.imagePath,
  });

  VmInfo copyWith({VmPowerState? powerState, String? ipAddress}) => VmInfo(
        id: id,
        name: name,
        osType: osType,
        cpuCount: cpuCount,
        memoryMB: memoryMB,
        ipAddress: ipAddress ?? this.ipAddress,
        powerState: powerState ?? this.powerState,
        imagePath: imagePath,
      );
}

class CreateVmRequest {
  final String name;
  final String isoPath;
  final int    cpuCount;
  final int    memoryMB;
  final int    diskGB;
  final String osType;

  const CreateVmRequest({
    required this.name,
    required this.isoPath,
    required this.cpuCount,
    required this.memoryMB,
    required this.diskGB,
    required this.osType,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 抽象后端接口
// ─────────────────────────────────────────────────────────────────────────────

abstract class VmBackend {
  /// 检测后端是否可用（vmrest 进程/virsh 命令是否存在）
  Future<bool> isAvailable();

  /// 获取所有虚拟机列表
  Future<List<VmInfo>> listVms();

  /// 开机
  Future<bool> powerOn(String vmId);

  /// 关机（强制）
  Future<bool> powerOff(String vmId);

  /// 重启
  Future<bool> reboot(String vmId);

  /// 挂起
  Future<bool> suspend(String vmId);

  /// 删除
  Future<bool> delete(String vmId);

  /// 新建虚拟机
  Future<VmInfo?> createVm(CreateVmRequest req);

  /// 获取单个 VM 状态
  Future<VmPowerState> getPowerState(String vmId);

  /// 打开虚拟机控制台/GUI 界面
  /// 返回 [ConsoleResult]，包含是否成功和错误信息
  Future<ConsoleResult> openConsole(String vmId, {String? vmName});

  String get backendName;
}

// ─────────────────────────────────────────────────────────────────────────────
// 控制台连接结果
// ─────────────────────────────────────────────────────────────────────────────

class ConsoleResult {
  final bool success;
  final String message;
  final ConsoleMethod method;

  const ConsoleResult({
    required this.success,
    required this.message,
    required this.method,
  });
}

enum ConsoleMethod {
  vmwareGui,      // VMware Workstation GUI 窗口
  vmwareVnc,      // VMware VNC 连接
  virtViewer,     // virt-viewer (SPICE/VNC)
  virshConsole,   // virsh console (串行终端)
  remoteViewer,   // remote-viewer
  notAvailable,   // 后端不可用
}

// ─────────────────────────────────────────────────────────────────────────────
// 平台检测工厂
// ─────────────────────────────────────────────────────────────────────────────

class VmBackendFactory {
  static VmBackend create() {
    if (Platform.isWindows) {
      return VmwareWorkstationBackend();
    } else {
      return KvmLibvirtBackend();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VMware Workstation REST API 后端（Windows）
// API Base: http://127.0.0.1:8697/api
// Auth: Basic Auth (vmrest credentials)
// ─────────────────────────────────────────────────────────────────────────────

class VmwareWorkstationBackend extends VmBackend {
  // 动态配置：地址、端口、凭据（通过 applyConfig 更新）
  String _host     = '127.0.0.1';
  int    _port     = 8697;
  String _username = '';
  String _password = '';

  String get _baseUrl => 'http://$_host:$_port/api';

  @override
  String get backendName => 'VMware Workstation (vmrest)';

  /// 一次性应用完整配置（地址 + 凭据）
  void applyConfig({
    required String host,
    required int    port,
    required String username,
    required String password,
  }) {
    _host     = host.isEmpty ? '127.0.0.1' : host;
    _port     = port <= 0   ? 8697        : port;
    _username = username;
    _password = password;
  }

  void setCredentials(String username, String password) {
    _username = username;
    _password = password;
  }

  String get _authHeader {
    final credentials = '$_username:$_password';
    final encoded = _base64Encode(credentials);
    return 'Basic $encoded';
  }

  String _base64Encode(String input) {
    // Dart 内置 base64
    final bytes = input.codeUnits;
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final result = StringBuffer();
    for (var i = 0; i < bytes.length; i += 3) {
      final b0 = bytes[i];
      final b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      result.write(chars[(b0 >> 2) & 0x3F]);
      result.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      result.write(i + 1 < bytes.length ? chars[((b1 << 2) | (b2 >> 6)) & 0x3F] : '=');
      result.write(i + 2 < bytes.length ? chars[b2 & 0x3F] : '=');
    }
    return result.toString();
  }

  Future<HttpClientResponse?> _request(
    String method,
    String path, {
    String? body,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final uri = Uri.parse('$_baseUrl$path');
      final request = await client.openUrl(method, uri);
      request.headers.set('Authorization', _authHeader);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'application/json');
      if (body != null) {
        request.write(body);
      }
      return await request.close();
    } catch (_) {
      return null;
    }
  }

  Future<String> _readBody(HttpClientResponse resp) async {
    final chunks = <int>[];
    await for (final chunk in resp) {
      chunks.addAll(chunk);
    }
    return String.fromCharCodes(chunks);
  }

  @override
  Future<bool> isAvailable() async {
    // 检测 vmrest 进程是否在运行
    try {
      final result = await Process.run(
        'tasklist',
        ['/FI', 'IMAGENAME eq vmrest.exe', '/NH'],
        runInShell: true,
      );
      if ((result.stdout as String).contains('vmrest.exe')) return true;
    } catch (_) {}

    // 尝试连接 API
    final resp = await _request('GET', '/vms');
    return resp != null && resp.statusCode == 200;
  }

  @override
  Future<List<VmInfo>> listVms() async {
    final resp = await _request('GET', '/vms');
    if (resp == null || resp.statusCode != 200) return [];

    final body = await _readBody(resp);
    // 解析 JSON 数组: [{"id":"xxx","path":"..."}]
    final vms = <VmInfo>[];
    final matches = RegExp(r'"id"\s*:\s*"([^"]+)"[^}]*"path"\s*:\s*"([^"]+)"')
        .allMatches(body);
    for (final m in matches) {
      final id   = m.group(1)!;
      final path = m.group(2)!;
      final name = path.split(RegExp(r'[/\\]')).last.replaceAll('.vmx', '');

      // 获取电源状态
      final state = await getPowerState(id);

      // 获取 IP（可选）
      String ip = '';
      final ipResp = await _request('GET', '/vms/$id/ip');
      if (ipResp != null && ipResp.statusCode == 200) {
        final ipBody = await _readBody(ipResp);
        final ipMatch = RegExp(r'"ip"\s*:\s*"([^"]+)"').firstMatch(ipBody);
        ip = ipMatch?.group(1) ?? '';
      }

      vms.add(VmInfo(
        id: id,
        name: name,
        osType: path.toLowerCase().contains('win') ? 'windows' : 'linux',
        cpuCount: 2,
        memoryMB: 2048,
        ipAddress: ip,
        powerState: state,
        imagePath: path,
      ));
    }
    return vms;
  }

  @override
  Future<VmPowerState> getPowerState(String vmId) async {
    final resp = await _request('GET', '/vms/$vmId/power');
    if (resp == null || resp.statusCode != 200) return VmPowerState.unknown;
    final body = await _readBody(resp);
    if (body.contains('poweredOn'))  return VmPowerState.poweredOn;
    if (body.contains('poweredOff')) return VmPowerState.poweredOff;
    if (body.contains('suspended'))  return VmPowerState.suspended;
    if (body.contains('paused'))     return VmPowerState.paused;
    return VmPowerState.unknown;
  }

  @override
  Future<bool> powerOn(String vmId) async {
    final resp = await _request('PUT', '/vms/$vmId/power',
        body: '"on"');
    return resp != null && resp.statusCode == 200;
  }

  @override
  Future<bool> powerOff(String vmId) async {
    final resp = await _request('PUT', '/vms/$vmId/power',
        body: '"off"');
    return resp != null && resp.statusCode == 200;
  }

  @override
  Future<bool> reboot(String vmId) async {
    // VMware Workstation API 无直接重启端点，先关后开
    await powerOff(vmId);
    await Future.delayed(const Duration(seconds: 2));
    return powerOn(vmId);
  }

  @override
  Future<bool> suspend(String vmId) async {
    final resp = await _request('PUT', '/vms/$vmId/power',
        body: '"suspend"');
    return resp != null && resp.statusCode == 200;
  }

  @override
  Future<bool> delete(String vmId) async {
    final resp = await _request('DELETE', '/vms/$vmId');
    return resp != null && (resp.statusCode == 200 || resp.statusCode == 204);
  }

  @override
  Future<ConsoleResult> openConsole(String vmId, {String? vmName}) async {
    // VMware Workstation 控制台连接策略：
    // 1. 优先使用 vmrun gui 打开 VMware GUI 窗口（需要 .vmx 路径）
    // 2. 降级：通过 vmplayer 打开
    // 3. 降级：通过 vmware.exe 打开
    // vmId 在 VMware 后端就是 .vmx 文件路径

    final vmxPath = vmId; // VMware 后端的 vmId 就是 vmx 路径

    // 候选 vmrun 路径
    final vmrunCandidates = [
      r'C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe',
      r'C:\Program Files\VMware\VMware Workstation\vmrun.exe',
    ];

    for (final vmrunPath in vmrunCandidates) {
      if (await File(vmrunPath).exists()) {
        try {
          // vmrun gui <vmx> 打开 GUI 窗口
          final result = await Process.run(
            vmrunPath,
            ['gui', vmxPath],
            runInShell: false,
          );
          if (result.exitCode == 0) {
            return ConsoleResult(
              success: true,
              message: '已通过 VMware Workstation 打开虚拟机控制台',
              method: ConsoleMethod.vmwareGui,
            );
          }
        } catch (_) {}
      }
    }

    // 降级：使用 vmplayer.exe 打开 .vmx
    final vmplayerCandidates = [
      r'C:\Program Files (x86)\VMware\VMware Player\vmplayer.exe',
      r'C:\Program Files\VMware\VMware Player\vmplayer.exe',
    ];
    for (final playerPath in vmplayerCandidates) {
      if (await File(playerPath).exists()) {
        try {
          await Process.start(playerPath, [vmxPath], mode: ProcessStartMode.detached);
          return ConsoleResult(
            success: true,
            message: '已通过 VMware Player 打开虚拟机',
            method: ConsoleMethod.vmwareGui,
          );
        } catch (_) {}
      }
    }

    // 降级：使用 vmware.exe 打开
    final vmwareCandidates = [
      r'C:\Program Files (x86)\VMware\VMware Workstation\vmware.exe',
      r'C:\Program Files\VMware\VMware Workstation\vmware.exe',
    ];
    for (final vmwarePath in vmwareCandidates) {
      if (await File(vmwarePath).exists()) {
        try {
          await Process.start(vmwarePath, [vmxPath], mode: ProcessStartMode.detached);
          return ConsoleResult(
            success: true,
            message: '已通过 VMware Workstation 打开虚拟机',
            method: ConsoleMethod.vmwareGui,
          );
        } catch (_) {}
      }
    }

    return ConsoleResult(
      success: false,
      message: '未找到 VMware 可执行文件，请确认 VMware Workstation 已安装',
      method: ConsoleMethod.notAvailable,
    );
  }

  @override
  Future<VmInfo?> createVm(CreateVmRequest req) async {
    // VMware Workstation REST API 通过 clone 创建
    // POST /vms  body: {"name":"...","parentId":"..."}
    // 由于需要父 VM，这里通过 vmrun 命令创建
    try {
      final vmrunPath = r'C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe';
      final vmxPath   = '${Platform.environment['USERPROFILE']}\\Documents\\Virtual Machines\\${req.name}\\${req.name}.vmx';

      // 使用 vmrun 创建（需要 VMware Workstation 已安装）
      final result = await Process.run(vmrunPath, [
        'createVM',
        vmxPath,
        '--guestOS', req.osType == 'windows' ? 'windows9-64' : 'ubuntu-64',
        '--numvcpus', req.cpuCount.toString(),
        '--memsize',  req.memoryMB.toString(),
      ]);

      if (result.exitCode == 0) {
        return VmInfo(
          id: vmxPath,
          name: req.name,
          osType: req.osType,
          cpuCount: req.cpuCount,
          memoryMB: req.memoryMB,
          ipAddress: '',
          powerState: VmPowerState.poweredOff,
          imagePath: vmxPath,
        );
      }
    } catch (_) {}
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KVM/QEMU libvirt 后端（Linux）
// 通过 virsh 命令行调用 libvirt
// ─────────────────────────────────────────────────────────────────────────────

class KvmLibvirtBackend extends VmBackend {
  @override
  String get backendName => 'KVM/QEMU (libvirt/virsh)';

  Future<ProcessResult> _virsh(List<String> args) async {
    return Process.run('virsh', args, runInShell: false);
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await _virsh(['version', '--daemon']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<VmInfo>> listVms() async {
    final vms = <VmInfo>[];

    // 获取所有域（包括关机的）
    final result = await _virsh(['list', '--all', '--name']);
    if (result.exitCode != 0) return vms;

    final names = (result.stdout as String)
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    for (final name in names) {
      final info = await _getVmInfo(name);
      if (info != null) vms.add(info);
    }
    return vms;
  }

  Future<VmInfo?> _getVmInfo(String name) async {
    try {
      // virsh dominfo <name>
      final infoResult = await _virsh(['dominfo', name]);
      if (infoResult.exitCode != 0) return null;

      final infoText = infoResult.stdout as String;
      int    cpuCount = 1;
      int    memoryMB = 512;
      String state    = 'shut off';

      for (final line in infoText.split('\n')) {
        if (line.startsWith('CPU(s):')) {
          cpuCount = int.tryParse(line.split(':').last.trim()) ?? 1;
        } else if (line.startsWith('Max memory:')) {
          final kb = int.tryParse(
                  line.split(':').last.trim().replaceAll(RegExp(r'[^\d]'), '')) ??
              524288;
          memoryMB = kb ~/ 1024;
        } else if (line.startsWith('State:')) {
          state = line.split(':').last.trim();
        }
      }

      // 获取 IP（通过 virsh domifaddr）
      String ip = '';
      final ipResult = await _virsh(['domifaddr', name]);
      if (ipResult.exitCode == 0) {
        final ipMatch = RegExp(r'(\d+\.\d+\.\d+\.\d+)')
            .firstMatch(ipResult.stdout as String);
        ip = ipMatch?.group(1) ?? '';
      }

      // 获取 UUID 作为 ID
      final uuidMatch =
          RegExp(r'UUID:\s+([a-f0-9\-]+)').firstMatch(infoText);
      final id = uuidMatch?.group(1) ?? name;

      return VmInfo(
        id: id,
        name: name,
        osType: _guessOsType(name),
        cpuCount: cpuCount,
        memoryMB: memoryMB,
        ipAddress: ip,
        powerState: _parseState(state),
      );
    } catch (_) {
      return null;
    }
  }

  String _guessOsType(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('win')) return 'windows';
    if (lower.contains('kali') ||
        lower.contains('ubuntu') ||
        lower.contains('parrot') ||
        lower.contains('linux')) return 'linux';
    return 'linux';
  }

  VmPowerState _parseState(String state) {
    switch (state.toLowerCase()) {
      case 'running':
        return VmPowerState.poweredOn;
      case 'shut off':
      case 'shutoff':
        return VmPowerState.poweredOff;
      case 'paused':
        return VmPowerState.paused;
      case 'pmsuspended':
      case 'suspended':
        return VmPowerState.suspended;
      default:
        return VmPowerState.unknown;
    }
  }

  @override
  Future<VmPowerState> getPowerState(String vmId) async {
    // vmId 可能是 UUID 或名称
    final result = await _virsh(['domstate', vmId]);
    if (result.exitCode != 0) return VmPowerState.unknown;
    return _parseState((result.stdout as String).trim());
  }

  @override
  Future<bool> powerOn(String vmId) async {
    final result = await _virsh(['start', vmId]);
    return result.exitCode == 0;
  }

  @override
  Future<bool> powerOff(String vmId) async {
    // 先尝试优雅关机，失败则强制
    var result = await _virsh(['shutdown', vmId]);
    if (result.exitCode != 0) {
      result = await _virsh(['destroy', vmId]);
    }
    return result.exitCode == 0;
  }

  @override
  Future<bool> reboot(String vmId) async {
    final result = await _virsh(['reboot', vmId]);
    return result.exitCode == 0;
  }

  @override
  Future<bool> suspend(String vmId) async {
    final result = await _virsh(['suspend', vmId]);
    return result.exitCode == 0;
  }

  @override
  Future<bool> delete(String vmId) async {
    // 先关机，再 undefine（保留磁盘需要用户手动删除）
    await _virsh(['destroy', vmId]);
    final result = await _virsh(['undefine', vmId, '--remove-all-storage']);
    return result.exitCode == 0;
  }

  @override
  Future<ConsoleResult> openConsole(String vmId, {String? vmName}) async {
    // KVM/QEMU 控制台连接策略（按优先级）：
    // 1. virt-viewer --connect qemu:///system <vmId>  (SPICE/VNC 图形界面，最佳体验)
    // 2. remote-viewer spice://localhost:<port>       (SPICE 直连)
    // 3. 在终端模拟器中运行 virsh console <vmId>      (串行控制台，文本模式)
    final name = vmName ?? vmId;

    // 策略1：virt-viewer（图形化，支持 SPICE/VNC）
    try {
      final which = await Process.run('which', ['virt-viewer']);
      if (which.exitCode == 0) {
        await Process.start(
          'virt-viewer',
          ['--connect', 'qemu:///system', '--wait', name],
          mode: ProcessStartMode.detached,
        );
        return ConsoleResult(
          success: true,
          message: '已通过 virt-viewer 打开虚拟机图形控制台',
          method: ConsoleMethod.virtViewer,
        );
      }
    } catch (_) {}

    // 策略2：remote-viewer（SPICE 直连）
    try {
      final which = await Process.run('which', ['remote-viewer']);
      if (which.exitCode == 0) {
        // 获取 SPICE 端口
        final xmlResult = await _virsh(['dumpxml', name]);
        if (xmlResult.exitCode == 0) {
          final portMatch = RegExp(r"spice.*?port='(\d+)'")
              .firstMatch(xmlResult.stdout as String);
          final port = portMatch?.group(1) ?? '5900';
          await Process.start(
            'remote-viewer',
            ['spice://localhost:$port'],
            mode: ProcessStartMode.detached,
          );
          return ConsoleResult(
            success: true,
            message: '已通过 remote-viewer 连接 SPICE 控制台（端口 $port）',
            method: ConsoleMethod.remoteViewer,
          );
        }
      }
    } catch (_) {}

    // 策略3：在终端中运行 virsh console（串行文本控制台）
    // 尝试多种终端模拟器
    final terminals = [
      ['gnome-terminal', '--', 'virsh', 'console', name],
      ['xterm', '-e', 'virsh console $name'],
      ['konsole', '-e', 'virsh', 'console', name],
      ['xfce4-terminal', '-e', 'virsh console $name'],
      ['lxterminal', '-e', 'virsh console $name'],
    ];

    for (final termArgs in terminals) {
      try {
        final which = await Process.run('which', [termArgs[0]]);
        if (which.exitCode == 0) {
          await Process.start(
            termArgs[0],
            termArgs.sublist(1),
            mode: ProcessStartMode.detached,
          );
          return ConsoleResult(
            success: true,
            message: '已在 ${termArgs[0]} 中打开 virsh 串行控制台',
            method: ConsoleMethod.virshConsole,
          );
        }
      } catch (_) {}
    }

    // 最后降级：直接 virsh console（当前终端，阻塞）
    try {
      await Process.start(
        'virsh',
        ['console', name],
        mode: ProcessStartMode.inheritStdio,
      );
      return ConsoleResult(
        success: true,
        message: '已在当前终端打开 virsh 串行控制台（按 Ctrl+] 退出）',
        method: ConsoleMethod.virshConsole,
      );
    } catch (e) {
      return ConsoleResult(
        success: false,
        message: '无法打开控制台：$e\n请安装 virt-viewer: sudo apt install virt-viewer',
        method: ConsoleMethod.notAvailable,
      );
    }
  }

  @override
  Future<VmInfo?> createVm(CreateVmRequest req) async {
    // 使用 virt-install 创建虚拟机
    try {
      final args = [
        '--name',     req.name,
        '--memory',   req.memoryMB.toString(),
        '--vcpus',    req.cpuCount.toString(),
        '--disk',     'size=${req.diskGB}',
        '--cdrom',    req.isoPath,
        '--os-variant', req.osType == 'windows' ? 'win10' : 'ubuntu22.04',
        '--graphics', 'vnc',
        '--noautoconsole',
      ];

      final result = await Process.run('virt-install', args);
      if (result.exitCode == 0) {
        return VmInfo(
          id: req.name,
          name: req.name,
          osType: req.osType,
          cpuCount: req.cpuCount,
          memoryMB: req.memoryMB,
          ipAddress: '',
          powerState: VmPowerState.poweredOff,
        );
      }
    } catch (_) {}
    return null;
  }
}
