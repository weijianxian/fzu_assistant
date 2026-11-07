import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_async_data.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/academic_change.dart';
import 'package:fzu_assistant/service/academic_changes_service.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:intl/intl.dart';

class AcademicChangesPage extends HookWidget {
  const AcademicChangesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = AcademicChangesService.instance;
    final changes = useValueListenable(service);
    final failure = useState<String?>(null);
    final busy = useState(false);
    final query = useAsyncData(() async {
      await service.load(ApiClient.instance.studentId ?? '');
      return true;
    });
    Future<void> markRead({String? id}) async {
      if (busy.value) return;
      busy.value = true;
      failure.value = null;
      try {
        await service.markRead(id: id);
      } catch (error) {
        if (context.mounted) failure.value = error.toString();
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    String label(AcademicChangeType type) => switch (type) {
      AcademicChangeType.gradeAdded => l10n.academicChangeGradeAdded,
      AcademicChangeType.gradeChanged => l10n.academicChangeGradeChanged,
      AcademicChangeType.examAdded => l10n.academicChangeExamAdded,
      AcademicChangeType.examChanged => l10n.academicChangeExamChanged,
      AcademicChangeType.examRemoved => l10n.academicChangeExamRemoved,
    };
    String termLabel(String term) {
      final match = RegExp(r'^(\d{4})(\d{2})$').firstMatch(term);
      if (match == null) return term;
      return l10n.academicYearTerm(
        match[1]!,
        '${int.parse(match[1]!) + 1}',
        '${int.parse(match[2]!)}',
      );
    }

    final dateFormat = DateFormat.yMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).add_Hm();
    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.academicChanges),
        actions: [
          IconButton(
            tooltip: l10n.academicChangesMarkRead,
            onPressed: busy.value || changes.every((e) => e.read)
                ? null
                : () => markRead(),
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: ToolPageWrapper(
        loading: query.loading,
        error: query.error,
        hasData: query.data == true,
        emptyText: l10n.academicChangesEmpty,
        onRefresh: query.refresh,
        slivers: [
          SliverToBoxAdapter(
            child: ListTile(subtitle: Text(l10n.academicChangesDescription)),
          ),
          if (failure.value != null)
            SliverToBoxAdapter(
              child: ListTile(title: Text(l10n.loadingFailed(failure.value!))),
            ),
          if (changes.isEmpty)
            SliverToBoxAdapter(
              child: ListTile(title: Text(l10n.academicChangesEmpty)),
            ),
          AppSliverList(
            itemCount: changes.length,
            itemBuilder: (context, index) {
              final item = changes[index];
              final detail = item.before.isNotEmpty && item.after.isNotEmpty
                  ? l10n.academicChangeFromTo(item.before, item.after)
                  : item.after.isNotEmpty
                  ? item.after
                  : item.before;
              return ListTile(
                leading: Icon(
                  item.type.isExam
                      ? Icons.event_note_outlined
                      : Icons.school_outlined,
                  color: item.read
                      ? null
                      : Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  item.course,
                  style: TextStyle(
                    fontWeight: item.read ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  [
                    label(item.type),
                    if (item.term.isNotEmpty) termLabel(item.term),
                    if (detail.isNotEmpty) detail,
                    l10n.academicChangeDetectedAt(
                      dateFormat.format(
                        item.detectedAt.toUtc().add(const Duration(hours: 8)),
                      ),
                    ),
                  ].join('\n'),
                ),
                onTap: item.read || busy.value
                    ? null
                    : () => markRead(id: item.id),
              );
            },
          ),
        ],
      ),
    );
  }
}
