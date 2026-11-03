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
                await manager.setCookie(
                  url: WebUri(SsoService.loginUrl),
                  name: 'SOURCEID_TGC',
                  value: ssoCookie!,
                  path: '/',
                  isSecure: true,
                  isHttpOnly: true,
                );
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
                onPressed: () =>
                    context.pushNamed(AppRoutes.campusServicesLogin),
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
                userAgent: injectSsoCookies ? SsoService.userAgent : null,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              ),
              onWebViewCreated: (web) => controller.value = web,
              shouldOverrideUrlLoading: (web, action) async {
                final uri = action.request.url;
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
              onLoadStart: (web, uri) {
                if (context.mounted) currentUrl.value = uri?.toString() ?? '';
              },
              onTitleChanged: (web, value) {
                if (context.mounted) pageTitle.value = value ?? '';
              },
              onProgressChanged: (web, value) {
                if (context.mounted) progress.value = value / 100;
              },
              onReceivedServerTrustAuthRequest: (web, challenge) async {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l10n.sslWarning)));
                }
                return ServerTrustAuthResponse(
                  action: injectSsoCookies
                      ? ServerTrustAuthResponseAction.CANCEL
                      : ServerTrustAuthResponseAction.PROCEED,
                );
              },
              onLoadStop: (web, uri) async {
                if (injectSsoCookies &&
                    uri?.host == 'sso.fzu.edu.cn' &&
                    uri?.path == '/login') {
                  if (context.mounted) needsLogin.value = true;
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
