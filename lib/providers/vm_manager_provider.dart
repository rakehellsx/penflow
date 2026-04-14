import 'package:flutter/material.dart';
import '../services/vm_backend.dart';

enum VmManagerStatus { idle, loading, error }

class VmManagerProvider extends ChangeNotifier {
  final VmBackend _backend = VmBackendFactory.create();

  List<VmInfo>     _vms       = [];
  VmManagerStatus  _status    = VmManagerStatus.idle;
  String?          _error;
  bool             _available = false;
  bool             _initialized = false;

  List<VmInfo>    get vms       => _vms;
  VmManagerStatus get status    => _status;
  String?         get error     => _error;
  bool            get available => _available;
  bool            get isLoading => _status == VmManagerStatus.loading;
  String          get backendName => _backend.backendName;

  /// 初始化：检测后端可用性并加载 VM 列表
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _status = VmManagerStatus.loading;
    notifyListeners();

    _available = await _backend.isAvailable();
    if (_available) {
      await _loadVms();
    } else {
      _status = VmManagerStatus.idle;
    }
    notifyListeners();
  }

  Future<void> _loadVms() async {
    try {
      _vms = await _backend.listVms();
      _status = VmManagerStatus.idle;
      _error  = null;
    } catch (e) {
      _status = VmManagerStatus.error;
      _error  = e.toString();
    }
  }

  /// 刷新 VM 列表
  Future<void> refresh() async {
    _status = VmManagerStatus.loading;
    notifyListeners();
    _available = await _backend.isAvailable();
    if (_available) {
      await _loadVms();
    } else {
      _status = VmManagerStatus.idle;
    }
    notifyListeners();
  }

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
  /// [vmId] 为后端 VM ID（VMware: vmx 路径，KVM: UUID 或名称）
  /// [vmName] 可选，用于 KVM virsh 命令中的名称参数
  Future<ConsoleResult> openConsole(String vmId, {String? vmName}) async {
    return _backend.openConsole(vmId, vmName: vmName);
  }

  /// VMware 凭据配置（仅 Windows）
  void configureVmwareCredentials(String username, String password) {
    if (_backend is VmwareWorkstationBackend) {
      (_backend as VmwareWorkstationBackend)
          .setCredentials(username, password);
    }
  }
}
