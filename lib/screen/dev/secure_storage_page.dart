import 'package:fzu_assistant/common/widget/layout/app_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fzu_assistant/router/app_routes.dart';

import 'widgets/kv_tile.dart';

import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';

class SecureStoragePage extends HookWidget {
  const SecureStoragePage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = useState<Map<String, String>>({});

    Future<void> load() async {
      const ss = FlutterSecureStorage();
      data.value = await ss.readAll();
    }

    useEffect(() {
      load();
      return null;
    }, []);

    return AppScaffold(
      appBar: AppBar(title: const Text('SecureStorage')),
      body: data.value.isEmpty
          ? const Center(
              child: Text('(empty)', style: TextStyle(color: Colors.grey)),
            )
          : AppListView.builder(
              itemCount: data.value.length,
              itemBuilder: (_, i) {
                final e = data.value.entries.elementAt(i);
                return KVTile(
                  key_: e.key,
                  value: e.value,
                  onTap: () async {
                    await context.pushNamed(
                      AppRoutes.editor,
                      arguments: EditorArgs(
                        title: e.key,
                        initialValue: e.value,
                        onSave: (text) async {
                          const ss = FlutterSecureStorage();
                          if (text == e.value) return true;
                          await ss.write(key: e.key, value: text);
                          return true;
                        },
                      ),
                    );
                    await load();
                  },
                );
              },
            ),
    );
  }
}
