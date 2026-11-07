import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widget/navigation/chevron_list_tile.dart';

import 'settings_choice_sheet.dart';

/// A compact value row with a native radio sheet and duplicate-open protection.
class SettingsChoiceTile<T> extends HookWidget {
  const SettingsChoiceTile({
    super.key,
    required this.title,
    required this.value,
    required this.choices,
    required this.onChanged,
    this.leading,
  });

  final String title;
  final T value;
  final List<SettingsChoice<T>> choices;
  final ValueChanged<T> onChanged;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final showing = useState(false);
    return ChevronListTile(
      leading: leading,
      title: Text(title),
      subtitle: Text(
        choices.firstWhere((choice) => choice.value == value).label,
      ),
      onTap: showing.value
          ? null
          : () async {
              if (showing.value) return;
              showing.value = true;
              try {
                final selected = await showSettingsChoiceSheet<T>(
                  context: context,
                  title: title,
                  selected: value,
                  choices: choices,
                );
                if (context.mounted && selected != null && selected != value) {
                  onChanged(selected);
                }
              } finally {
                if (context.mounted) showing.value = false;
              }
            },
    );
  }
}
