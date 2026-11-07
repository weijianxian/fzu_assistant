import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';

/// The attendance site's small native protocol, without a general JS bridge.
///
/// Keep an instance for the lifetime of a WebView so native permission dialogs
/// and position fixes can be shared by simultaneous page requests. `isCurrent`
/// must include the caller's document, navigation and session generations.
class CampusWebViewBridge {
  CampusWebViewBridge({GeolocatorPlatform? geolocator})
    : _geolocator = geolocator ?? GeolocatorPlatform.instance;

  static const _origin = 'https://yzsxg.fzu.edu.cn';
  static const _attendancePaths = [
    '/plug-in/livecloud/project/fzu/attn/',
    '/livecloud/project/fzu/attn/',
  ];
  static const _locationTimeout = Duration(seconds: 10);
  static const _failedLocation = {'lon': '', 'lat': '', 'address': ''};
  static final _identifier = RegExp(r'[a-zA-Z_$][a-zA-Z0-9_$]*');

  final GeolocatorPlatform _geolocator;
  final _permissionChecks = _SharedCall<LocationPermission>();
  final _permissionRequests = _SharedCall<LocationPermission>();
  final _serviceChecks = _SharedCall<bool>();
  final _positions = _SharedCall<Position>();

  /// Only the HTTPS attendance documents may use native location.
  static bool isTrustedDocument(Uri document) {
    if (document.scheme != 'https' ||
        document.host != 'yzsxg.fzu.edu.cn' ||
        document.port != 443 ||
        document.userInfo.isNotEmpty) {
      return false;
    }
    if (!_attendancePaths.any(document.path.startsWith)) return false;
    // Reject encoded separators and dot segments rather than relying on the
    // native browser and Dart to normalize an unusual pathname identically.
    try {
      return !document.pathSegments.any(
        (segment) =>
            segment == '.' ||
            segment == '..' ||
            segment.contains('/') ||
            segment.contains(r'\'),
      );
    } on FormatException {
      return false;
    }
  }

  /// Shared by the native protocol and the caller's HTML5 permission callback.
  ///
  /// A query never opens a permission dialog. The platform's standard foreground
  /// permission request is the only authorization flow; settings and background
  /// location are not requested here. A stale caller always receives false.
  Future<bool> locationPermission({
    required bool request,
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) return false;
    try {
      var permission = await _permissionChecks.run(_geolocator.checkPermission);
      if (!isCurrent()) return false;
      if (_isGranted(permission)) return true;
      if (!request || permission != LocationPermission.denied) return false;

      permission = await _permissionRequests.run(_geolocator.requestPermission);
      if (!isCurrent()) return false;
      return _isGranted(permission);
    } catch (_) {
      return false;
    }
  }

  /// Returns true for this native endpoint, including blocked/invalid requests,
  /// so the caller never launches an external app for this protocol.
  Future<bool> handle({
    required Uri request,
    required Uri document,
    required bool Function() isCurrent,
    required Future<void> Function(String) evaluateJavascript,
  }) async {
    if (request.scheme != 'kysk-fdxy-app' || request.host != 'native') {
      return false;
    }
    if (!isTrustedDocument(document) ||
        !isCurrent() ||
        request.userInfo.isNotEmpty ||
        request.hasPort ||
        (request.path.isNotEmpty && request.path != '/') ||
        request.fragment.isNotEmpty) {
      return true;
    }

    final Map<String, List<String>> parameters;
    try {
      parameters = request.queryParametersAll;
    } on FormatException {
      return true;
    }
    String? parameter(String key) {
      final values = parameters[key];
      return values?.length == 1 ? values!.single : null;
    }

    final type = parameter('type');
    final callback = parameter('function');
    if (callback == null ||
        _identifier.matchAsPrefix(callback)?.end != callback.length) {
      return true;
    }
    final permissionRequest = type == 'permission';
    final action = parameter('action');
    if (permissionRequest) {
      if (parameter('biz') != 'location' || !{'0', '1'}.contains(action)) {
        return true;
      }
    } else if (type != 'location') {
      return true;
    }

    Object payload;
    try {
      if (permissionRequest) {
        payload = await locationPermission(
          request: action == '1',
          isCurrent: isCurrent,
        );
        if (!isCurrent()) return true;
      } else {
        final enabled = await _serviceChecks.run(
          _geolocator.isLocationServiceEnabled,
        );
        if (!isCurrent()) return true;
        if (!enabled) {
          payload = _failedLocation;
        } else {
          final granted = await locationPermission(
            request: true,
            isCurrent: isCurrent,
          );
          if (!isCurrent()) return true;
          if (!granted) {
            payload = _failedLocation;
          } else {
            final position = await _positions.run(
              () => _geolocator
                  .getCurrentPosition(
                    locationSettings: const LocationSettings(
                      accuracy: LocationAccuracy.high,
                      timeLimit: _locationTimeout,
                    ),
                  )
                  .timeout(_locationTimeout),
            );
            if (!isCurrent()) return true;
            payload = _validPosition(position)
                ? {
                    'lon': position.longitude.toString(),
                    'lat': position.latitude.toString(),
                    'address': {
                      'city': '',
                      'district': '',
                      'street': '',
                      'streetNumber': '',
                    },
                  }
                : _failedLocation;
          }
        }
      }
    } catch (_) {
      if (!isCurrent()) return true;
      payload = permissionRequest ? false : _failedLocation;
    }
    if (!isCurrent()) return true;

    // The native checks above cannot make evaluateJavascript atomic with a
    // navigation. Recheck the actual document inside the injected script too.
    final script =
        '''
(() => {
  if (window.location.origin !== ${jsonEncode(_origin)} ||
      window.location.pathname !== ${jsonEncode(document.path)}) return;
  const name = ${jsonEncode(callback)};
  if (typeof window[name] === 'function') {
    window[name](${jsonEncode(payload)});
  }
})();
''';
    if (!isCurrent()) return true;
    try {
      await evaluateJavascript(script);
      if (!isCurrent()) return true;
    } catch (_) {
      // A disposed native view or a page callback error must not fall through
      // to external application launching.
    }
    return true;
  }

  static bool _isGranted(LocationPermission permission) =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;

  static bool _validPosition(Position position) =>
      position.latitude.isFinite &&
      position.longitude.isFinite &&
      position.latitude >= -90 &&
      position.latitude <= 90 &&
      position.longitude >= -180 &&
      position.longitude <= 180;
}

/// Retains only an unfinished native call; completed coordinates are not cached.
class _SharedCall<T> {
  Future<T>? _pending;

  Future<T> run(Future<T> Function() operation) {
    final pending = _pending;
    if (pending != null) return pending;
    final completer = Completer<T>();
    final future = completer.future;
    _pending = future;
    Future<T>.sync(operation).then(
      (result) {
        _pending = null;
        completer.complete(result);
      },
      onError: (Object error, StackTrace stack) {
        _pending = null;
        completer.completeError(error, stack);
      },
    );
    return future;
  }
}
