import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widget/section.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/api/course_service.dart';

class ScheduleSettingsPage extends HookWidget {
  const ScheduleSettingsPage({super.key});

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
      appBar: AppBar(title: Text(l10n.scheduleSettings)),
      body: ListView(
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
                          child: Text(AppSettings.formatSemester(term)),
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
            title: l10n.scheduleSettings,
            child: Column(
              children: [
                ValueListenableBuilder(
                  valueListenable: settings.showExamOnSchedule,
                  builder: (_, showExam, _) => SwitchListTile(
                    title: Text(l10n.showExamOnSchedule),
                    value: showExam,
                    onChanged: (v) => settings.showExamOnSchedule.value = v,
                  ),
                ),
                ValueListenableBuilder(
                  valueListenable: settings.autoAdjustCourse,
                  builder: (_, autoAdjust, _) => SwitchListTile(
                    title: Text(l10n.autoAdjustCourse),
                    value: autoAdjust,
                    onChanged: (v) => settings.autoAdjustCourse.value = v,
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
