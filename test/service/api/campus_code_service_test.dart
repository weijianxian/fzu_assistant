import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/api/campus_code_service.dart';
import 'package:fzu_assistant/service/api/sso_service.dart';

class _Sso extends SsoService {
  String? cached = 'cached';
  int renewals = 0;
  @override
  Future<String?> loadCampusToken() async => cached;
  @override
  Future<void> clearCampusToken() async => cached = null;
  @override
  Future<String> getCampusToken() async {
    renewals++;
    return 'renewed';
  }
}

class _Adapter implements HttpClientAdapter {
  bool expired = false;
  bool offlineEnabled = true;
  bool networkError = false;
  final requests = <RequestOptions>[];
  late Map<String, dynamic> fixture;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (networkError) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    Object data;
    if (options.path.endsWith('/user')) {
      if (expired && options.headers['Synjones-Auth'] == 'bearer cached') {
        return ResponseBody.fromString(
          '{"code":401}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      data = {'name': '测试用户', 'account': '123456789'};
    } else if (options.path.endsWith('/codebarPayinfo')) {
      data = [
        {
          'account': '123456789',
          'payacc': '1234',
          'paytype': '1',
          'voucher': offlineEnabled ? 'fake-voucher' : '',
          'voucherStatus': 0,
        },
      ];
    } else if (options.path.endsWith('/batchGetBarCodeGet')) {
      data = {
        'barcode': ['12345678901234567890'],
      };
    } else if (options.path.endsWith('/offlienPar')) {
      data = {
        'offline_userdata': '80FF00AA',
        'userhashkey': fixture['encrypted'],
        'version': '3',
        'offline_effective_time': '60',
      };
    } else if (options.path.endsWith('/frontInfo')) {
      data = {
        'getFrontConfig': jsonEncode({
          'privateKey': fixture['pem'],
          'offlineCode': '1',
        }),
      };
    } else {
      throw StateError('Unexpected endpoint ${options.path}');
    }
    return ResponseBody.fromString(
      jsonEncode({'code': 200, 'data': data}),
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
  late CampusCodeService service;
  late _Adapter adapter;
  late _Sso sso;
  late Map<String, dynamic> fixture;
  setUp(() {
    fixture = jsonDecode(
      File('test/fixtures/campus_rsa.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    adapter = _Adapter()..fixture = fixture;
    sso = _Sso();
    service = CampusCodeService(
      dio: Dio()..httpClientAdapter = adapter,
      sso: sso,
    );
  });
  tearDown(() {
    service.dio.close(force: true);
    sso.dio.close(force: true);
  });
  test('RSA PKCS1 decryption accepts PKCS1 and PKCS8 PEM fixtures encrypted by .NET', () {
    for (final field in ['pem', 'pkcs8']) {
      expect(
        CampusCodeService.decryptHashKey(
          fixture['encrypted'] as String,
          fixture[field] as String,
        ),
        List.generate(16, (i) => i),
      );
    }
  });
  test('SO and SP payloads match independent .NET SHA1 vectors and retain raw bytes', () {
    Uint8List generate(bool newProtocol) => CampusCodeService.generatePayBytes(
      barcode: '12345678901234567890',
      payAccount: '1234',
      offlineData: '80ff00aa',
      hashKey: Uint8List.fromList(List.generate(16, (i) => i)),
      version: 3,
      effectiveTime: 60,
      newProtocol: newProtocol,
      now: DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
    );
    final old = generate(false);
    expect(ascii.decode(old.take(22).toList()), '12345678901234567890SO');
    expect(
      old
          .skip(22)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase(),
      '0011030000F15365013C0180FF00AA53BE8587',
    );
    expect(
      ascii.decode(generate(true)),
      '12345678901234567890SPAB0DAADxU2UBPAGA/wCqC28JhAQxMjM0hQEBSpTugQ==',
    );
  });
  test(
    'expired saved token renews through SSO; transport errors do not log out',
    () async {
      adapter.expired = true;
      final session = await service.loadSession();
      expect(session.token, 'renewed');
      expect(session.user.account, '123456789');
      expect(sso.renewals, 1);
      sso.cached = 'cached';
      adapter.networkError = true;
      await expectLater(service.loadSession(), throwsA(isA<DioException>()));
      expect(sso.cached, 'cached');
      expect(sso.renewals, 1);
    },
  );
  test('payment endpoints use exact parameter names and no auth on front configuration', () async {
    final code = await service.getPayCode('test-token');
    expect(
      ascii.decode(code.bytes.take(22).toList()),
      '12345678901234567890SP',
    );
    final offline = adapter.requests.singleWhere(
      (r) => r.path.endsWith('/offlienPar'),
    );
    expect(offline.queryParameters, {
      'synAccessSource': 'h5',
      'payacc': '1234',
      'paytype': '1',
      'voucher': 'fake-voucher',
    });
    final front = adapter.requests.singleWhere(
      (r) => r.path.endsWith('/frontInfo'),
    );
    expect(front.headers.containsKey('Synjones-Auth'), isFalse);
    expect(offline.headers['Synjones-Auth'], 'bearer test-token');
    expect(offline.headers.containsKey('cookie'), isFalse);
  });
  test('disabled offline payments still allow library user lookup', () async {
    adapter.offlineEnabled = false;
    await expectLater(
      service.getPayCode('test-token'),
      throwsA(predicate((e) => e.toString().contains('未开通离线支付权限'))),
    );
    expect((await service.getUser('test-token')).account, '123456789');
  });
}
