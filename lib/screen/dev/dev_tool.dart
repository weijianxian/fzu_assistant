import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/my/about/widgets/update_dialog.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/update_service.dart';

const _tools = [
  (Icons.storage, 'SharedPreferences', AppRoutes.devSharedPrefs),
  (Icons.lock, 'SecureStorage', AppRoutes.devSecureStorage),
];

class DevToolPage extends StatelessWidget {
  const DevToolPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devTools)),
      body: ListView(
        children: [
          ..._tools.map(
            (tool) => ChevronListTile(
              leading: Icon(tool.$1),
              title: Text(tool.$2),
              onTap: () => context.pushNamed(tool.$3),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cookie_outlined),
            title: const Text('Expire Cookies'),
            subtitle: const Text(
              'Clear academic session cookies to test automatic re-login and request retry',
            ),
            onTap: () async {
              try {
                await ApiClient.instance.expireCookiesForDebug();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cookies have been expired')),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to expire cookies: $error')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Re-login'),
            subtitle: const Text(
              'Sign in again with the credentials stored on this device',
            ),
            onTap: () async {
              final success = await ApiClient.instance.refreshSession();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success ? 'Re-login succeeded' : 'Re-login failed',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.drag_handle),
            title: const Text('Native BottomSheet'),
            onTap: () => showHalfScreenSheet(
              context,
              builder: (controller) => ListView.builder(
                controller: controller,
                itemCount: 20,
                itemBuilder: (context, index) =>
                    ListTile(title: Text('Item ${index + 1}')),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('Force Update Dialog'),
            subtitle: const Text('Fetch latest release and show installer'),
            onTap: () async {
              final release = await UpdateService().fetchLatestRelease();
              if (!context.mounted) return;

              if (release == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to fetch latest release'),
                  ),
                );
                return;
              }

              showUpdateSheet(
                context,
                release: release,
                onSkip: () {},
                onSkipForever: () {},
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('WebView (with Cookie)'),
            onTap: () {
              final id = ApiClient.instance.userId;
              if (id == null) return;
              context.pushNamed(
                AppRoutes.webview,
                arguments: WebViewArgs(
                  url:
                      'https://jwcjwxt2.fzu.edu.cn:81/jcxx/xsxx/StudentInformation.aspx?id=$id',
                  injectCookies: true,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.css),
            title: const Text('Test CSS/JS Injection'),
            onTap: () => context.pushNamed(
              AppRoutes.webview,
              arguments: const WebViewArgs(
                url: 'https://example.com/',
                injectCookies: false,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('WebView (no Cookie)'),
            onTap: () {
              final id = ApiClient.instance.userId;
              if (id == null) return;
              context.pushNamed(
                AppRoutes.webview,
                arguments: WebViewArgs(
                  url:
                      'https://jwcjwxt2.fzu.edu.cn:81/jcxx/xsxx/StudentInformation.aspx?id=$id',
                  injectCookies: false,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
