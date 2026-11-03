import 'package:flutter/material.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/semester_utils.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/api/course_service.dart';
import 'package:fzu_assistant/service/api/api_client.dart';

class HomeSettingsPage extends HookWidget {
  const HomeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final l10n = AppLocalizations.of(context)!;
    final autoAdjustCourse = useValueListenable(settings.autoAdjustCourse);
    final access = useValueListenable(settings.west2AdjustmentsAccess);
    final hidden =
        useValueListenable(settings.hiddenCourseSessions)
            .where((s) => s.account == ApiClient.instance.studentId)
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

    final termsLoading = useState(false);
    final termsError = useState<String?>(null);

    Future<void> loadTerms() async {
      if (settings.termsKey.value.isNotEmpty) return;
      termsLoading.value = true;
      termsError.value = null;
      try {
        final termInfo = await CourseService().getTerms();
        settings.termsKey.value = termInfo.terms;
      } catch (e) {
        termsError.value = e.toString();
      }
      termsLoading.value = false;
    }

    useEffect(() {
      loadTerms();
      return null;
    }, []);

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.homeSettings)),
      body: AppListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Section(
            title: l10n.selectSemester,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder(
                valueListenable: settings.selectedSemesterKey,
                builder: (_, selected, _) {
                  final terms = settings.termsKey.value;

                  if (termsLoading.value) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }

                  if (termsError.value != null) {
                    return ListTile(
                      title: Text(termsError.value!),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          termsError.value = null;
                          loadTerms();
                        },
                      ),
                    );
                  }

                  return DropdownButton<String>(
                    value: selected.isEmpty ? '' : selected,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(l10n.autoSemester),
                      ),
                      for (final term in terms)
                        DropdownMenuItem(
                          value: term,
                          child: Text(SemesterUtils.formatSemester(term)),
                        ),
                    ],
                    onChanged: (v) {
                      settings.selectedSemesterKey.value = v ?? '';
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Section(
            title: l10n.navSchedule,
            child: Column(
              children: [
                SettingSwitchTile(
                  notifier: settings.showNonCurrentWeekCourses,
                  title: Text(l10n.showNonCurrentWeekCourses),
                  subtitle: Text(l10n.showNonCurrentWeekCoursesDescription),
                ),
                SettingSwitchTile(
                  notifier: settings.showExamOnSchedule,
                  title: Text(l10n.showExamOnSchedule),
                  subtitle: Text(l10n.showExamOnScheduleDescription),
                ),
                SettingSwitchTile(
                  notifier: settings.autoAdjustCourse,
                  title: Text(l10n.autoAdjustCourse),
                  subtitle: Text(l10n.autoAdjustCourseDescription),
                ),
                if (autoAdjustCourse && access != FeatureAccess.hide)
                  ListTile(
                    title: Text(l10n.west2AdjustmentsEnabled),
                    subtitle: Text(
                      access == FeatureAccess.allow
                          ? l10n.west2AdjustmentsDescription
                          : l10n.thirdPartyDisabled,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.pushNamed(AppRoutes.thirdPartySettings),
                  ),
              ],
            ),
          ),
          Section(
            title: l10n.hiddenCourseSessions,
            child: Column(
              children: [
                ListTile(
                  title: Text(l10n.hiddenCourseSessionsDescription),
                  trailing: hidden.isEmpty
                      ? null
                      : TextButton(
                          onPressed: () => settings.restoreAllCourseSessions(
                            ApiClient.instance.studentId!,
                          ),
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
                      onPressed: () => settings.restoreCourseSession(session),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
