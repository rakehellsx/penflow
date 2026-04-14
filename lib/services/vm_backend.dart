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

  String get backendName;
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
  static const String _baseUrl = 'http://127.0.0.1:8697/api';

  // 从环境变量或配置读取凭据，默认空（需用户配置）
  String _username = '';
  String _password = '';

  @override
  String get backendName => 'VMware Workstation (vmrest)';

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
