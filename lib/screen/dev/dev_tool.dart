import 'package:flutter/material.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/dev/secure_storage_page.dart';
import 'package:fzu_assistant/screen/dev/shared_prefs_page.dart';

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
        children: tools
            .map(
              (tool) => ListTile(
                leading: Icon(tool['icon']),
                title: Text(tool['title']),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => tool['page']),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
