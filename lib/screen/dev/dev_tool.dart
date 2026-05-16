import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _maxChars = 200;

class DevToolPage extends HookWidget {
  const DevToolPage({super.key});

  @override
  Widget build(BuildContext context) {
    final spData = useState<Map<String, Object>>({});
    final ssData = useState<Map<String, String>>({});

    useEffect(() {
      _loadAll(spData, ssData);
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.devTools)),
      body: ListView(
        children: [
          _section('SharedPreferences', spData.value, onDelete: (key) async {
            final sp = await SharedPreferences.getInstance();
            await sp.remove(key);
            await _loadAll(spData, ssData);
          }),
          _section('SecureStorage', ssData.value),
        ],
      ),
    );
  }


  Future<void> _loadAll(
    ValueNotifier<Map<String, Object>> spData,
    ValueNotifier<Map<String, String>> ssData,
  ) async {
    final sp = await SharedPreferences.getInstance();
    spData.value = Map.from(sp.getKeys().fold<Map<String, Object>>({}, (m, k) {
      m[k] = sp.get(k)!;
      return m;
    }));

    const ss = FlutterSecureStorage();
    ssData.value = await ss.readAll();
  }

  Widget _section(String title, Map<dynamic, dynamic> data, {Future<void> Function(String key)? onDelete}) {
    if (data.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('$title: (empty)',
              style: const TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        title: Text('$title (${data.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        initiallyExpanded: false,
        children: data.entries
            .map((e) => _KVTile(
                  key_: '${e.key}',
                  value: e.value.toString(),
                  onDelete: onDelete != null ? () => onDelete('${e.key}') : null,
                ))
            .toList(),
      ),
    );
  }
}

class _KVTile extends HookWidget {
  final String key_;
  final String value;
  final VoidCallback? onDelete;

  const _KVTile({required this.key_, required this.value, this.onDelete});

  static String _tryPrettyJson(String s) {
    try {
      final obj = jsonDecode(s);
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (_) {
      return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final expanded = useState(false);
    final pretty = _tryPrettyJson(value);
    final hasMore = pretty.length > _maxChars;
    final displayValue =
        hasMore && !expanded.value ? pretty.substring(0, _maxChars) : pretty;

    return ListTile(
      dense: true,
      title: Text(key_,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      trailing: onDelete != null
          ? IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: onDelete,
            )
          : null,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(displayValue, style: const TextStyle(fontSize: 12)),
          if (hasMore)
            GestureDetector(
              onTap: () => expanded.value = !expanded.value,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  expanded.value ? AppLocalizations.of(context)!.collapse : AppLocalizations.of(context)!.expandAll,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
