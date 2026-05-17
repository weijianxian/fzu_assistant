import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../guest/editor_page.dart';
import 'kv_tile.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('SecureStorage')),
      body: data.value.isEmpty
          ? const Center(
              child: Text('(empty)', style: TextStyle(color: Colors.grey)),
            )
          : ListView.builder(
              itemCount: data.value.length,
              itemBuilder: (_, i) {
                final e = data.value.entries.elementAt(i);
                return KVTile(
                  key_: e.key,
                  value: e.value,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditorPage(
                          title: e.key,
                          initialValue: e.value,
                          onSave: (text) async {
                            const ss = FlutterSecureStorage();
                            if (text == e.value) return true;
                            await ss.write(key: e.key, value: text);
                            return true;
                          },
                        ),
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
