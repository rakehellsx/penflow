import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/vm_manager_provider.dart';
import '../services/vm_backend.dart';
import '../utils/app_theme.dart';

class CreateVmDialog extends StatefulWidget {
  const CreateVmDialog({super.key});

  @override
  State<CreateVmDialog> createState() => _CreateVmDialogState();
}

class _CreateVmDialogState extends State<CreateVmDialog> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController(text: 'PenFlow-VM');
  final _isoCtrl   = TextEditingController();
  final _diskCtrl  = TextEditingController(text: '40');

  int    _cpuCount  = 2;
  int    _memoryMB  = 2048;
  String _osType    = 'linux';
  bool   _creating  = false;
  String? _errorMsg;

  // 预设内存选项（MB）
  static const _memOptions = [512, 1024, 2048, 4096, 8192, 16384];
  // 预设 CPU 选项
  static const _cpuOptions = [1, 2, 4, 8, 16];

  // 常用 OS 类型
  static const _osOptions = [
    {'value': 'linux',   'label': 'Linux (通用)',   'icon': '🐧'},
    {'value': 'ubuntu',  'label': 'Ubuntu',         'icon': '🟠'},
    {'value': 'kali',    'label': 'Kali Linux',     'icon': '🐉'},
    {'value': 'parrot',  'label': 'Parrot OS',      'icon': '🦜'},
    {'value': 'windows', 'label': 'Windows',        'icon': '🪟'},
    {'value': 'other',   'label': '其他',            'icon': '💻'},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _isoCtrl.dispose();
    _diskCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickIso() async {
    // 通过文件对话框选择 ISO（使用 file_picker 或手动输入）
    // 由于没有 file_picker 依赖，提示用户手动输入路径
    // 在实际部署中可添加 file_picker 包
    if (Platform.isLinux) {
      try {
        final result = await Process.run(
          'zenity',
          ['--file-selection', '--title=选择 ISO 镜像文件', '--file-filter=ISO files | *.iso'],
          runInShell: true,
        );
        if (result.exitCode == 0) {
          final path = (result.stdout as String).trim();
          if (path.isNotEmpty) {
            setState(() => _isoCtrl.text = path);
          }
        }
      } catch (_) {
        // zenity 不可用，用户手动输入
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _creating = true; _errorMsg = null; });

    final req = CreateVmRequest(
      name:     _nameCtrl.text.trim(),
      isoPath:  _isoCtrl.text.trim(),
      cpuCount: _cpuCount,
      memoryMB: _memoryMB,
      diskGB:   int.tryParse(_diskCtrl.text) ?? 40,
      osType:   _osType,
    );

    final vm = await context.read<VmManagerProvider>().createVm(req);
    if (mounted) {
      setState(() => _creating = false);
      if (vm != null) {
        Navigator.pop(context, vm);
      } else {
        setState(() => _errorMsg = '创建失败，请检查虚拟机管理工具是否已安装并配置正确');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t       = context.appTheme;
    final manager = context.watch<VmManagerProvider>();

    return AlertDialog(
      backgroundColor: t.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Row(
        children: [
          const Text('🖥️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('新建虚拟机',
                    style: TextStyle(
                        color: t.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(
                  '后端: ${manager.backendName}',
                  style: TextStyle(color: AppAccent.blue, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 虚拟机名称 ──────────────────────────────
                _SectionTitle('基本信息', t),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _nameCtrl,
                  label: '虚拟机名称',
                  hint: '例如: Kali-Attack-01',
                  t: t,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '请输入虚拟机名称' : null,
                ),
                const SizedBox(height: 12),

                // ── 操作系统类型 ────────────────────────────
                _SectionTitle('操作系统', t),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _osOptions.map((os) {
                    final selected = _osType == os['value'];
                    return GestureDetector(
                      onTap: () => setState(() => _osType = os['value']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: selected
                                ? AppAccent.blue
                                : t.border,
                            width: selected ? 1.5 : 1,
                          ),
                          color: selected
                              ? AppAccent.blue.withOpacity(0.15)
                              : t.bg,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(os['icon']!,
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              os['label']!,
                              style: TextStyle(
                                color: selected ? AppAccent.blue : t.text2,
                                fontSize: 11,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // ── ISO 镜像 ────────────────────────────────
                _SectionTitle('ISO 镜像', t),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _isoCtrl,
                        label: 'ISO 文件路径',
                        hint: Platform.isWindows
                            ? r'C:\ISOs\kali-linux-2024.iso'
                            : '/home/user/isos/kali-linux-2024.iso',
                        t: t,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? '请输入 ISO 路径'
                                : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: t.card,
                          foregroundColor: t.text2,
                          side: BorderSide(color: t.border),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10),
                        ),
                        onPressed: _pickIso,
                        icon: const Icon(Icons.folder_open, size: 14),
                        label: const Text('浏览',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── CPU 配置 ────────────────────────────────
                _SectionTitle('CPU 核数', t),
                const SizedBox(height: 8),
                Row(
                  children: _cpuOptions.map((n) {
                    final selected = _cpuCount == n;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _cpuCount = n),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 48,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: selected ? AppAccent.cyan : t.border,
                              width: selected ? 1.5 : 1,
                            ),
                            color: selected
                                ? AppAccent.cyan.withOpacity(0.15)
                                : t.bg,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$n',
                            style: TextStyle(
                              color: selected ? AppAccent.cyan : t.text2,
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 4),
                Text('已选: $_cpuCount 核',
                    style: TextStyle(color: t.text3, fontSize: 10)),
                const SizedBox(height: 16),

                // ── 内存配置 ────────────────────────────────
                _SectionTitle('内存大小', t),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _memOptions.map((mb) {
                    final selected = _memoryMB == mb;
                    final label = mb >= 1024
                        ? '${mb ~/ 1024} GB'
                        : '$mb MB';
                    return GestureDetector(
                      onTap: () => setState(() => _memoryMB = mb),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: selected ? AppAccent.green : t.border,
                            width: selected ? 1.5 : 1,
                          ),
                          color: selected
                              ? AppAccent.green.withOpacity(0.15)
                              : t.bg,
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: selected ? AppAccent.green : t.text2,
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 4),
                Text(
                  '已选: ${_memoryMB >= 1024 ? "${_memoryMB ~/ 1024} GB" : "$_memoryMB MB"}',
                  style: TextStyle(color: t.text3, fontSize: 10),
                ),
                const SizedBox(height: 16),

                // ── 磁盘大小 ────────────────────────────────
                _SectionTitle('磁盘大小 (GB)', t),
                const SizedBox(height: 8),
                SizedBox(
                  width: 120,
                  child: _buildTextField(
                    controller: _diskCtrl,
                    label: '磁盘 (GB)',
                    hint: '40',
                    t: t,
                    inputType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 10) return '最小 10 GB';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // ── 错误提示 ────────────────────────────────
                if (_errorMsg != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: AppAccent.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppAccent.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: AppAccent.red, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMsg!,
                            style: TextStyle(
                                color: AppAccent.red, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── 说明 ────────────────────────────────────
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppAccent.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppAccent.blue.withOpacity(0.2)),
                  ),
                  child: Text(
                    Platform.isWindows
                        ? '💡 Windows 平台使用 VMware Workstation vmrest API 创建虚拟机，需要先运行 vmrest.exe 并配置凭据'
                        : '💡 Linux 平台使用 KVM/QEMU (virt-install) 创建虚拟机，需要安装 libvirt 和 virt-install',
                    style: TextStyle(color: t.text3, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _creating ? null : () => Navigator.pop(context),
          child: Text('取消', style: TextStyle(color: t.text3)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppAccent.green,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          onPressed: _creating ? null : _submit,
          icon: _creating
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.add_circle_outline, size: 14),
          label: Text(_creating ? '创建中...' : '创建虚拟机',
              style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required AppThemeData t,
    TextInputType? inputType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: t.text2,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: inputType,
          inputFormatters: inputFormatters,
          style: TextStyle(color: t.text, fontSize: 12),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: t.text3, fontSize: 11),
            filled: true,
            fillColor: t.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: t.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: t.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AppAccent.blue),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AppAccent.red),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 8),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final AppThemeData t;
  const _SectionTitle(this.title, this.t);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: AppAccent.blue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: t.text,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
