import 'package:fzu_assistant/common/widget/layout/app_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/semester_utils.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';

class HiddenCoursesPage extends HookWidget {
  const HiddenCoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final l10n = AppLocalizations.of(context)!;
    final account = ApiClient.instance.studentId;
    final hidden =
        useValueListenable(settings.hiddenCourseSessions)
            .where((session) => session.account == account)
            .toList()
          ..sort((a, b) {
            final byTerm = b.term.compareTo(a.term);
            if (byTerm != 0) return byTerm;
            final byWeek = a.week.compareTo(b.week);
            if (byWeek != 0) return byWeek;
            final byDay = a.weekday.compareTo(b.weekday);
            if (byDay != 0) return byDay;
            return a.startClass.compareTo(b.startClass);
          });
    final weekdays = [
      l10n.monday,
      l10n.tuesday,
      l10n.wednesday,
      l10n.thursday,
      l10n.friday,
      l10n.saturday,
      l10n.sunday,
    ];

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.hiddenCourseManagement)),
      body: AppListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            title: Text(l10n.hiddenCourseSessionsDescription),
            trailing: hidden.isEmpty
                ? null
                : TextButton(
                    onPressed: () {
                      if (account != null &&
                          account == ApiClient.instance.studentId) {
                        settings.restoreAllCourseSessions(account);
                      }
                    },
                    child: Text(l10n.restoreAllCourseSessions),
                  ),
          ),
          if (hidden.isEmpty)
            ListTile(title: Text(l10n.noHiddenCourseSessions)),
          for (final session in hidden)
            ListTile(
              title: Text(session.name),
              subtitle: Text(
                [
                  SemesterUtils.formatSemester(session.term),
                  '${l10n.weekN(session.week)} · ${weekdays[session.weekday - 1]} · ${l10n.classPeriodRange(session.startClass, session.endClass)}',
                  if (session.teacher.isNotEmpty) session.teacher,
                  if (session.location.isNotEmpty) session.location,
                ].join('\n'),
              ),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.visibility_outlined),
                tooltip: l10n.restoreCourseSession,
                onPressed: () {
                  if (account == ApiClient.instance.studentId) {
                    settings.restoreCourseSession(session);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
