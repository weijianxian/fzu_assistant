import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widget/academic_change_notice.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_async_data.dart';
import 'package:fzu_assistant/common/utils/grade_summary.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/mark.dart';
import 'package:fzu_assistant/model/semester_summary.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:intl/intl.dart';

class MarksPage extends HookWidget {
  const MarksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final expandedKeys = useState<Set<String>>({});
    final service = useMemoized(() => AcademicService());

    final unknownSemester = AppLocalizations.of(context)!.unknownSemester;

    final result = useAsyncData(
      service.getMarks,
      initialData: const <Mark>[],
      onLoaded: (marks) {
        if (marks.isNotEmpty) {
          final first = marks.first.semester;
          expandedKeys.value = {first.isEmpty ? unknownSemester : first};
        }
      },
    );
    final marks = result.data!;

    return AppScaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.marksQuery)),
      body: ToolPageWrapper(
        onRefresh: result.refresh,
        loading: result.loading,
        error: result.error,
        refreshTime: result.updatedAt,
        hasData: marks.isNotEmpty,
        emptyText: AppLocalizations.of(context)!.noMarksData,
        slivers: _buildSlivers(context, marks, expandedKeys),
      ),
    );
  }

  List<Widget> _buildSlivers(
    BuildContext context,
    List<Mark> marks,
    ValueNotifier<Set<String>> expandedKeys,
  ) {
    // 按学期分组，保持顺序
    final grouped = <String, List<Mark>>{};
    for (final m in marks) {
      final key = m.semester.isEmpty
          ? AppLocalizations.of(context)!.unknownSemester
          : m.semester;
      grouped.putIfAbsent(key, () => []).add(m);
    }
    // 每学期按成绩倒序
    for (final list in grouped.values) {
      list.sort(GradeSummary.compareMarks);
    }
    final semesters = grouped.keys.toList();

    return [
      const SliverToBoxAdapter(child: AcademicChangeNotice(exams: false)),
      MasonrySliverGrid(
        childCount: semesters.length,
        itemBuilder: (context, i) {
          final sem = semesters[i];
          final items = grouped[sem]!;
          final summary = SemesterSummary.fromMarks(items);
          return Card(
            margin: EdgeInsets.zero,
            child: ExpansionTile(
              key: ValueKey(sem),
              initiallyExpanded: expandedKeys.value.contains(sem),
              onExpansionChanged: (expanded) {
                final next = Set<String>.of(expandedKeys.value);
                if (expanded) {
                  next.add(sem);
                } else {
                  next.remove(sem);
                }
                expandedKeys.value = next;
              },
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                sem,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.courseCount(summary.courseCount),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              children: [
                SemesterSummaryCard(summary: summary),
                for (var j = 0; j < items.length; j++) ...[
                  _buildMarkTile(context, items[j]),
                  if (j < items.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          );
        },
      ),
    ];
  }

  Widget _buildMarkTile(BuildContext context, Mark m) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final gpaStatus = GradeSummary.gpaStatus(m);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  m.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 2,
                child: Text(
                  m.score,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _scoreColor(context, m.score),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _tag(context, l10n.creditsTag(m.credits)),
              if (gpaStatus != CourseGpaStatus.notApplicable)
                _tag(
                  context,
                  gpaStatus == CourseGpaStatus.available
                      ? l10n.gpaTag(m.gpa)
                      : l10n.gradesMissingGpa,
                ),
              if (m.teacher.isNotEmpty) _tag(context, m.teacher),
            ],
          ),
          if (m.electiveType.isNotEmpty || m.examType.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 8,
                children: [
                  if (m.electiveType.isNotEmpty)
                    _tag(
                      context,
                      m.electiveType,
                      foreground: colors.onPrimaryContainer,
                      background: colors.primaryContainer,
                    ),
                  if (m.examType.isNotEmpty)
                    _tag(
                      context,
                      m.examType,
                      foreground: colors.onTertiaryContainer,
                      background: colors.tertiaryContainer,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tag(
    BuildContext context,
    String text, {
    Color? foreground,
    Color? background,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background ?? colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: foreground ?? colors.onSurfaceVariant,
        ),
      ),
    );
  }

  Color _scoreColor(BuildContext context, String score) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return switch (GradeSummary.scoreBand(score)) {
      GradeBand.excellent =>
        dark ? Colors.green.shade300 : Colors.green.shade800,
      GradeBand.good => dark ? Colors.blue.shade300 : Colors.blue.shade800,
      GradeBand.medium => dark ? Colors.amber.shade200 : Colors.amber.shade900,
      GradeBand.pass || GradeBand.unknown => theme.colorScheme.onSurfaceVariant,
      GradeBand.fail => theme.colorScheme.error,
    };
  }
}

/// A compact summary that follows the surrounding semester card's theme.
class SemesterSummaryCard extends HookWidget {
  final SemesterSummary summary;

  const SemesterSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final creditFormat = NumberFormat('0.##', locale);
    final gpaFormat = NumberFormat('0.00', locale);
    final gpaText = summary.estimatedGpa != null
        ? gpaFormat.format(summary.estimatedGpa)
        : summary.isGpaIncomplete
        ? l10n.gradesSummaryMissingValue
        : l10n.gradesSummaryNoGpa;

    TableRow metric(String label, String value, {bool emphasis = false}) {
      return TableRow(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(0, 5, 16, 5),
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleMedium?.copyWith(
                color: emphasis ? colors.primary : colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.gradesSummaryTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Table(
            columnWidths: const {0: FlexColumnWidth(1.1), 1: FlexColumnWidth()},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              metric(
                l10n.gradesSummaryTotalCredits,
                creditFormat.format(summary.totalCredits),
              ),
              metric(
                l10n.gradesSummaryHighestScore,
                summary.highestScore ?? l10n.gradesSummaryMissingValue,
              ),
              metric(
                l10n.gradesSummaryEstimatedGpa,
                gpaText,
                emphasis: summary.estimatedGpa != null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (summary.isGpaIncomplete)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l10n.gradesSummaryIncompleteGpa,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ),
          if (summary.missingCreditsCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l10n.gradesSummaryIncompleteCredits,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ),
          Text(
            l10n.gradesSummaryGpaNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.gradesSummaryRules,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
