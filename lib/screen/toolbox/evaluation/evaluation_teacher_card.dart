import 'package:flutter/material.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/evaluation.dart';

const defaultComments = [
  '学识渊博，品德高尚，思学生所思，为学生而为，是传道授业解惑之良师。',
  '爱岗敬业、严谨治学、为人师表。',
  '课堂结构完整，层次清楚，突出重点，突破难点，各环衔接紧密，时间安排合理。',
];

class EvaluationTeacherCard extends StatelessWidget {
  final EvaluationTeacher teacher;
  final String score;
  final int? selectedComment;
  final String customComment;
  final ValueChanged<String> onScoreChanged;
  final ValueChanged<int?> onCommentChanged;
  final ValueChanged<String> onCustomCommentChanged;
  final VoidCallback onSubmit;

  const EvaluationTeacherCard({
    super.key,
    required this.teacher,
    required this.score,
    required this.selectedComment,
    required this.customComment,
    required this.onScoreChanged,
    required this.onCommentChanged,
    required this.onCustomCommentChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final hasComment =
        selectedComment != null &&
        (selectedComment != defaultComments.length || customComment.isNotEmpty);
    final canSubmit = score.isNotEmpty && hasComment;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.courseName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teacher.teacherName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller:
                        TextEditingController(text: score.isEmpty ? '0' : score)
                          ..selection = TextSelection.collapsed(
                            offset: score.isEmpty ? 1 : score.length,
                          ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 3,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      suffixText: ' /100',
                      suffixStyle: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (text) {
                      final numeric = text.replaceAll(RegExp(r'[^0-9]'), '');
                      if (numeric.isEmpty) {
                        onScoreChanged('');
                        return;
                      }
                      final num = int.parse(numeric);
                      final clamped = num.clamp(0, 100);
                      onScoreChanged(clamped.toString());
                    },
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              l10n.evalSelectComment,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            RadioGroup<int>(
              groupValue: selectedComment,
              onChanged: onCommentChanged,
              child: Column(
                children: [
                  ...List.generate(defaultComments.length, (idx) {
                    return RadioListTile<int>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: idx,
                      title: Text(
                        defaultComments[idx],
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }),
                  RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: defaultComments.length,
                    title: Text(
                      l10n.evalCustomComment,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            if (selectedComment == defaultComments.length)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 4),
                child: TextField(
                  controller: TextEditingController(text: customComment)
                    ..selection = TextSelection.collapsed(
                      offset: customComment.length,
                    ),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: l10n.evalCustomHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  onChanged: onCustomCommentChanged,
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: canSubmit ? onSubmit : null,
                icon: const Icon(Icons.send, size: 18),
                label: Text(l10n.evalSubmit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
