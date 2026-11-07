import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' hide Cookie;
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/constants/site_injections.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/sso_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/webview_environment.dart';
import 'package:fzu_assistant/service/webview_campus_bridge.dart';
import 'package:fzu_assistant/service/webview_session.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';

class WebViewPage extends HookWidget {
  final String url;
  final String? title;
  final bool injectCookies;
  final bool injectSsoCookies;
  const WebViewPage({
    super.key,
    required this.url,
    this.title,
    this.injectCookies = true,
    this.injectSsoCookies = false,
  });

  static String _ensureUserId(String url) {
    final uri = Uri.parse(url);
    if (uri.host != 'jwcjwxt2.fzu.edu.cn' ||
        uri.queryParameters.containsKey('id')) {
      return url;
    }
    final id = ApiClient.instance.userId;
    return id == null
        ? url
        : uri
              .replace(queryParameters: {...uri.queryParameters, 'id': id})
              .toString();
  }

  static String _jsStringLiteral(String s) =>
      "'${s.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n').replaceAll('\r', '\\r')}'";

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sso = SsoService.instance;
    final revision = useValueListenable(sso.sessionRevision);
    final retry = useState(0);
    final controller = useRef<InAppWebViewController?>(null);
    final navigationRevision = useRef(0);
    final campusBridge = useMemoized(CampusWebViewBridge.new);
    final sourceUrl = useMemoized(
      () => injectSsoCookies ? url : _ensureUserId(url),
      [url, injectSsoCookies],
    );
    final currentUrl = useState(sourceUrl);
    final pageTitle = useState(title ?? '');
    final progress = useState(0.0);
    final needsLogin = useState(false);
    final error = useState<String?>(null);
    final prepared = useState<Object?>(null);
    final preparationKey = (
      sourceUrl,
      injectCookies,
      injectSsoCookies,
      injectSsoCookies ? revision : 0,
      retry.value,
    );
    bool currentBrowser(InAppWebViewController web) =>
        context.mounted &&
        controller.value?.platform == web.platform &&
        (!injectSsoCookies || sso.sessionRevision.value == preparationKey.$4);
    Future<Uri?> browserDocument(InAppWebViewController web) async {
      if (!currentBrowser(web)) return null;
      try {
        return await web.getUrl();
      } catch (_) {
        return null;
      }
    }

    useEffect(() {
      if (!injectSsoCookies) return null;
      return registerSsoBrowser(() async {
        if (context.mounted) {
          prepared.value = null;
          needsLogin.value = true;
        }
        try {
          await controller.value?.stopLoading();
        } catch (_) {
          // An already-disposed browser has no remaining request to stop.
        }
        controller.value = null;
      });
    }, [injectSsoCookies]);

    useEffect(() {
      var disposed = false;
      final sessionRevision = sso.sessionRevision.value;
      bool current() =>
          !disposed &&
          context.mounted &&
          (!injectSsoCookies || sessionRevision == sso.sessionRevision.value);
      Future<void> prepare() async {
        try {
          try {
            await controller.value?.stopLoading();
          } catch (_) {
            // A previous WebView may already have been disposed by the key
            // change. Cookie cleanup must still run after logout.
          }
          controller.value = null;
          if (!current()) return;
          needsLogin.value = false;
          error.value = null;
          progress.value = 0;
          currentUrl.value = sourceUrl;
          if (injectSsoCookies || injectCookies) {
            // Missing SSO credentials show the app login prompt before any
            // native browser object is created (including in widget tests).
            final ssoCookie = injectSsoCookies
                ? await sso.loadWebViewCookie()
                : null;
            if (!current()) return;
            final manager = CookieManager.instance(
              webViewEnvironment: webViewEnvironment,
            );
            await serializeWebViewCookies(() async {
              if (!current()) return;
              await manager.deleteAllCookies();
              if (!current()) return;
              if (injectSsoCookies) {
                if (!current()) return;
                // Omitting domain keeps this a secure host-only SSO ticket.
                final saved = await manager.setCookie(
                  url: WebUri(SsoService.loginUrl),
                  name: 'SOURCEID_TGC',
                  value: ssoCookie!,
                  path: '/',
                  isSecure: true,
                  isHttpOnly: true,
                  sameSite: HTTPCookieSameSitePolicy.NONE,
                );
                if (!saved) {
                  throw StateError('无法设置统一认证登录状态，请重试');
                }
                final browserCookies = await manager.getCookies(
                  url: WebUri(SsoService.loginUrl),
                );
                if (!browserCookies.any(
                  (cookie) =>
                      cookie.name == 'SOURCEID_TGC' &&
                      cookie.value == ssoCookie,
                )) {
                  throw StateError('无法设置统一认证登录状态，请重试');
                }
                if (!current()) {
                  await manager.deleteCookie(
                    url: WebUri(SsoService.loginUrl),
                    name: 'SOURCEID_TGC',
                  );
                }
              } else {
                final now = DateTime.now();
                for (final domain in [
                  'https://jwcjwxt2.fzu.edu.cn',
                  'https://jwch.fzu.edu.cn',
                ]) {
                  final cookies = await ApiClient.instance.cookieJar
                      .loadForRequest(Uri.parse(domain));
                  for (final cookie in cookies) {
                    if (!current()) return;
                    if ((cookie.maxAge != null && cookie.maxAge! <= 0) ||
                        (cookie.expires != null &&
                            !cookie.expires!.isAfter(now))) {
                      continue;
                    }
                    await manager.setCookie(
                      url: WebUri(domain),
                      name: cookie.name,
                      value: cookie.value,
                      path: cookie.path ?? '/',
                      domain: cookie.domain,
                      expiresDate: cookie.expires?.millisecondsSinceEpoch,
                      maxAge: cookie.maxAge,
                      isSecure: cookie.secure,
                      isHttpOnly: cookie.httpOnly,
                    );
                  }
                }
              }
            });
          }
          if (current()) prepared.value = preparationKey;
        } on SsoLoginRequired {
          if (current()) needsLogin.value = true;
        } catch (failure) {
          if (current()) error.value = failure.toString();
        }
      }

      scheduleMicrotask(prepare);
      return () {
        disposed = true;
      };
    }, [preparationKey]);

    Future<void> injectForDomain(InAppWebViewController web, Uri? uri) async {
      if (!context.mounted ||
          !AppSettingsProvider.of(context).siteInjectionEnabled.value) {
        return;
      }
      for (final injection in kSiteInjections) {
        if (RegExp(injection.pattern).hasMatch(uri?.toString() ?? '')) {
          if (injection.css != null) {
            await web.evaluateJavascript(
              source:
                  'var s=document.createElement("style");s.textContent=${_jsStringLiteral(injection.css!)};document.head.appendChild(s);',
            );
          }
          if (injection.js != null) {
            await web.evaluateJavascript(source: injection.js!);
          }
        }
      }
    }

    Widget body;
    if (needsLogin.value) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.ssoLoginDescription),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final beforeLogin = sso.sessionRevision.value;
                  final signedIn = await context.pushNamed(
                    AppRoutes.campusServicesLogin,
                  );
                  if (context.mounted &&
                      signedIn == true &&
                      beforeLogin == sso.sessionRevision.value) {
                    retry.value++;
                  }
                },
                icon: const Icon(Icons.login),
                label: Text(l10n.ssoLogin),
              ),
            ],
          ),
        ),
      );
    } else if (error.value != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.loadingFailed(error.value!)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => retry.value++,
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    } else if (prepared.value != preparationKey) {
      body = const Center(child: CircularProgressIndicator.adaptive());
    } else {
      body = Column(
        children: [
          if (progress.value < 1)
            LinearProgressIndicator(value: progress.value),
          Expanded(
            child: InAppWebView(
              key: ValueKey(preparationKey),
              webViewEnvironment: webViewEnvironment,
              initialUrlRequest: URLRequest(url: WebUri(sourceUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useHybridComposition: !Platform.isAndroid,
                algorithmicDarkeningAllowed: true,
                useShouldOverrideUrlLoading: true,
                userAgent: injectSsoCookies && !Platform.isAndroid
                    ? SsoService.userAgent
                    : null,
                applicationNameForUserAgent:
                    injectSsoCookies && Platform.isAndroid
                    ? SsoService.appUserAgent
                    : null,
                thirdPartyCookiesEnabled: true,
                geolocationEnabled: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              ),
              onWebViewCreated: (web) => controller.value = web,
              shouldOverrideUrlLoading: (web, action) async {
                if (!currentBrowser(web)) return NavigationActionPolicy.CANCEL;
                final uri = action.request.url;
                if (uri?.scheme == 'kysk-fdxy-app') {
                  if (!injectSsoCookies || !action.isForMainFrame) {
                    return NavigationActionPolicy.CANCEL;
                  }
                  final navigation = navigationRevision.value;
                  final document = await browserDocument(web);
                  bool current() =>
                      currentBrowser(web) &&
                      navigationRevision.value == navigation;
                  if (document != null && current()) {
                    await campusBridge.handle(
                      request: uri!,
                      document: document,
                      isCurrent: current,
                      evaluateJavascript: (source) async {
                        if (current()) {
                          await web.evaluateJavascript(source: source);
                        }
                      },
                    );
                  }
                  return NavigationActionPolicy.CANCEL;
                }
                if (uri == null ||
                    {
                      'http',
                      'https',
                      'about',
                      'data',
                      'blob',
                    }.contains(uri.scheme)) {
                  return NavigationActionPolicy.ALLOW;
                }
                // File inputs retain the plugin's native chooser. App schemes
                // require a user gesture, rather than an automatic page redirect.
                if (action.isForMainFrame && action.hasGesture == true) {
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                }
                return NavigationActionPolicy.CANCEL;
              },
              onGeolocationPermissionsShowPrompt: (web, origin) async {
                final navigation = navigationRevision.value;
                bool current() =>
                    currentBrowser(web) &&
                    navigationRevision.value == navigation;
                final document = await browserDocument(web);
                final requestingOrigin = Uri.tryParse(origin);
                final trusted =
                    injectSsoCookies &&
                    current() &&
                    document != null &&
                    CampusWebViewBridge.isTrustedDocument(document) &&
                    requestingOrigin?.scheme == 'https' &&
                    requestingOrigin?.host == document.host &&
                    requestingOrigin?.port == document.port &&
                    requestingOrigin!.origin == document.origin;
                final allowed =
                    trusted &&
                    await campusBridge.locationPermission(
                      request: true,
                      isCurrent: current,
                    );
                return GeolocationPermissionShowPromptResponse(
                  origin: origin,
                  allow: allowed && current(),
                  retain: false,
                );
              },
              onLoadStart: (web, uri) {
                if (!currentBrowser(web)) return;
                navigationRevision.value++;
                currentUrl.value = uri?.toString() ?? '';
              },
              onTitleChanged: (web, value) {
                if (currentBrowser(web)) pageTitle.value = value ?? '';
              },
              onProgressChanged: (web, value) {
                if (currentBrowser(web)) progress.value = value / 100;
              },
              onReceivedServerTrustAuthRequest: (web, challenge) async {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l10n.sslWarning)));
                }
                return ServerTrustAuthResponse(
                  action: ServerTrustAuthResponseAction.CANCEL,
                );
              },
              onLoadStop: (web, uri) async {
                if (!currentBrowser(web)) return;
                if (injectSsoCookies &&
                    uri?.scheme == 'https' &&
                    uri?.host == 'sso.fzu.edu.cn' &&
                    uri?.path == '/login') {
                  // A redirect can finish after the next page has started.
                  // Inspect the current document, rather than treating every
                  // /login callback as proof that the SSO ticket was rejected.
                  Object? loginFormVisible;
                  try {
                    loginFormVisible = await web.evaluateJavascript(
                      source: '''
(() => {
  if (location.origin !== 'https://sso.fzu.edu.cn' ||
      location.pathname !== '/login') return false;
  return !!(
    document.getElementById('login-page-flowkey') ||
    document.getElementById('current-login-type') ||
    document.querySelector('form input[type="password"]')
  );
})()
''',
                    );
                  } catch (_) {
                    // A replaced document or disposed native view cannot
                    // establish that the current session needs a new login.
                    return;
                  }
                  if (currentBrowser(web) && loginFormVisible == true) {
                    needsLogin.value = true;
                  }
                  return;
                }
                await injectForDomain(web, uri);
              },
            ),
          ),
        ],
      );
    }
    return AppScaffold(
      appBar: AppBar(
        title: Text(
          pageTitle.value.isNotEmpty ? pageTitle.value : l10n.webView,
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'refresh':
                  retry.value++;
                case 'copy':
                  await Clipboard.setData(
                    ClipboardData(text: currentUrl.value),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(l10n.copied)));
                  }
                case 'open':
                  final uri = Uri.tryParse(currentUrl.value);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                case 'clear':
                  await clearNativeWebViewCookies();
                  if (context.mounted) retry.value++;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'refresh', child: Text(l10n.refresh)),
              PopupMenuItem(value: 'copy', child: Text(l10n.copyLink)),
              PopupMenuItem(value: 'open', child: Text(l10n.openInBrowser)),
              PopupMenuItem(value: 'clear', child: Text(l10n.clearCookies)),
            ],
          ),
        ],
      ),
      body: AppSafeContent(child: body),
    );
  }
}
