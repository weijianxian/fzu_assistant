import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/semester_utils.dart';
import 'package:fzu_assistant/common/widget/settings/settings_choice_sheet.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';

/// 通用的学期选择按钮，复用随界面风格变化的单选弹层。
///
/// [selected] 为空字符串时表示"自动"模式。
class TermSelectorButton extends HookWidget {
  final List<String> terms;
  final String selected;
  final ValueChanged<String> onSelected;

  const TermSelectorButton({
    super.key,
    required this.terms,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final showing = useState(false);
    if (terms.isEmpty && selected.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      icon: const Icon(Icons.calendar_month),
      tooltip: l10n.selectSemester,
      onPressed: showing.value
          ? null
          : () async {
              if (showing.value) return;
              showing.value = true;
              try {
                final value = await showSettingsChoiceSheet<String>(
                  context: context,
                  title: l10n.selectSemester,
                  selected: selected,
                  choices: [
                    SettingsChoice(value: '', label: l10n.autoSemester),
                    for (final term in {
                      ...terms,
                      if (selected.isNotEmpty) selected,
                    })
                      SettingsChoice(
                        value: term,
                        label: SemesterUtils.formatSemester(term),
                      ),
                  ],
                );
                if (context.mounted && value != null && value != selected) {
                  onSelected(value);
                }
              } finally {
                if (context.mounted) showing.value = false;
              }
            },
    );
  }
}
