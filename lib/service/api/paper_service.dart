import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fzu_assistant/model/feature_access.dart';

class PaperEntry {
  const PaperEntry({required this.name, required this.isFolder});
  final String name;
  final bool isFolder;
}

class PaperDirectory {
  const PaperDirectory({required this.path, required this.entries});
  final String path;
  final List<PaperEntry> entries;
}

/// Public west2 paper APIs never use academic credentials or SSO cookies.
class PaperService {
  PaperService({required this.access, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              followRedirects: false,
            ),
          ),
      _ownsDio = dio == null;

  static const baseUrl = 'https://fzuhelper.west2.online';
  final FeatureAccess Function() access;
  final Dio _dio;
  final bool _ownsDio;

  void _checkAccess() {
    if (access() != FeatureAccess.allow) {
      throw StateError('请先在第三方服务设置中允许历年卷');
    }
  }

  /// Paths are logical paper-library paths, never URLs or filesystem paths.
  static String normalizePath(String path) {
    if (path.isEmpty) return '/';
    if (!path.startsWith('/') ||
        path.contains('\\') ||
        path.contains(RegExp(r'[\x00-\x1f\x7f]')) ||
        path.length > 4096) {
      throw const FormatException('试卷目录路径无效');
    }
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    for (final part in parts) {
      _validateName(part);
    }
    return parts.isEmpty ? '/' : '/${parts.join('/')}';
  }

  static void _validateName(String name) {
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.contains(RegExp(r'[/\\\x00-\x1f\x7f]'))) {
      throw const FormatException('试卷名称无效');
    }
    // Do not allow encoded separators or traversal to be decoded downstream.
    var decoded = name;
    for (var i = 0; i < 4; i++) {
      final next = decoded.replaceAllMapped(
        RegExp(r'%([0-9a-fA-F]{2})'),
        (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
      );
      if (next == decoded) return;
      if (next == '.' ||
          next == '..' ||
          next.contains(RegExp(r'[/\\\x00-\x1f\x7f]'))) {
        throw const FormatException('试卷名称无效');
      }
      decoded = next;
    }
    if (RegExp(r'%[0-9a-fA-F]{2}').hasMatch(decoded)) {
      throw const FormatException('试卷名称编码层级无效');
    }
  }

  static String childPath(String directory, String name) {
    _validateName(name);
    final parent = normalizePath(directory);
    return normalizePath('${parent == '/' ? '' : parent}/$name');
  }

  static String parentPath(String path) {
    final normalized = normalizePath(path);
    final last = normalized.lastIndexOf('/');
    return last <= 0 ? '/' : normalized.substring(0, last);
  }

  Future<Map<String, dynamic>> _get(
    String endpoint,
    Map<String, String> query,
  ) async {
    _checkAccess();
    final response = await _dio.get<dynamic>(
      '$baseUrl/api/v1/paper/$endpoint',
      queryParameters: query,
      options: Options(
        followRedirects: false,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    _checkAccess();
    final Object? body = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (body is! Map || body['code']?.toString() != '10000') {
      throw Exception(body is Map ? body['message'] ?? '历年卷请求失败' : '历年卷响应无效');
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) throw const FormatException('历年卷数据无效');
    return data;
  }

  Future<PaperDirectory> list(String path) async {
    final normalized = normalizePath(path);
    final data = await _get('list', {'path': normalized});
    final entries = <PaperEntry>[];
    for (final (field, folder) in [('folders', true), ('files', false)]) {
      final values = data[field];
      if (values is! List || values.length > 20000) {
        throw const FormatException('历年卷目录无效');
      }
      for (final value in values) {
        if (value is! String) throw const FormatException('试卷名称无效');
        _validateName(value);
        entries.add(PaperEntry(name: value, isFolder: folder));
      }
    }
    entries.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return PaperDirectory(
      path: normalized,
      entries: List.unmodifiable(entries),
    );
  }

  Future<Uri> download(String filepath) async {
    final normalized = normalizePath(filepath);
    if (normalized == '/') throw const FormatException('请选择试卷文件');
    final data = await _get('download', {'filepath': normalized});
    final url = data['url'];
    final uri = url is String ? Uri.tryParse(url) : null;
    if (uri == null ||
        !{'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('试卷下载地址无效');
    }
    return uri;
  }

  void close() {
    if (_ownsDio) _dio.close(force: true);
  }
}
