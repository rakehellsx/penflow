import 'dart:io';
import 'package:flutter/material.dart';
import '../services/vm_backend.dart';
import '../services/vmrest_launcher.dart';

enum VmManagerStatus { idle, loading, error }

class VmManagerProvider extends ChangeNotifier {
  final VmBackend _backend = VmBackendFactory.create();

  List<VmInfo>     _vms         = [];
  VmManagerStatus  _status      = VmManagerStatus.idle;
  String?          _error;
  bool             _available   = false;
  bool             _initialized = false;

  // vmrest 启动状态（仅 Windows 有意义）
  VmrestStatus     _vmrestStatus  = VmrestStatus.notApplicable;
  String           _vmrestMessage = '';

  List<VmInfo>    get vms           => _vms;
  VmManagerStatus get status        => _status;
  String?         get error         => _error;
  bool            get available     => _available;
  bool            get isLoading     => _status == VmManagerStatus.loading;
  String          get backendName   => _backend.backendName;
  VmrestStatus    get vmrestStatus  => _vmrestStatus;
  String          get vmrestMessage => _vmrestMessage;

  /// 是否正在启动 vmrest（用于 UI 显示进度）
  bool get isLaunchingVmrest =>
      _vmrestStatus == VmrestStatus.checking ||
      _vmrestStatus == VmrestStatus.starting;

  // ── 初始化 ─────────────────────────────────────────────────────────────────

  /// 初始化：Windows 下自动检测并启动 vmrest.exe，然后加载 VM 列表
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _status = VmManagerStatus.loading;
    notifyListeners();

    // Windows：先确保 vmrest.exe 运行
    if (Platform.isWindows) {
      await _ensureVmrest();
    }

    // 检测后端可用性并加载 VM 列表
    _available = await _backend.isAvailable();
    if (_available) {
      await _loadVms();
    } else {
      _status = VmManagerStatus.idle;
    }
    notifyListeners();
  }

  /// 确保 vmrest.exe 正在运行（Windows 专用）
  Future<void> _ensureVmrest() async {
    final launcher = VmrestLauncher(
      onProgress: (status, message) {
        _vmrestStatus  = status;
        _vmrestMessage = message;
        notifyListeners();
      },
    );

    final result = await launcher.ensureRunning();
    _vmrestStatus  = result.status;
    _vmrestMessage = result.message;

    if (!result.isAvailable) {
      // vmrest 不可用，记录错误但不阻断启动（VM 面板会显示不可用提示）
      _error = result.message;
    }
    notifyListeners();
  }

  // ── VM 列表操作 ────────────────────────────────────────────────────────────

  Future<void> _loadVms() async {
    try {
      _vms   = await _backend.listVms();
      _status = VmManagerStatus.idle;
      _error  = null;
    } catch (e) {
      _status = VmManagerStatus.error;
      _error  = e.toString();
    }
  }

  /// 刷新 VM 列表（Windows 下若 vmrest 未运行会先尝试启动）
  Future<void> refresh() async {
    _status = VmManagerStatus.loading;
    notifyListeners();

    if (Platform.isWindows && !_available) {
      await _ensureVmrest();
    }

    _available = await _backend.isAvailable();
    if (_available) {
      await _loadVms();
    } else {
      _status = VmManagerStatus.idle;
    }
    notifyListeners();
  }

  // ── VM 电源操作 ────────────────────────────────────────────────────────────

  /// 开机
  Future<bool> powerOn(String vmId) async {
    final ok = await _backend.powerOn(vmId);
    if (ok) await _updateVmState(vmId, VmPowerState.poweredOn);
    return ok;
  }

  /// 关机
  Future<bool> powerOff(String vmId) async {
    final ok = await _backend.powerOff(vmId);
    if (ok) await _updateVmState(vmId, VmPowerState.poweredOff);
    return ok;
  }

  /// 重启
  Future<bool> reboot(String vmId) async {
    final ok = await _backend.reboot(vmId);
    if (ok) await _updateVmState(vmId, VmPowerState.poweredOn);
    return ok;
  }

  /// 挂起
  Future<bool> suspend(String vmId) async {
    final ok = await _backend.suspend(vmId);
    if (ok) await _updateVmState(vmId, VmPowerState.suspended);
    return ok;
  }

  /// 删除
  Future<bool> delete(String vmId) async {
    final ok = await _backend.delete(vmId);
    if (ok) {
      _vms = _vms.where((v) => v.id != vmId).toList();
      notifyListeners();
    }
    return ok;
  }

  /// 新建虚拟机
  Future<VmInfo?> createVm(CreateVmRequest req) async {
    _status = VmManagerStatus.loading;
    notifyListeners();

    final vm = await _backend.createVm(req);
    if (vm != null) {
      _vms = [..._vms, vm];
    }
    _status = VmManagerStatus.idle;
    notifyListeners();
    return vm;
  }

  Future<void> _updateVmState(String vmId, VmPowerState state) async {
    _vms = _vms.map((v) {
      if (v.id == vmId) return v.copyWith(powerState: state);
      return v;
    }).toList();
    notifyListeners();
  }

  /// 打开虚拟机控制台
  Future<ConsoleResult> openConsole(String vmId, {String? vmName}) async {
    return _backend.openConsole(vmId, vmName: vmName);
  }

  /// VMware 凭据配置（仅 Windows）
  void configureVmwareCredentials(String username, String password) {
    if (_backend is VmwareWorkstationBackend) {
      (_backend as VmwareWorkstationBackend).setCredentials(username, password);
    }
  }
}
