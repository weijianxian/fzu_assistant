import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';

const _maxChars = 200;

class KVTile extends HookWidget {
  final String key_;
  final String value;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const KVTile({
    super.key,
    required this.key_,
    required this.value,
    this.onDelete,
    this.onTap,
  });

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
    final displayValue = hasMore && !expanded.value
        ? pretty.substring(0, _maxChars)
        : pretty;

    return ListTile(
      dense: true,
      onTap: onTap,
      title: Text(
        key_,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
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
                  expanded.value
                      ? AppLocalizations.of(context)!.collapse
                      : AppLocalizations.of(context)!.expandAll,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
