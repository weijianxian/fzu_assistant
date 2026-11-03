import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/service/api/paper_service.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final requested = Completer<void>();
  Map<String, dynamic> listing = {
    'basePath': '/',
    'folders': ['高等数学', '大学物理'],
    'files': ['2025 试卷.pdf', '2024 试卷.pdf'],
  };
  String downloadUrl = 'https://papers.example.org/2025.pdf?sign=example';
  Completer<void>? waiting;
  bool redirect = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (!requested.isCompleted) requested.complete();
    await waiting?.future;
    if (redirect) {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['https://other.example.org/'],
        },
      );
    }
    final data = options.uri.path.endsWith('/list')
        ? listing
        : {'url': downloadUrl};
    return ResponseBody.fromString(
      jsonEncode({'code': '10000', 'message': 'success', 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late FeatureAccess access;
  late _Adapter adapter;
  late Dio dio;
  late PaperService service;
  setUp(() {
    access = FeatureAccess.tip;
    adapter = _Adapter();
    dio = Dio()..httpClientAdapter = adapter;
    service = PaperService(access: () => access, dio: dio);
  });
  tearDown(() => dio.close(force: true));

  test('tip and hide do not send listing or download requests', () async {
    for (final state in [FeatureAccess.tip, FeatureAccess.hide]) {
      access = state;
      await expectLater(service.list('/'), throwsStateError);
      await expectLater(service.download('/file.pdf'), throwsStateError);
    }
    expect(adapter.requests, isEmpty);
  });

  test('public requests use exact path parameters, isolated headers and no redirects', () async {
    access = FeatureAccess.allow;
    final listing = await service.list('//大学物理//');
    expect(listing.path, '/大学物理');
    expect(listing.entries.where((entry) => entry.isFolder), hasLength(2));
    expect(listing.entries.last.name, '2025 试卷.pdf');
    final download = await service.download('/大学物理/2025 试卷.pdf');
    expect(download.toString(), adapter.downloadUrl);
    expect(adapter.requests[0].queryParameters, {'path': '/大学物理'});
    expect(adapter.requests[1].queryParameters, {
      'filepath': '/大学物理/2025 试卷.pdf',
    });
    for (final request in adapter.requests) {
      expect(request.uri.host, 'fzuhelper.west2.online');
      expect(request.followRedirects, isFalse);
      expect(
        request.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('cookie')),
      );
      expect(
        request.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('authorization')),
      );
    }
  });

  test('revoking consent discards an already pending response', () async {
    access = FeatureAccess.allow;
    adapter.waiting = Completer<void>();
    final result = service.list('/');
    final assertion = expectLater(result, throwsStateError);
    await adapter.requested.future;
    expect(adapter.requests, hasLength(1));
    access = FeatureAccess.hide;
    adapter.waiting!.complete();
    await assertion;
  });

  test('malformed paths, traversal and unsafe server names never become navigation targets', () async {
    access = FeatureAccess.allow;
    for (final path in [
      '/../private',
      '/x/./file',
      '/x\\file',
      '/%2e%2e/file',
      '/x/%252e%252e',
      '/x/%2fetc',
      'https://evil.example/file',
    ]) {
      await expectLater(
        service.list(path),
        throwsFormatException,
        reason: path,
      );
    }
    expect(adapter.requests, isEmpty);
    for (final name in ['..', '.', '/etc', '%2e%2e', 'a\\b']) {
      adapter.listing = {
        'folders': [name],
        'files': <String>[],
      };
      await expectLater(service.list('/'), throwsFormatException, reason: name);
    }
    expect(PaperService.childPath('/', '试卷 #1.pdf'), '/试卷 #1.pdf');
    expect(PaperService.parentPath('/大一/试卷'), '/大一');
  });

  test(
    'download validates URL scheme and rejects redirected API responses',
    () async {
      access = FeatureAccess.allow;
      for (final url in [
        'javascript:alert(1)',
        'file:///C:/private',
        '//evil.example/file',
        'https://user:secret@example.org/file',
      ]) {
        adapter.downloadUrl = url;
        await expectLater(service.download('/test.pdf'), throwsFormatException);
      }
      adapter.redirect = true;
      await expectLater(service.list('/'), throwsA(isA<DioException>()));
      expect(adapter.requests.last.followRedirects, isFalse);
    },
  );
}
