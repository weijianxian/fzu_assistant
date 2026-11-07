import 'package:flutter/material.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/semester_utils.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/api/course_service.dart';
import 'package:fzu_assistant/service/calendar_sync_service.dart';

class HomeSettingsPage extends HookWidget {
  const HomeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final l10n = AppLocalizations.of(context)!;
    final autoAdjustCourse = useValueListenable(settings.autoAdjustCourse);
    final access = useValueListenable(settings.west2AdjustmentsAccess);
    final cachedTerms = useValueListenable(settings.termsKey);
    final selected = useValueListenable(settings.selectedSemesterKey);
    final termsLoading = useState(false);
    final termsError = useState<String?>(null);
    final terms = <String>{
      ...cachedTerms,
      if (selected.isNotEmpty) selected,
    }.toList()..sort((a, b) => b.compareTo(a));

    Future<void> loadTerms() async {
      if (settings.termsKey.value.isNotEmpty) return;
      termsLoading.value = true;
      termsError.value = null;
      try {
        final termInfo = await CourseService().getTerms();
        if (!context.mounted) return;
        settings.termsKey.value = termInfo.terms;
      } catch (e) {
        if (!context.mounted) return;
        termsError.value = e.toString();
      }
      if (!context.mounted) return;
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
          SettingsSection.list(
            title: l10n.settingsCoursesSection,
            children: [
              if (!CalendarSyncService.supported)
                ChevronListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(l10n.calendarExport),
                  subtitle: Text(l10n.calendarExportDescription),
                  onTap: () => context.pushNamed(AppRoutes.calendarExport),
                ),
              ChevronListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: Text(l10n.customCourseManagement),
                subtitle: Text(l10n.customCoursesDescription),
                onTap: () => context.pushNamed(AppRoutes.customCourses),
              ),
              ChevronListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: Text(l10n.hiddenCourseManagement),
                subtitle: Text(l10n.hiddenCourseSessionsDescription),
                onTap: () => context.pushNamed(AppRoutes.hiddenCourses),
              ),
            ],
          ),
          SettingsSection.list(
            title: l10n.settingsSemesterSection,
            children: [
              if (termsLoading.value)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (termsError.value != null)
                ListTile(
                  title: Text(termsError.value!),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: loadTerms,
                  ),
                )
              else
                SettingsChoiceTile<String>(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: l10n.selectSemester,
                  value: selected,
                  choices: [
                    SettingsChoice(value: '', label: l10n.autoSemester),
                    for (final term in terms)
                      SettingsChoice(
                        value: term,
                        label: SemesterUtils.formatSemester(term),
                      ),
                  ],
                  onChanged: (value) =>
                      settings.selectedSemesterKey.value = value,
                ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSection.list(
            title: l10n.navSchedule,
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
                ChevronListTile(
                  title: Text(l10n.west2AdjustmentsEnabled),
                  subtitle: Text(
                    access == FeatureAccess.allow
                        ? l10n.west2AdjustmentsDescription
                        : l10n.thirdPartyDisabled,
                  ),
                  onTap: () => context.pushNamed(AppRoutes.thirdPartySettings),
                ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
