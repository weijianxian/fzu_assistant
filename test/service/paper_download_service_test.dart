import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/service/api/paper_service.dart';
import 'package:fzu_assistant/service/paper_download_service.dart';

class _Api extends PaperService {
  _Api(this.permission) : super(access: () => permission.value);

  final ValueNotifier<FeatureAccess> permission;
  final requested = Completer<void>();
  final paths = <String>[];
  Completer<Uri>? pending;
  Uri uri = Uri.parse('https://papers.example.org/dynamic.pdf?signature=fresh');

  @override
  Future<Uri> download(String filepath) async {
    paths.add(filepath);
    if (!requested.isCompleted) requested.complete();
    return pending?.future ?? Future.value(uri);
  }
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final requested = Completer<void>();
  late ResponseBody Function(RequestOptions options) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (!requested.isCompleted) requested.complete();
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

Matcher _throws(PaperDownloadFailure failure) => throwsA(
  isA<PaperDownloadException>().having(
    (error) => error.failure,
    'failure',
    failure,
  ),
);

void main() {
  late Directory base;
  late ValueNotifier<FeatureAccess> access;
  late _Api api;
  late _Adapter adapter;
  late Dio dio;
  late PaperDownloadService service;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('fzu-paper-download-test-');
    access = ValueNotifier(FeatureAccess.allow);
    api = _Api(access);
    adapter = _Adapter()
      ..respond = (_) => ResponseBody.fromBytes(
        [37, 80, 68, 70, 45],
        200,
        headers: {
          HttpHeaders.contentLengthHeader: ['5'],
        },
      );
    dio = Dio()..httpClientAdapter = adapter;
    service = PaperDownloadService(
      access: access,
      api: api,
      dio: dio,
      directory: () async => base,
    );
  });

  tearDown(() async {
    service.close();
    api.close();
    dio.close(force: true);
    access.dispose();
    await base.delete(recursive: true);
  });

  Future<List<File>> savedFiles() async => [
    await for (final entity in base.list(recursive: true))
      if (entity is File) entity,
  ];

  test(
    'tip and hide never resolve links, create files, or send downloads',
    () async {
      for (final permission in [FeatureAccess.tip, FeatureAccess.hide]) {
        access.value = permission;
        await expectLater(
          service.download(path: '/数学.pdf', name: '数学.pdf'),
          _throws(PaperDownloadFailure.accessDenied),
        );
        await expectLater(
          service.resolveUrl('/数学.pdf'),
          _throws(PaperDownloadFailure.accessDenied),
        );
      }
      expect(api.paths, isEmpty);
      expect(adapter.requests, isEmpty);
      expect(await savedFiles(), isEmpty);
    },
  );

  test('dynamic URL, isolated headers and exact filename produce a complete local file', () async {
    final progress = <PaperDownloadProgress>[];
    final result = await service.download(
      path: '/高等数学/试卷 #1.pdf',
      name: '试卷 #1.pdf',
      onProgress: progress.add,
    );
    expect(api.paths, ['/高等数学/试卷 #1.pdf']);
    expect(adapter.requests.single.uri, api.uri);
    expect(result.name, '试卷 #1.pdf');
    expect(result.bytes, 5);
    expect(await result.file.readAsBytes(), [37, 80, 68, 70, 45]);
    expect(result.file.parent.parent.path, contains('paper_downloads'));
    expect(result.file.path, endsWith('试卷 #1.pdf'));
    expect(progress.first.fraction, isNull);
    expect(progress.last.total, 5);
    expect(progress.last.fraction, 1);
    expect(await savedFiles(), hasLength(1));
    final request = adapter.requests.single;
    expect(request.followRedirects, isFalse);
    expect(request.uri.userInfo, isEmpty);
    expect(
      request.headers.keys.map((key) => key.toLowerCase()),
      isNot(anyOf(contains('cookie'), contains('authorization'))),
    );
  });

  test('repeated filenames use unique owned directories and preserve existing files', () async {
    final userFile = File('${base.path}${Platform.pathSeparator}数学.pdf');
    await userFile.writeAsString('user document');
    final first = await service.download(path: '/数学.pdf', name: '数学.pdf');
    final second = await service.download(path: '/数学.pdf', name: '数学.pdf');
    expect(first.file.path, isNot(second.file.path));
    expect(await first.file.exists(), isTrue);
    expect(await second.file.exists(), isTrue);
    expect(await userFile.readAsString(), 'user document');
    expect(api.paths, hasLength(2));
  });

  test('unknown length stays indeterminate and encoded lengths are not false totals', () async {
    for (final headers in [
      <String, List<String>>{},
      {
        HttpHeaders.contentLengthHeader: ['2'],
        HttpHeaders.contentEncodingHeader: ['gzip'],
      },
    ]) {
      adapter.respond = (_) =>
          ResponseBody.fromBytes([1, 2, 3], 200, headers: headers);
      final progress = <PaperDownloadProgress>[];
      final result = await service.download(
        path: '/unknown.bin',
        name: 'unknown.bin',
        onProgress: progress.add,
      );
      expect(result.bytes, 3);
      expect(progress.last.received, 3);
      expect(progress.every((item) => item.total == null), isTrue);
      expect(progress.every((item) => item.fraction == null), isTrue);
    }
  });

  test('invalid filesystem and traversal names never resolve links or create files', () async {
    for (final name in [
      '../outside.pdf',
      '.',
      '..',
      'a/b.pdf',
      'a\\b.pdf',
      '%2e%2e',
      '%252fsecret',
      'bad:stream.pdf',
      'bad?.pdf',
      'bad*.pdf',
      'bad|name.pdf',
      'bad<name>.pdf',
      'bad"name.pdf',
      'a\u0000.pdf',
      'a\u007f.pdf',
      'NUL.pdf',
      'NUL .pdf',
      'con',
      'LPT1.txt',
      'COM².txt',
      ' file.pdf',
      'file.pdf ',
      'file.pdf.',
      List.filled(100, '卷').join(),
    ]) {
      await expectLater(
        service.download(path: '/$name', name: name),
        _throws(PaperDownloadFailure.invalidFile),
        reason: name,
      );
    }
    await expectLater(
      service.download(path: '/real.pdf', name: 'different.pdf'),
      _throws(PaperDownloadFailure.invalidFile),
    );
    expect(api.paths, isEmpty);
    expect(adapter.requests, isEmpty);
    expect(await savedFiles(), isEmpty);
  });

  test('reserved partial-file-like names are valid without colliding with staging files', () async {
    final result = await service.download(
      path: '/download.part',
      name: 'download.part',
    );
    expect(await result.file.readAsBytes(), [37, 80, 68, 70, 45]);
    expect(await savedFiles(), hasLength(1));
  });

  test('cancel while resolving a link never starts a file request', () async {
    api.pending = Completer<Uri>();
    final token = CancelToken();
    final future = service.download(
      path: '/数学.pdf',
      name: '数学.pdf',
      cancelToken: token,
    );
    final assertion = expectLater(
      future,
      _throws(PaperDownloadFailure.cancelled),
    );
    await api.requested.future;
    token.cancel();
    await assertion;
    api.pending!.complete(api.uri);
    await Future<void>.delayed(Duration.zero);
    expect(adapter.requests, isEmpty);
    expect(await savedFiles(), isEmpty);
  });

  test(
    'consent revoked and immediately allowed cannot revive a pending link',
    () async {
      api.pending = Completer<Uri>();
      final future = service.resolveUrl('/数学.pdf');
      final assertion = expectLater(
        future,
        _throws(PaperDownloadFailure.accessDenied),
      );
      await api.requested.future;
      access.value = FeatureAccess.hide;
      access.value = FeatureAccess.allow;
      api.pending!.complete(api.uri);
      await assertion;
      expect(adapter.requests, isEmpty);
      expect(await savedFiles(), isEmpty);
      // Only a new operation after the new consent is allowed.
      expect(await service.resolveUrl('/new.pdf'), api.uri);
    },
  );

  for (final cancellation in ['user', 'consent', 'dispose']) {
    test(
      '$cancellation cancellation while the stream stalls removes partial files',
      () async {
        final controller = StreamController<Uint8List>();
        adapter.respond = (_) => ResponseBody(controller.stream, 200);
        final token = CancelToken();
        final received = Completer<void>();
        final future = service.download(
          path: '/数学.pdf',
          name: '数学.pdf',
          cancelToken: token,
          onProgress: (progress) {
            if (progress.received > 0 && !received.isCompleted) {
              received.complete();
            }
          },
        );
        final assertion = expectLater(
          future.timeout(const Duration(seconds: 3)),
          _throws(
            cancellation == 'consent'
                ? PaperDownloadFailure.accessDenied
                : PaperDownloadFailure.cancelled,
          ),
        );
        await adapter.requested.future;
        controller.add(Uint8List.fromList([1, 2, 3]));
        await received.future;
        expect(await savedFiles(), hasLength(1));
        if (cancellation == 'user') {
          token.cancel();
        } else if (cancellation == 'consent') {
          access.value = FeatureAccess.tip;
          access.value = FeatureAccess.allow;
        } else {
          service.close();
        }
        await assertion;
        expect(await savedFiles(), isEmpty);
        await controller.close();
      },
    );
  }

  test('network failure after bytes were written cleans the partial file and retry starts fresh', () async {
    final controller = StreamController<Uint8List>();
    adapter.respond = (_) => ResponseBody(controller.stream, 200);
    final received = Completer<void>();
    final future = service.download(
      path: '/数学.pdf',
      name: '数学.pdf',
      onProgress: (progress) {
        if (progress.received > 0 && !received.isCompleted) received.complete();
      },
    );
    final assertion = expectLater(future, _throws(PaperDownloadFailure.failed));
    await adapter.requested.future;
    controller.add(Uint8List.fromList([1, 2]));
    await received.future;
    controller.addError(StateError('simulated connection lost'));
    await assertion;
    await controller.close();
    expect(await savedFiles(), isEmpty);
    adapter.respond = (_) => ResponseBody.fromBytes([7, 8], 200);
    final result = await service.download(path: '/数学.pdf', name: '数学.pdf');
    expect(await result.file.readAsBytes(), [7, 8]);
    expect(api.paths, ['/数学.pdf', '/数学.pdf']);
  });

  test(
    'known-length truncation and empty downloads never become complete files',
    () async {
      for (final bytes in [
        <int>[],
        [1, 2],
      ]) {
        adapter.respond = (_) => ResponseBody.fromBytes(
          bytes,
          200,
          headers: {
            HttpHeaders.contentLengthHeader: ['5'],
          },
        );
        await expectLater(
          service.download(path: '/数学.pdf', name: '数学.pdf'),
          _throws(PaperDownloadFailure.incomplete),
        );
        expect(await savedFiles(), isEmpty);
      }
    },
  );

  test('revoking consent after the final chunk prevents publishing the downloaded file', () async {
    final future = service.download(
      path: '/数学.pdf',
      name: '数学.pdf',
      onProgress: (progress) {
        if (progress.received == 5) access.value = FeatureAccess.hide;
      },
    );
    await expectLater(future, _throws(PaperDownloadFailure.accessDenied));
    expect(await savedFiles(), isEmpty);
  });

  test('unsafe dynamic or redirect URLs never reach their target', () async {
    for (final uri in [
      Uri.parse('file:///private/secret'),
      Uri.parse('javascript:alert(1)'),
      Uri.parse('https://user:password@example.org/exam.pdf'),
    ]) {
      api.uri = uri;
      await expectLater(
        service.download(path: '/数学.pdf', name: '数学.pdf'),
        _throws(PaperDownloadFailure.invalidFile),
      );
    }
    expect(adapter.requests, isEmpty);
    api.uri = Uri.parse('https://papers.example.org/dynamic.pdf');
    adapter.respond = (_) => ResponseBody.fromString(
      '',
      302,
      headers: {
        HttpHeaders.locationHeader: ['file:///private/exam.pdf'],
      },
    );
    await expectLater(
      service.download(path: '/数学.pdf', name: '数学.pdf'),
      _throws(PaperDownloadFailure.invalidFile),
    );
    expect(adapter.requests, hasLength(1));
    expect(await savedFiles(), isEmpty);
  });

  test('HTTP redirects keep credentials isolated and use the current dynamic target', () async {
    adapter.respond = (options) => options.uri.host == 'papers.example.org'
        ? ResponseBody.fromString(
            '',
            302,
            headers: {
              HttpHeaders.locationHeader: [
                'https://cdn.example.org/current.pdf',
              ],
            },
          )
        : ResponseBody.fromBytes([9, 8, 7], 200);
    final result = await service.download(path: '/数学.pdf', name: '数学.pdf');
    expect(await result.file.readAsBytes(), [9, 8, 7]);
    expect(adapter.requests.map((request) => request.uri.host), [
      'papers.example.org',
      'cdn.example.org',
    ]);
    for (final request in adapter.requests) {
      expect(
        request.headers.keys.map((key) => key.toLowerCase()),
        isNot(anyOf(contains('cookie'), contains('authorization'))),
      );
    }
  });

  test(
    'a streaming redirect body is aborted without cancelling the next hop',
    () async {
      final cancelled = Completer<void>();
      final redirectBody = StreamController<Uint8List>(
        onCancel: () => cancelled.complete(),
      );
      final token = CancelToken();
      adapter.respond = (options) => options.uri.host == 'papers.example.org'
          ? ResponseBody(
              redirectBody.stream,
              302,
              headers: {
                HttpHeaders.locationHeader: [
                  'https://cdn.example.org/exam.pdf',
                ],
              },
            )
          : ResponseBody.fromBytes([4, 5, 6], 200);
      final result = await service.download(
        path: '/数学.pdf',
        name: '数学.pdf',
        cancelToken: token,
      );
      await cancelled.future.timeout(const Duration(seconds: 3));
      expect(redirectBody.hasListener, isFalse);
      expect(token.isCancelled, isFalse);
      expect(await result.file.readAsBytes(), [4, 5, 6]);
      expect(adapter.requests, hasLength(2));
      await redirectBody.close();
    },
  );

  test(
    'a consumer failure aborts the source and cleans the partial file',
    () async {
      final cancelled = Completer<void>();
      final controller = StreamController<Uint8List>(
        onCancel: () => cancelled.complete(),
      );
      adapter.respond = (_) => ResponseBody(controller.stream, 200);
      final token = CancelToken();
      final future = service.download(
        path: '/数学.pdf',
        name: '数学.pdf',
        cancelToken: token,
        onProgress: (progress) {
          if (progress.received > 0) {
            throw StateError('simulated consumer failure');
          }
        },
      );
      final assertion = expectLater(
        future,
        _throws(PaperDownloadFailure.failed),
      );
      await adapter.requested.future;
      controller.add(Uint8List.fromList([1, 2, 3]));
      await assertion;
      await cancelled.future.timeout(const Duration(seconds: 3));
      expect(controller.hasListener, isFalse);
      expect(token.isCancelled, isFalse);
      expect(await savedFiles(), isEmpty);
      await controller.close();
    },
  );

  test('an existing non-directory download root is preserved', () async {
    final existing = File(
      '${base.path}${Platform.pathSeparator}paper_downloads',
    );
    await existing.writeAsString('preserve');
    await expectLater(
      service.download(path: '/数学.pdf', name: '数学.pdf'),
      _throws(PaperDownloadFailure.invalidFile),
    );
    expect(await existing.readAsString(), 'preserve');
    expect(adapter.requests, isEmpty);
  });
}
