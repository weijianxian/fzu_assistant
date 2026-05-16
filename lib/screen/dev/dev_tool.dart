import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fzu_assistant/theme/app_themes.dart';
import 'package:fzu_assistant/theme/theme_provider.dart';

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
      appBar: AppBar(title: const Text('Dev Tools')),
      body: ListView(
        children: [
          _buildThemeSection(context),
          _section('SharedPreferences', spData.value),
          _section('SecureStorage', ssData.value),
        ],
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    final provider = ThemeProvider.of(context);
    final modeLabels = ['跟随系统', '浅色', '深色'];

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('主题',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(appThemes.length, (i) {
                final (name, color) = appThemes[i];
                return ValueListenableBuilder(
                  valueListenable: provider.themeIndex,
                  builder: (_, idx, __) {
                    return ChoiceChip(
                      label: Text(name),
                      selected: idx == i,
                      selectedColor: color.withValues(alpha: 0.3),
                      onSelected: (_) => provider.themeIndex.value = i,
                    );
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text('深色模式',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ValueListenableBuilder(
              valueListenable: provider.themeMode,
              builder: (_, mode, __) {
                return SegmentedButton<int>(
                  segments: List.generate(3, (i) {
                    final icons = [
                      Icons.brightness_auto,
                      Icons.light_mode,
                      Icons.dark_mode,
                    ];
                    return ButtonSegment<int>(
                      value: i,
                      icon: Icon(icons[i]),
                      label: Text(modeLabels[i]),
                    );
                  }),
                  selected: {mode},
                  onSelectionChanged: (s) => provider.themeMode.value = s.first,
                );
              },
            ),
          ],
        ),
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

  Widget _section(String title, Map<dynamic, dynamic> data) {
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
                ))
            .toList(),
      ),
    );
  }
}

class _KVTile extends HookWidget {
  final String key_;
  final String value;

  const _KVTile({required this.key_, required this.value});

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
                  expanded.value ? '收起' : '展开全部',
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
