import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 载荷记录模型
// 记录：载荷文件名、大小、所在虚拟机信息、虚拟机内路径
// ─────────────────────────────────────────────────────────────────────────────
class PayloadRecord {
  final String id;          // UUID
  final String fileName;    // 文件名
  final int    fileSize;    // 字节数
  final String vmId;        // 虚拟机 ID（vmrest ID 或预设 ID）
  final String vmName;      // 虚拟机名称（显示用）
  final String vmIp;        // 虚拟机 IP
  final String remotePath;  // 虚拟机内路径，如 /payloads/shell.exe
  final String uploadedAt;  // ISO 8601

  const PayloadRecord({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.vmId,
    required this.vmName,
    required this.vmIp,
    required this.remotePath,
    required this.uploadedAt,
  });

  factory PayloadRecord.fromJson(Map<String, dynamic> j) => PayloadRecord(
        id:         j['id']         as String,
        fileName:   j['fileName']   as String,
        fileSize:   (j['fileSize']  as num).toInt(),
        vmId:       j['vmId']       as String,
        vmName:     j['vmName']     as String,
        vmIp:       j['vmIp']       as String,
        remotePath: j['remotePath'] as String,
        uploadedAt: j['uploadedAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id':         id,
        'fileName':   fileName,
        'fileSize':   fileSize,
        'vmId':       vmId,
        'vmName':     vmName,
        'vmIp':       vmIp,
        'remotePath': remotePath,
        'uploadedAt': uploadedAt,
      };

  /// 人类可读大小
  String get sizeLabel {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB';
    }
    return '${(fileSize / 1024 / 1024 / 1024).toStringAsFixed(2)}GB';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 载荷持久化存储服务
// ─────────────────────────────────────────────────────────────────────────────
class PayloadStore {
  static const String _key = 'payload_records';

  /// 加载所有载荷记录
  static Future<List<PayloadRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PayloadRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 保存所有载荷记录（覆盖）
  static Future<void> saveAll(List<PayloadRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(records.map((r) => r.toJson()).toList());
    await prefs.setString(_key, json);
  }

  /// 添加一条记录
  static Future<void> add(PayloadRecord record) async {
    final records = await loadAll();
    records.insert(0, record);
    await saveAll(records);
  }

  /// 删除一条记录（按 id）
  static Future<void> remove(String id) async {
    final records = await loadAll();
    records.removeWhere((r) => r.id == id);
    await saveAll(records);
  }

  /// 按虚拟机 ID 过滤
  static Future<List<PayloadRecord>> loadByVm(String vmId) async {
    final all = await loadAll();
    return all.where((r) => r.vmId == vmId).toList();
  }
}
