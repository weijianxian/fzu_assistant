import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/webview_campus_bridge.dart';
import 'package:geolocator/geolocator.dart';

final _document = Uri.parse(
  'https://yzsxg.fzu.edu.cn/plug-in/livecloud/project/fzu/attn/index.html',
);
const _emptyLocation = {'lon': '', 'lat': '', 'address': ''};

void main() {
  late _LocationPlatform platform;
  late CampusWebViewBridge bridge;
  late List<String> scripts;
  var current = true;

  setUp(() {
    platform = _LocationPlatform();
    bridge = CampusWebViewBridge(geolocator: platform);
    scripts = [];
    current = true;
  });

  Future<bool> handle({
    String type = 'location',
    String? action,
    String? callback,
    Uri? request,
    Uri? document,
  }) => bridge.handle(
    request:
        request ?? _request(type: type, action: action, callback: callback),
    document: document ?? _document,
    isCurrent: () => current,
    evaluateJavascript: (script) async => scripts.add(script),
  );

  test('only attendance HTTPS documents on the default port are trusted', () {
    for (final address in [
      _document.toString(),
      'https://yzsxg.fzu.edu.cn:443/livecloud/project/fzu/attn/page',
      'https://yzsxg.fzu.edu.cn/livecloud/project/fzu/attn/?mapType=amap#/home',
    ]) {
      expect(CampusWebViewBridge.isTrustedDocument(Uri.parse(address)), isTrue);
    }
    for (final address in [
      'http://yzsxg.fzu.edu.cn/plug-in/livecloud/project/fzu/attn/index.html',
      'https://yzsxg.fzu.edu.cn:8443/plug-in/livecloud/project/fzu/attn/',
      'https://yzsxg.fzu.edu.cn.evil.example/plug-in/livecloud/project/fzu/attn/',
      'https://evil.example/plug-in/livecloud/project/fzu/attn/',
      'https://user@yzsxg.fzu.edu.cn/plug-in/livecloud/project/fzu/attn/',
      'https://yzsxg.fzu.edu.cn/other/',
      'https://yzsxg.fzu.edu.cn/plug-in/livecloud/project/fzu/attn',
      'https://yzsxg.fzu.edu.cn/plug-in/livecloud/project/fzu/attn-other/',
      'https://yzsxg.fzu.edu.cn/plug-in/livecloud/project/fzu/attn/../other/',
      'https://yzsxg.fzu.edu.cn/plug-in/livecloud/project/fzu/attn/%2Fother',
      'https://yzsxg.fzu.edu.cn/plug-in/livecloud/project/fzu/attn/%5Cother',
      'file:///plug-in/livecloud/project/fzu/attn/',
      'about:blank',
    ]) {
      expect(
        CampusWebViewBridge.isTrustedDocument(Uri.parse(address)),
        isFalse,
        reason: address,
      );
    }
  });

  test('untrusted documents consume the native endpoint without accessing location', () async {
    for (final document in [
      Uri.parse('https://evil.example/'),
      Uri.parse('https://yzsxg.fzu.edu.cn/other/'),
      Uri.parse('http://yzsxg.fzu.edu.cn/livecloud/project/fzu/attn/'),
    ]) {
      expect(await handle(document: document), isTrue);
    }
    expect(platform.calls, isEmpty);
    expect(scripts, isEmpty);
  });

  test('other schemes and hosts remain outside this bridge', () async {
    for (final uri in [
      'https://yzsxg.fzu.edu.cn/',
      'kysk-fdxy-app://other?type=location&function=callback',
      'other-app://native?type=location&function=callback',
    ]) {
      expect(await handle(request: Uri.parse(uri)), isFalse);
    }
    expect(platform.calls, isEmpty);
    expect(scripts, isEmpty);
  });

  test('malformed and unsupported native requests are consumed without authorization', () async {
    for (final uri in [
      'kysk-fdxy-app://native?type=scan&function=callback',
      'kysk-fdxy-app://native?type=location',
      'kysk-fdxy-app://native?type=location&function=',
      'kysk-fdxy-app://native?type=location&type=permission&function=callback',
      'kysk-fdxy-app://native?type=location&function=one&function=two',
      'kysk-fdxy-app://native?type=permission&biz=camera&action=1&function=callback',
      'kysk-fdxy-app://native?type=permission&biz=location&action=2&function=callback',
      'kysk-fdxy-app://native/other?type=location&function=callback',
      'kysk-fdxy-app://native:123?type=location&function=callback',
      'kysk-fdxy-app://user@native?type=location&function=callback',
    ]) {
      expect(await handle(request: Uri.parse(uri)), isTrue);
    }
    expect(platform.calls, isEmpty);
    expect(scripts, isEmpty);
  });

  test(
    'callback names must be whole identifiers, never executable fragments',
    () async {
      for (final callback in [
        'callback);fetch("https://evil.example")//',
        'window.callback',
        "callback'](1);//",
        'callback\n',
        'callback\u2028',
        '0callback',
        'with space',
      ]) {
        expect(await handle(callback: callback), isTrue);
      }
      expect(platform.calls, isEmpty);
      expect(scripts, isEmpty);
      await handle(type: 'permission', action: '0', callback: r'$callback_1');
      expect(_payload(scripts.single), isFalse);
      expect(scripts.single, contains(r'const name = "$callback_1";'));
    },
  );

  for (final permission in LocationPermission.values) {
    test('action=0 only checks permission ($permission)', () async {
      platform.permission = permission;
      expect(await handle(type: 'permission', action: '0'), isTrue);
      expect(
        _payload(scripts.single),
        permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always,
      );
      expect(platform.calls, ['check']);
    });
  }

  test(
    'action=1 requests foreground permission and reports the boolean result',
    () async {
      platform.permission = LocationPermission.denied;
      platform.requestedPermission = LocationPermission.whileInUse;
      await handle(type: 'permission', action: '1');
      expect(platform.calls, ['check', 'request']);
      expect(_payload(scripts.single), isTrue);
    },
  );

  test(
    'permanently denied permission does not reopen a prompt or settings',
    () async {
      platform.permission = LocationPermission.deniedForever;
      await handle(type: 'permission', action: '1');
      expect(platform.calls, ['check']);
      expect(_payload(scripts.single), isFalse);
    },
  );

  test(
    'successful location returns current coordinates and the FUU address shape',
    () async {
      platform.permission = LocationPermission.whileInUse;
      platform.position = _position(latitude: 26.057, longitude: 119.196);
      await handle();
      expect(_payload(scripts.single), {
        'lon': '119.196',
        'lat': '26.057',
        'address': {
          'city': '',
          'district': '',
          'street': '',
          'streetNumber': '',
        },
      });
      expect(platform.calls, ['enabled', 'check', 'position']);
      expect(platform.settings?.accuracy, LocationAccuracy.high);
      expect(platform.settings?.timeLimit, const Duration(seconds: 10));
    },
  );

  test(
    'denial returns empty coordinates without fetching a position',
    () async {
      platform.permission = LocationPermission.denied;
      platform.requestedPermission = LocationPermission.denied;
      await handle();
      expect(platform.calls, ['enabled', 'check', 'request']);
      expect(_payload(scripts.single), _emptyLocation);
    },
  );

  test(
    'disabled location returns empty coordinates without requesting permission',
    () async {
      platform.enabled = false;
      await handle();
      expect(platform.calls, ['enabled']);
      expect(_payload(scripts.single), _emptyLocation);
    },
  );

  for (final stage in ['enabled', 'check', 'request', 'position']) {
    test(
      'platform failure at $stage follows the FUU failure contract',
      () async {
        platform.failure = stage;
        if (stage == 'position') {
          platform.permission = LocationPermission.whileInUse;
        }
        await handle();
        expect(_payload(scripts.single), _emptyLocation);
        expect(platform.calls, isNot(contains('last-known')));
      },
    );
  }

  test(
    'public HTML5 permission requests share the native protocol authorization',
    () async {
      platform.permissionResult = Completer<LocationPermission>();
      final html5 = bridge.locationPermission(
        request: true,
        isCurrent: () => current,
      );
      final native = handle(type: 'permission', action: '1');
      final location = handle();
      await _flush();
      expect(platform.calls.where((call) => call == 'request'), hasLength(1));
      expect(platform.calls, isNot(contains('position')));
      platform.permissionResult!.complete(LocationPermission.whileInUse);
      expect(await html5, isTrue);
      await Future.wait([native, location]);
      expect(platform.calls.where((call) => call == 'request'), hasLength(1));
      expect(platform.calls.where((call) => call == 'position'), hasLength(1));
      expect(scripts.map(_payload), contains(true));
      expect(scripts.map(_payload).whereType<Map>(), hasLength(1));
    },
  );

  test('concurrent fixes are shared but subsequent requests obtain new coordinates', () async {
    platform.permission = LocationPermission.whileInUse;
    platform.positionResult = Completer<Position>();
    final first = handle();
    final second = handle(callback: 'anotherCallback');
    await _flush();
    expect(platform.calls.where((call) => call == 'position'), hasLength(1));
    platform.positionResult!.complete(_position(latitude: 26, longitude: 119));
    await Future.wait([first, second]);
    expect(scripts, hasLength(2));
    expect(
      scripts.map(_payload).toList(),
      everyElement(containsPair('lat', '26.0')),
    );

    platform.positionResult = null;
    platform.position = _position(latitude: 27, longitude: 120);
    await handle();
    expect(platform.calls.where((call) => call == 'position'), hasLength(2));
    expect(_payload(scripts.last), containsPair('lat', '27.0'));
    expect(platform.calls, isNot(contains('last-known')));
  });

  testWidgets('a fix times out after ten seconds and ignores a late position', (
    tester,
  ) async {
    platform.permission = LocationPermission.whileInUse;
    platform.positionResult = Completer<Position>();
    final pending = handle();
    await tester.pump();
    expect(platform.calls, contains('position'));
    await tester.pump(const Duration(seconds: 10));
    expect(await pending, isTrue);
    expect(_payload(scripts.single), _emptyLocation);
    platform.positionResult!.complete(_position());
    await tester.pump();
    expect(scripts, hasLength(1));
    expect(platform.calls, isNot(contains('last-known')));
  });

  test(
    'stale callers cannot begin either native protocol or HTML5 authorization',
    () async {
      current = false;
      expect(await handle(), isTrue);
      expect(
        await bridge.locationPermission(
          request: true,
          isCurrent: () => current,
        ),
        isFalse,
      );
      expect(platform.calls, isEmpty);
      expect(scripts, isEmpty);
    },
  );

  for (final stage in ['enabled', 'check', 'request', 'position']) {
    test(
      'navigation during $stage stops every subsequent operation and callback',
      () async {
        platform.enabledResult = stage == 'enabled' ? Completer<bool>() : null;
        platform.checkResult = stage == 'check'
            ? Completer<LocationPermission>()
            : null;
        platform.permissionResult = stage == 'request'
            ? Completer<LocationPermission>()
            : null;
        platform.positionResult = stage == 'position'
            ? Completer<Position>()
            : null;
        if (stage == 'position') {
          platform.permission = LocationPermission.whileInUse;
        }
        final pending = handle();
        await _flush();
        final before = List<String>.from(platform.calls);
        current = false;
        platform.enabledResult?.complete(true);
        platform.checkResult?.complete(LocationPermission.denied);
        platform.permissionResult?.complete(LocationPermission.whileInUse);
        platform.positionResult?.complete(_position());
        expect(await pending, isTrue);
        expect(platform.calls, before);
        expect(scripts, isEmpty);
      },
    );
  }

  test(
    'a stale participant does not suppress an active caller sharing a fix',
    () async {
      platform.permission = LocationPermission.whileInUse;
      platform.positionResult = Completer<Position>();
      final stale = handle();
      final active = bridge.handle(
        request: _request(),
        document: _document,
        isCurrent: () => true,
        evaluateJavascript: (script) async => scripts.add(script),
      );
      await _flush();
      current = false;
      platform.positionResult!.complete(_position());
      await Future.wait([stale, active]);
      expect(scripts, hasLength(1));
      expect(platform.calls.where((call) => call == 'position'), hasLength(1));
    },
  );

  test(
    'the injected callback rechecks the exact origin and pathname',
    () async {
      final document = Uri.parse(
        'https://yzsxg.fzu.edu.cn:443/livecloud/project/fzu/attn/page?secret=ignored',
      );
      platform.permission = LocationPermission.whileInUse;
      await handle(document: document);
      final script = scripts.single;
      final guard = script.indexOf('window.location.origin');
      final callback = script.indexOf('window[name](');
      expect(guard, greaterThanOrEqualTo(0));
      expect(guard, lessThan(callback));
      expect(script, contains('!== "https://yzsxg.fzu.edu.cn"'));
      expect(
        script,
        contains('pathname !== "/livecloud/project/fzu/attn/page"'),
      );
      expect(script, isNot(contains('secret')));
      expect(script, contains('const name = "nativeCallJsLocationFunKysk";'));
    },
  );

  test(
    'an unavailable callback never falls through to an external app',
    () async {
      platform.permission = LocationPermission.whileInUse;
      expect(
        await bridge.handle(
          request: _request(),
          document: _document,
          isCurrent: () => true,
          evaluateJavascript: (_) async => throw StateError('view disposed'),
        ),
        isTrue,
      );
    },
  );

  for (final latitude in [double.nan, double.infinity, 91.0]) {
    test(
      'invalid platform latitude $latitude is returned as a failed fix',
      () async {
        platform.permission = LocationPermission.whileInUse;
        platform.position = _position(latitude: latitude);
        await handle();
        expect(_payload(scripts.single), _emptyLocation);
      },
    );
  }
}

Uri _request({String type = 'location', String? action, String? callback}) =>
    Uri(
      scheme: 'kysk-fdxy-app',
      host: 'native',
      queryParameters: {
        'type': type,
        if (type == 'permission') 'biz': 'location',
        'action': ?action,
        'function':
            callback ??
            (type == 'permission'
                ? 'nativePermissionFunKysk'
                : 'nativeCallJsLocationFunKysk'),
      },
    );

Object? _payload(String script) => jsonDecode(
  RegExp(r'window\[name\]\((.+)\);').firstMatch(script)!.group(1)!,
);

Future<void> _flush() => Future<void>.delayed(Duration.zero);

Position _position({double latitude = 26.057, double longitude = 119.196}) =>
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.utc(2026, 11, 7),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class _LocationPlatform extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.denied;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  bool enabled = true;
  Position position = _position();
  String? failure;
  final calls = <String>[];
  LocationSettings? settings;
  Completer<bool>? enabledResult;
  Completer<LocationPermission>? checkResult;
  Completer<LocationPermission>? permissionResult;
  Completer<Position>? positionResult;

  Future<T> _read<T>(String call, T fallback, Future<T>? pending) {
    calls.add(call);
    if (failure == call) {
      return Future<T>.error(StateError('$call unavailable'));
    }
    return pending ?? Future<T>.value(fallback);
  }

  @override
  Future<LocationPermission> checkPermission() =>
      _read('check', permission, checkResult?.future);

  @override
  Future<LocationPermission> requestPermission() =>
      _read('request', requestedPermission, permissionResult?.future).then((
        result,
      ) {
        permission = result;
        return result;
      });

  @override
  Future<bool> isLocationServiceEnabled() =>
      _read('enabled', enabled, enabledResult?.future);

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    settings = locationSettings;
    return _read('position', position, positionResult?.future);
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) =>
      _read<Position?>('last-known', position, null);
}
