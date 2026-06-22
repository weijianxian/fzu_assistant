import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/utils/semester_utils.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';

/// 通用的学期选择下拉按钮。
///
/// [selected] 为空字符串时表示"自动"模式。
class TermSelectorButton extends StatelessWidget {
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
    if (terms.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.calendar_month),
      tooltip: AppLocalizations.of(context)!.selectSemester,
      onSelected: onSelected,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: '',
          child: Row(
            children: [
              if (selected.isEmpty)
                const Icon(Icons.check, size: 18)
              else
                const SizedBox(width: 18),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.autoSemester),
            ],
          ),
        ),
        const PopupMenuDivider(),
        for (final term in terms)
          PopupMenuItem(
            value: term,
            child: Row(
              children: [
                if (selected == term)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(SemesterUtils.formatSemester(term)),
              ],
            ),
          ),
      ],
    );
  }
}
