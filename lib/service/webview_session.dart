import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fzu_assistant/service/webview_environment.dart';

// Each native cookie store is shared by its WebViews. A single queue covers
// initialization and logout, so old injections cannot overtake logout cleanup.
Future<void> _cookieQueue = Future<void>.value();
final _ssoBrowsers = <Future<void> Function()>{};

/// Stop mounted SSO browsers before clearing the shared store, including
/// requests that could otherwise finish after logout and set cookies again.
void Function() registerSsoBrowser(Future<void> Function() stop) {
  _ssoBrowsers.add(stop);
  return () => _ssoBrowsers.remove(stop);
}

Future<void> serializeWebViewCookies(Future<void> Function() action) {
  final result = _cookieQueue.then((_) => action());
  _cookieQueue = result.catchError((Object _) {});
  return result;
}

Future<void> clearNativeWebViewCookies() async {
  for (final stop in _ssoBrowsers.toList()) {
    await stop();
  }
  await serializeWebViewCookies(() async {
    // Pure Dart tests and unsupported platforms have no native browser store.
    if (InAppWebViewPlatform.instance == null) return;
    await CookieManager.instance(webViewEnvironment: webViewEnvironment)
        .deleteAllCookies();
  });
}
