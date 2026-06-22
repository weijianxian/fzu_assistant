import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../guest/editor_page.dart';
import 'widgets/kv_tile.dart';

class SharedPrefsPage extends HookWidget {
  const SharedPrefsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = useState<Map<String, Object>>({});

    Future<void> load() async {
      final sp = await SharedPreferences.getInstance();
      data.value = Map.from(
        sp.getKeys().fold<Map<String, Object>>({}, (m, k) {
          m[k] = sp.get(k)!;
          return m;
        }),
      );
    }

    useEffect(() {
      load();
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(title: const Text('SharedPreferences')),
      body: data.value.isEmpty
          ? const Center(
              child: Text('(empty)', style: TextStyle(color: Colors.grey)),
            )
          : ListView.builder(
              itemCount: data.value.length,
              itemBuilder: (_, i) {
                final e = data.value.entries.elementAt(i);
                final value = e.value;
                final displayValue = value is List
                    ? jsonEncode(value)
                    : value.toString();

                return KVTile(
                  key_: e.key,
                  value: displayValue,
                  onTap: () async {
                    final edited = await context.push<String>(
                      EditorPage(
                        title: e.key,
                        initialValue: displayValue,
                        onSave: (text) async {
                          final sp = await SharedPreferences.getInstance();
                          if (text == displayValue) return true;
                          await _saveTyped(sp, e.key, text, value);
                          return true;
                        },
                      ),
                    );
                    if (edited != null) await load();
                  },
                  onDelete: () async {
                    final sp = await SharedPreferences.getInstance();
                    await sp.remove(e.key);
                    await load();
                  },
                );
              },
            ),
    );
  }

  static Future<void> _saveTyped(
    SharedPreferences sp,
    String key,
    String text,
    Object original,
  ) async {
    switch (original) {
      case int _:
        await sp.setInt(key, int.parse(text));
      case double _:
        await sp.setDouble(key, double.parse(text));
      case bool _:
        await sp.setBool(key, text.toLowerCase() == 'true');
      case List _:
        final decoded = jsonDecode(text);
        if (decoded is List) {
          await sp.setStringList(key, decoded.cast<String>());
        } else {
          await sp.setString(key, text);
        }
      default:
        await sp.setString(key, text);
    }
  }
}
