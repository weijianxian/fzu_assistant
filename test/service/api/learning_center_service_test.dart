import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/learning_center.dart';
import 'package:fzu_assistant/service/api/learning_center_service.dart';
import 'package:fzu_assistant/service/api/sso_service.dart';
import 'package:fzu_assistant/service/auth_storage.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bodies = <RequestOptions, String>{};
  int status = 200;
  Map<String, dynamic> result = {'code': '0', 'dataList': []};
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (stream != null) {
      bodies[options] = utf8.decode(
        await stream.expand((part) => part).toList(),
      );
    }
    return ResponseBody.fromString(
      jsonEncode(result),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Adapter adapter;
  late LearningCenterService api;
  late SsoService sso;
  final futureDate = learningDate(
    learningBeijingTime(DateTime.now()).add(const Duration(days: 1)),
  );
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await AuthStorage().saveCredentials('account', 'password');
    sso = SsoService();
    await sso.saveStudyToken('stored-token');
    adapter = _Adapter();
    api = LearningCenterService(
      dio: Dio(BaseOptions(baseUrl: 'https://aiot.fzu.edu.cn/api/ibs'))
        ..httpClientAdapter = adapter,
      sso: sso,
    );
  });
  tearDown(() {
    api.dio.close(force: true);
    sso.dio.close(force: true);
  });

  test(
    'seat query uses JSON, scoped token and server IDs with special seat names',
    () async {
      adapter.result = {
        'code': '0',
        'dataList': [
          {'id': 1247, 'spaceName': '796-1', 'floor': 5, 'spaceStatus': '0'},
          {'id': 1248, 'spaceName': '799-1', 'floor': 5, 'spaceStatus': 1},
        ],
      };
      final seats = await api.querySeats(
        date: futureDate,
        begin: '08:00',
        end: '10:00',
        floor: '5',
      );
      expect(seats.map((s) => s.name), ['797', '800']);
      expect(seats.first.id, '1247');
      expect(seats.first.available, isTrue);
      final request = adapter.requests.single;
      expect(request.headers['token'], 'stored-token');
      expect(request.contentType, Headers.jsonContentType);
      expect(jsonDecode(adapter.bodies[request]!), {
        'beginTime': '$futureDate 08:00',
        'endTime': '$futureDate 10:00',
        'floorLike': '5',
        'parentId': 'null',
        'region': '1',
      });
    },
  );
  test(
    'reservation uses returned spaceId, date and unprefixed times',
    () async {
      await api.reserve(
        spaceId: '1247',
        date: futureDate,
        begin: '08:00',
        end: '10:00',
      );
      expect(jsonDecode(adapter.bodies[adapter.requests.single]!), {
        'spaceId': '1247',
        'date': futureDate,
        'beginTime': '08:00',
        'endTime': '10:00',
      });
    },
  );
  test('history sends page and page size, parses sign and status', () async {
    adapter.result = {
      'code': '0',
      'dataList': [
        {
          'id': 11,
          'date': futureDate,
          'spaceName': '1',
          'auditStatus': 2,
          'sign': true,
        },
      ],
    };
    final records = await api.appointments(page: 2);
    expect(records.single.signedIn, isTrue);
    expect(
      jsonDecode(adapter.bodies[adapter.requests.single]!)['currentPage'],
      '2',
    );
  });
  test('occupied seat schedule uses the server space ID', () async {
    adapter.result = {
      'code': '0',
      'data': {
        'timeDiamondList': [
          {'timeText': '08:00–08:30', 'occupy': 1},
        ],
      },
    };
    final slots = await api.seatTimes('1247', futureDate);
    expect(slots.single.available, isFalse);
    expect(
      jsonDecode(adapter.bodies[adapter.requests.single]!)['spaceId'],
      '1247',
    );
  });
  test(
    'HTTP 500 invalidates stored token and never retries a mutation',
    () async {
      adapter.status = 500;
      await expectLater(api.cancel('11'), throwsA(isA<SsoLoginRequired>()));
      expect(adapter.requests, hasLength(1));
      expect(await sso.loadStudyToken(), isNull);
    },
  );
  test(
    'debug token overrides stored token without changing saved session',
    () async {
      adapter.status = 500;
      await expectLater(
        api.signIn('11', token: 'debug-token'),
        throwsA(isA<SsoLoginRequired>()),
      );
      expect(adapter.requests.single.headers['token'], 'debug-token');
      expect(await sso.loadStudyToken(), 'stored-token');
    },
  );
  test('business error is reported and mutations are not retried', () async {
    adapter.result = {'code': '403', 'msg': 'too fast'};
    await expectLater(api.signOut('11'), throwsException);
    expect(adapter.requests, hasLength(1));
  });
  test('invalid period fails before sending a request', () async {
    await expectLater(
      api.querySeats(
        date: futureDate,
        begin: '08:10',
        end: '09:00',
        floor: '4',
      ),
      throwsException,
    );
    expect(adapter.requests, isEmpty);
  });
}
