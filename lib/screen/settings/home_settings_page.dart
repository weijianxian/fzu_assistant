import 'package:flutter/material.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Section(
            title: l10n.homeStyle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder<String>(
                valueListenable: settings.homeStyleKey,
                builder: (_, homeStyle, _) => DropdownButton<String>(
                  value: homeStyle,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: AppSettings.scheduleHomeStyle,
                      child: Text(l10n.homeStyleSchedule),
                    ),
                    DropdownMenuItem(
                      value: AppSettings.timelineHomeStyle,
                      child: Text(l10n.homeStyleTimeline),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) settings.homeStyleKey.value = value;
                  },
                ),
              ),
            ),
          ),
          Section(
            title: l10n.timelineCourseRange,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder(
                valueListenable: settings.timelineDaysKey,
                builder: (_, days, _) => DropdownButton<int>(
                  value: days,
                  isExpanded: true,
                  items: AppSettings.timelineDayOptions
                      .map(
                        (option) => DropdownMenuItem(
                          value: option,
                          child: Text(switch (option) {
                            1 => l10n.today,
                            30 => l10n.nextMonth,
                            _ => l10n.daysN(option),
                          }),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) settings.timelineDaysKey.value = value;
                  },
                ),
              ),
            ),
          ),
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
                  notifier: settings.showExamOnSchedule,
                  title: Text(l10n.showExamOnSchedule),
                  subtitle: Text(l10n.showExamOnScheduleDescription),
                ),
                SettingSwitchTile(
                  notifier: settings.autoAdjustCourse,
                  title: Text(l10n.autoAdjustCourse),
                  subtitle: Text(l10n.autoAdjustCourseDescription),
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
