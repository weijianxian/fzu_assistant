import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widget/half_screen_sheet.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/dev/secure_storage_page.dart';
import 'package:fzu_assistant/screen/dev/shared_prefs_page.dart';
import 'package:fzu_assistant/screen/my/about/update_dialog.dart';
import 'package:fzu_assistant/screen/guest/webview_page.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/update_service.dart';

final List<Map<String, dynamic>> tools = [
  {
    'icon': Icons.storage,
    'title': 'SharedPreferences',
    'page': const SharedPrefsPage(),
  },
  {
    'icon': Icons.lock,
    'title': 'SecureStorage',
    'page': const SecureStoragePage(),
  },
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
          ...tools.map(
            (tool) => ListTile(
              leading: Icon(tool['icon']),
              title: Text(tool['title']),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(tool['page']),
            ),
          ),
          const Divider(),
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
              context.push(
                WebViewPage(
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
            onTap: () => context.push(
              const WebViewPage(
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
              context.push(
                WebViewPage(
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
