import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_async_data.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/lecture.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';

class LecturesPage extends HookWidget {
  const LecturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = useMemoized(() => AcademicService());
    final result = useAsyncData(service.getLectures);
    final refreshing = useState(false);

    Future<void> refresh() async {
      if (refreshing.value) return;
      refreshing.value = true;
      try {
        await result.refresh();
      } finally {
        if (context.mounted) refreshing.value = false;
      }
    }

    void openOfficial() => context.pushNamed(
      AppRoutes.webview,
      arguments: WebViewArgs(
        url: AcademicService.lecturesUrl,
        title: l10n.jiaxiLectures,
      ),
    );

    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.jiaxiLectures),
        actions: [
          IconButton(
            onPressed: result.loading || refreshing.value ? null : refresh,
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.lecturesDescription),
          ),
          if (refreshing.value) const LinearProgressIndicator(),
          if (result.error != null && result.data != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.loadingFailed(result.error!))),
                  TextButton(
                    onPressed: refreshing.value ? null : refresh,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ToolPageWrapper(
              loading: result.loading && result.data == null,
              error: result.data == null ? result.error : null,
              hasData: result.data?.isNotEmpty ?? false,
              onRefresh: refresh,
              refreshTime: result.updatedAt,
              emptyText: l10n.lecturesEmpty,
              child: AppListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: result.data?.length ?? 0,
                itemBuilder: (context, index) =>
                    _LectureDetails(lecture: result.data![index]),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextButton.icon(
            onPressed: openOfficial,
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.lecturesOpenOfficial),
          ),
        ),
      ),
    );
  }
}

class _LectureDetails extends StatelessWidget {
  const _LectureDetails({required this.lecture});

  final Lecture lecture;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    String value(String text) => text.isEmpty ? l10n.lectureUnknown : text;
    final time = lecture.beijingStartTime;
    String pad(int number) => number.toString().padLeft(2, '0');
    final dateTime = time == null
        ? value(lecture.rawDateTime)
        : '${time.year}-${pad(time.month)}-${pad(time.day)} '
              '${pad(time.hour)}:${pad(time.minute)}';
    final details = [
      (l10n.lectureCategory, value(lecture.category)),
      (
        l10n.lectureIssueNumber,
        lecture.issueNumber?.toString() ?? l10n.lectureUnknown,
      ),
      (l10n.lectureSpeaker, value(lecture.speaker)),
      (l10n.lectureDateTime, dateTime),
      (l10n.lectureLocation, value(lecture.location)),
      (l10n.lectureAttendance, value(lecture.attendanceStatus)),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lecture.title.isEmpty ? l10n.lectureUntitled : lecture.title,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: [
              for (final detail in details)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 6),
                      child: Text(
                        detail.$1,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(detail.$2),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
