import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/job_fair.dart';
import 'package:fzu_assistant/service/api/job_fair_service.dart';

Map<String, dynamic> _row({String id = 'event-1', String date = '20261105'}) =>
    {
      'id': id,
      'title': ' 公司 &amp; 合作&nbsp; ',
      'place': ' 旗山校区 &lt;报告厅&gt; ',
      'start_time': date,
      'time': '14:30',
      'zphval': '3',
    };

String _response(List<Object?> rows) =>
    jsonEncode({'success': true, 'zhaopinhui_keynoteList': rows});

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bodies = <String>[];
  String body = _response([_row()]);
  int statusCode = 200;
  bool failConnection = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final bytes = requestStream == null
        ? <int>[]
        : await requestStream.expand((chunk) => chunk).toList();
    bodies.add(utf8.decode(bytes));
    if (failConnection) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    // The official endpoint may label JSON as text/html.
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
        if (statusCode == 302) 'location': ['https://other.invalid/'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Matcher _failure(JobFairFailure failure) => isA<JobFairException>().having(
  (exception) => exception.failure,
  'failure',
  failure,
);

void main() {
  late _Adapter adapter;
  late JobFairService service;
  setUp(() {
    adapter = _Adapter();
    service = JobFairService(httpClientAdapter: adapter);
  });
  tearDown(() => service.close());

  test(
    'posts the Beijing month directly with no credentials or redirects',
    () async {
      final result = await service.getMonth(JobFairMonth(2026, 11));
      expect(result.month, JobFairMonth(2026, 11));
      expect(result.events, hasLength(1));
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.toString(), JobFairService.endpoint);
      expect(request.uri.queryParameters, isEmpty);
      expect(request.contentType, Headers.formUrlEncodedContentType);
      expect(Uri.splitQueryString(adapter.bodies.single), {
        'dateday': '2026/11',
      });
      expect(request.followRedirects, isFalse);
      final headerNames = request.headers.keys.map((key) => key.toLowerCase());
      expect(headerNames, isNot(contains('cookie')));
      expect(headerNames, isNot(contains('authorization')));
      expect(result.events.single.startsAt, DateTime.utc(2026, 11, 5, 6, 30));
    },
  );

  test(
    'normalizes entities while keeping missing title and venue available',
    () async {
      var result = await service.getMonth(JobFairMonth(2026, 11));
      expect(result.events.single.title, '公司 & 合作');
      expect(result.events.single.place, '旗山校区 <报告厅>');
      adapter.body = _response([
        _row()
          ..['title'] = null
          ..['place'] = null,
      ]);
      result = await service.getMonth(JobFairMonth(2026, 11));
      expect(result.events.single.title, isEmpty);
      expect(result.events.single.place, isEmpty);
    },
  );

  test(
    'skips broken rows, filters wrong months and removes repeated entries',
    () async {
      adapter.body = _response([
        _row(),
        _row(id: 'broken', date: '20260230'),
        'not an event',
        _row(id: 'previous-month', date: '20261031'),
        _row(),
      ]);
      final result = await service.getMonth(JobFairMonth(2026, 11));
      expect(result.events.map((event) => event.id), ['event-1']);
      expect(result.skippedCount, 2);
    },
  );

  test('plain-text titles and venues retain literal angle brackets', () async {
    adapter.body = _response([
      _row()
        ..['title'] = '校园招聘 <研发专场> &amp; 秋招'
        ..['place'] = '教学楼 <A> &lt;报告厅&gt;',
    ]);
    final result = await service.getMonth(JobFairMonth(2026, 11));
    expect(result.events.single.title, '校园招聘 <研发专场> & 秋招');
    expect(result.events.single.place, '教学楼 <A> <报告厅>');
  });

  test(
    'an actual empty month succeeds but a wholly malformed month fails',
    () async {
      adapter.body = _response([]);
      final result = await service.getMonth(JobFairMonth(2026, 11));
      expect(result.events, isEmpty);
      expect(result.skippedCount, 0);
      adapter.body = _response([
        _row(date: '20261131'),
        _row()..['id'] = '\r\n',
        null,
      ]);
      await expectLater(
        service.getMonth(JobFairMonth(2026, 11)),
        throwsA(_failure(JobFairFailure.response)),
      );
    },
  );

  test(
    'valid rows outside the month cannot disguise malformed rows as empty',
    () async {
      adapter.body = _response([
        _row(id: 'previous-month', date: '20261031'),
        _row(id: 'broken-current-month', date: '20261131'),
      ]);
      await expectLater(
        service.getMonth(JobFairMonth(2026, 11)),
        throwsA(_failure(JobFairFailure.response)),
      );
    },
  );

  test(
    'non-JSON, wrong shapes and source failures remain retryable errors',
    () async {
      for (final body in [
        '<html>Maintenance</html>',
        '',
        'null',
        '[]',
        '{"success": true}',
        '{"success": true, "zhaopinhui_keynoteList": {}}',
      ]) {
        adapter.body = body;
        await expectLater(
          service.getMonth(JobFairMonth(2026, 11)),
          throwsA(_failure(JobFairFailure.response)),
          reason: body,
        );
      }
      adapter.body = '{"success": false, "zhaopinhui_keynoteList": []}';
      await expectLater(
        service.getMonth(JobFairMonth(2026, 11)),
        throwsA(_failure(JobFairFailure.unavailable)),
      );
      adapter.body = '\uFEFF${_response([_row()])}';
      final result = await service.getMonth(JobFairMonth(2026, 11));
      expect(result.events, hasLength(1));
    },
  );

  test(
    'connection failures, HTTP failures and redirects are not retried',
    () async {
      adapter.failConnection = true;
      await expectLater(
        service.getMonth(JobFairMonth(2026, 11)),
        throwsA(_failure(JobFairFailure.network)),
      );
      adapter.failConnection = false;
      for (final status in [500, 302]) {
        adapter.statusCode = status;
        await expectLater(
          service.getMonth(JobFairMonth(2026, 11)),
          throwsA(_failure(JobFairFailure.network)),
        );
      }
      expect(adapter.requests, hasLength(3));
    },
  );
}
