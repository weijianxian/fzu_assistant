import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/main.dart' show webViewEnvironment;
import 'package:fzu_assistant/constants/site_injections.dart';
import 'package:fzu_assistant/service/api_client.dart';
import 'package:url_launcher/url_launcher.dart';

class WebViewPage extends StatefulWidget {
  final String url;
  final String? title;
  final bool injectCookies;

  const WebViewPage({
    super.key,
    required this.url,
    this.title,
    this.injectCookies = true,
  });

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? _controller;
  String _currentUrl = '';
  String _pageTitle = '';
  double _progress = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _pageTitle = widget.title ?? '';
    if (widget.injectCookies) {
      _initCookies();
    } else {
      _ready = true;
    }
  }

  Future<void> _initCookies() async {
    final cookieJar = ApiClient.instance.cookieJar;
    final domains = ['https://jwcjwxt2.fzu.edu.cn', 'https://jwch.fzu.edu.cn'];
    final manager = CookieManager.instance(
      webViewEnvironment: webViewEnvironment,
    );
    await manager.deleteAllCookies();
    for (final domain in domains) {
      final cookies = await cookieJar.loadForRequest(Uri.parse(domain));
      for (final c in cookies) {
        await manager.setCookie(
          url: WebUri(domain),
          name: c.name,
          value: c.value,
          path: c.path ?? '/',
          domain: c.domain,
          isSecure: c.secure,
          isHttpOnly: c.httpOnly,
        );
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  static String _jsStringLiteral(String s) {
    return "'${s.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n').replaceAll('\r', '\\r')}'";
  }

  Future<void> _injectForDomain(
    InAppWebViewController controller,
    Uri? uri,
  ) async {
    final url = uri?.toString() ?? '';
    for (final injection in kSiteInjections) {
      if (RegExp(injection.pattern).hasMatch(url)) {
        if (injection.css != null) {
          await controller.evaluateJavascript(
            source:
                "var s=document.createElement('style');s.textContent=${_jsStringLiteral(injection.css!)};document.head.appendChild(s);",
          );
        }
        if (injection.js != null) {
          await controller.evaluateJavascript(source: injection.js!);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle.isNotEmpty ? _pageTitle : l10n.webView),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'refresh':
                  _controller?.reload();
                  break;
                case 'copy':
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(_currentUrl)));
                  break;
                case 'open':
                  final uri = Uri.parse(_currentUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  break;
                case 'clear':
                  await CookieManager.instance(
                    webViewEnvironment: webViewEnvironment,
                  ).deleteAllCookies();
                  break;
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
      body: _ready
          ? Column(
              children: [
                if (_progress < 1.0) LinearProgressIndicator(value: _progress),
                Expanded(
                  child: InAppWebView(
                    webViewEnvironment: webViewEnvironment,
                    initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      useHybridComposition: !Platform.isAndroid,
                      algorithmicDarkeningAllowed: true,
                      mixedContentMode:
                          MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    ),
                    onWebViewCreated: (controller) {
                      _controller = controller;
                    },
                    onLoadStart: (controller, url) {
                      setState(() => _currentUrl = url?.toString() ?? '');
                    },
                    onTitleChanged: (controller, title) {
                      setState(() => _pageTitle = title ?? '');
                    },
                    onProgressChanged: (controller, progress) {
                      setState(() => _progress = progress / 100.0);
                    },
                    onLoadStop: (controller, url) {
                      _injectForDomain(controller, url);
                    },
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}
