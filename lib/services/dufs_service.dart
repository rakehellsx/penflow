import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

// ─────────────────────────────────────────────────────────────────────────────
// dufs 文件条目模型
// ─────────────────────────────────────────────────────────────────────────────
class DufsEntry {
  final String name;
  final bool   isDir;
  final int    size;       // bytes，目录为 0
  final String mtime;     // ISO 8601

  const DufsEntry({
    required this.name,
    required this.isDir,
    required this.size,
    required this.mtime,
  });

  factory DufsEntry.fromJson(Map<String, dynamic> j) => DufsEntry(
        name:  j['name']  as String,
        isDir: j['is_dir'] as bool? ?? false,
        size:  (j['size'] as num?)?.toInt() ?? 0,
        mtime: j['mtime'] as String? ?? '',
      );

  /// 人类可读大小
  String get sizeLabel {
    if (isDir) return '—';
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / 1024 / 1024).toStringAsFixed(1)}MB';
    }
    return '${(size / 1024 / 1024 / 1024).toStringAsFixed(2)}GB';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// dufs API 服务
// dufs 默认端口 5000，WebDAV + 自定义 JSON API
// ─────────────────────────────────────────────────────────────────────────────
class DufsService {
  final String baseUrl;   // e.g. http://192.168.1.101:5000
  final String? username;
  final String? password;

  DufsService({
    required this.baseUrl,
    this.username,
    this.password,
  });

  Map<String, String> get _authHeaders {
    if (username != null && username!.isNotEmpty) {
      final creds = base64Encode(utf8.encode('$username:$password'));
      return {'Authorization': 'Basic $creds'};
    }
    return {};
  }

  // ── 列出目录 ────────────────────────────────────────────────────────────────
  /// 返回 [path] 目录下的文件/目录列表
  /// dufs JSON API: GET /<path>?json
  Future<List<DufsEntry>> listDir(String path) async {
    final url = Uri.parse('$baseUrl/${_encodePath(path)}?json');
    final resp = await http.get(url, headers: _authHeaders)
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('listDir failed: ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final paths = data['paths'] as List<dynamic>? ?? [];
    return paths
        .map((e) => DufsEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── 上传文件 ────────────────────────────────────────────────────────────────
  /// 上传 [bytes] 到 [remotePath]（包含文件名）
  /// dufs: PUT /<path>
  Future<void> upload({
    required String remotePath,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    final url = Uri.parse('$baseUrl/${_encodePath(remotePath)}');
    final request = http.Request('PUT', url);
    request.headers.addAll(_authHeaders);
    request.bodyBytes = bytes;
    final streamed = await request.send()
        .timeout(const Duration(seconds: 120));
    if (streamed.statusCode != 200 && streamed.statusCode != 201) {
      throw Exception('upload failed: ${streamed.statusCode}');
    }
  }

  // ── 下载文件 ────────────────────────────────────────────────────────────────
  /// 下载 [remotePath] 返回字节流
  Future<Uint8List> download(String remotePath) async {
    final url = Uri.parse('$baseUrl/${_encodePath(remotePath)}');
    final resp = await http.get(url, headers: _authHeaders)
        .timeout(const Duration(seconds: 120));
    if (resp.statusCode != 200) {
      throw Exception('download failed: ${resp.statusCode}');
    }
    return resp.bodyBytes;
  }

  // ── 删除文件/目录 ────────────────────────────────────────────────────────────
  /// dufs: DELETE /<path>
  Future<void> delete(String remotePath) async {
    final url = Uri.parse('$baseUrl/${_encodePath(remotePath)}');
    final resp = await http.delete(url, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('delete failed: ${resp.statusCode}');
    }
  }

  // ── 创建目录 ────────────────────────────────────────────────────────────────
  /// dufs: MKCOL /<path>/
  Future<void> mkdir(String remotePath) async {
    final url = Uri.parse('$baseUrl/${_encodePath(remotePath)}/');
    final request = http.Request('MKCOL', url);
    request.headers.addAll(_authHeaders);
    final streamed = await request.send()
        .timeout(const Duration(seconds: 10));
    if (streamed.statusCode != 200 &&
        streamed.statusCode != 201 &&
        streamed.statusCode != 405) {
      throw Exception('mkdir failed: ${streamed.statusCode}');
    }
  }

  // ── 重命名/移动 ─────────────────────────────────────────────────────────────
  /// dufs: MOVE /<src> Destination: /<dst>
  Future<void> move(String srcPath, String dstPath) async {
    final url = Uri.parse('$baseUrl/${_encodePath(srcPath)}');
    final request = http.Request('MOVE', url);
    request.headers.addAll(_authHeaders);
    request.headers['Destination'] =
        '$baseUrl/${_encodePath(dstPath)}';
    final streamed = await request.send()
        .timeout(const Duration(seconds: 30));
    if (streamed.statusCode != 200 &&
        streamed.statusCode != 201 &&
        streamed.statusCode != 204) {
      throw Exception('move failed: ${streamed.statusCode}');
    }
  }

  // ── 检查连通性 ──────────────────────────────────────────────────────────────
  Future<bool> ping() async {
    try {
      final url = Uri.parse('$baseUrl/?json');
      final resp = await http.get(url, headers: _authHeaders)
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── 工具方法 ────────────────────────────────────────────────────────────────
  String _encodePath(String path) {
    // 去掉开头的 /，然后对每段 URL 编码（保留 /）
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return clean.split('/').map(Uri.encodeComponent).join('/');
  }

  /// 从 VM IP 和端口构造 DufsService
  factory DufsService.fromVm({
    required String vmIp,
    int port = 5000,
    String? username,
    String? password,
  }) =>
      DufsService(
        baseUrl: 'http://$vmIp:$port',
        username: username,
        password: password,
      );
}
