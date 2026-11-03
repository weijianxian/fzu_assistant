import 'package:flutter/material.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/semester_utils.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/api/course_service.dart';

class HomeSettingsPage extends HookWidget {
  const HomeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final l10n = AppLocalizations.of(context)!;
    final autoAdjustCourse = useValueListenable(settings.autoAdjustCourse);
    final access = useValueListenable(settings.west2AdjustmentsAccess);
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
          ListTile(
            leading: const Icon(Icons.event_note_outlined),
            title: Text(l10n.customCourseManagement),
            subtitle: Text(l10n.customCoursesDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed(AppRoutes.customCourses),
          ),
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: Text(l10n.hiddenCourseManagement),
            subtitle: Text(l10n.hiddenCourseSessionsDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed(AppRoutes.hiddenCourses),
          ),
          Section(
            title: l10n.selectSemester,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder(
                valueListenable: settings.selectedSemesterKey,
                builder: (_, selected, _) {
                  final terms = <String>{
                    ...settings.termsKey.value,
                    if (selected.isNotEmpty) selected,
                  }.toList()..sort((a, b) => b.compareTo(a));

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
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
