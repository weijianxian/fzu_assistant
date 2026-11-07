import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_async_data.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/calendar_export.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/calendar_export_service.dart';
import 'package:fzu_assistant/service/calendar_sync_service.dart';
import 'package:fzu_assistant/screen/settings/calendar_sync_settings_page.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class CalendarExportPage extends HookWidget {
  const CalendarExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (CalendarSyncService.supported) return const CalendarSyncSettingsPage();
    final settings = AppSettingsProvider.of(context);
    final l10n = AppLocalizations.of(context)!;
    final service = useMemoized(() => CalendarExportService());
    final includeExams = useState(true);
    final reminder = useState(15);
    final busy = useState(false);
    final file = useState<File?>(null);
    final failure = useState<String?>(null);
    final source = useAsyncData(
      () => service.load(
        account: ApiClient.instance.studentId ?? '',
        preferredTerm: settings.selectedSemesterKey.value,
        useWest2Adjustments: settings.useWest2Adjustments,
      ),
    );
    final data = source.data;
    final termId = data?.term.term ?? '';
    final termMatch = RegExp(r'^(\d{4})(\d{2})$').firstMatch(termId);
    final termLabel = termMatch == null
        ? termId
        : l10n.academicYearTerm(
            termMatch[1]!,
            '${int.parse(termMatch[1]!) + 1}',
            '${int.parse(termMatch[2]!)}',
          );
    CalendarExport? result;
    String? buildError;
    try {
      if (data != null) {
        result = CalendarExport.build(
          account: data.account,
          term: data.term,
          courses: data.courses,
          hiddenSessions: settings.hiddenCourseSessions.value,
          autoAdjust: settings.autoAdjustCourse.value,
          includeExams: includeExams.value,
          reminderMinutes: reminder.value,
          calendarName: '${l10n.appName} $termLabel',
          generatedAt: DateTime.now(),
        );
      }
    } catch (error) {
      buildError = l10n.loadingFailed(error.toString());
    }
    Future<void> action(Future<void> Function() run) async {
      if (busy.value) return;
      busy.value = true;
      failure.value = null;
      try {
        await run();
      } catch (error) {
        if (context.mounted) {
          failure.value = l10n.loadingFailed(error.toString());
        }
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.calendarExport)),
      body: ToolPageWrapper(
        loading: source.loading,
        error: source.error ?? buildError,
        hasData: data != null && result != null,
        emptyText: l10n.calendarExportMissingData,
        onRefresh: source.refresh,
        refreshTime: data?.updatedAt,
        child: AppListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              title: Text(l10n.calendarExportDescription),
              subtitle: Text(l10n.calendarExportSnapshot),
            ),
            if (data != null && result != null) ...[
              SettingsSection(
                title: l10n.settingsExportSection,
                child: Column(
                  children: [
                    ListTile(
                      title: Text(termLabel),
                      subtitle: Text(
                        l10n.calendarExportEventCount(result.eventCount),
                      ),
                    ),
                    SettingSwitchTile.controlled(
                      title: Text(l10n.calendarExportIncludeExams),
                      value: includeExams.value,
                      onChanged: busy.value
                          ? null
                          : (value) {
                              includeExams.value = value;
                              file.value = null;
                            },
                    ),
                    ChevronListTile(
                      title: Text(l10n.calendarExportReminder),
                      subtitle: Text(
                        reminder.value == 0
                            ? l10n.calendarExportNoReminder
                            : l10n.calendarExportReminderMinutes(
                                reminder.value,
                              ),
                      ),
                      onTap: busy.value
                          ? null
                          : () async {
                              final value = await showSettingsChoiceSheet<int>(
                                context: context,
                                title: l10n.calendarExportReminder,
                                selected: reminder.value,
                                choices: [
                                  for (final minutes in [0, 5, 15, 30])
                                    SettingsChoice(
                                      value: minutes,
                                      label: minutes == 0
                                          ? l10n.calendarExportNoReminder
                                          : l10n.calendarExportReminderMinutes(
                                              minutes,
                                            ),
                                    ),
                                ],
                              );
                              if (value == null || !context.mounted) return;
                              reminder.value = value;
                              file.value = null;
                            },
                    ),
                    if (result.skippedExams > 0)
                      ListTile(
                        subtitle: Text(
                          l10n.calendarExportSkippedExams(result.skippedExams),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SettingsActionButton(
                        busy: busy.value,
                        onPressed: busy.value || result.eventCount == 0
                            ? null
                            : () => action(() async {
                                final saved = await service.save(result!, data);
                                if (context.mounted) file.value = saved;
                              }),
                        icon: Icons.calendar_month_outlined,
                        label: busy.value
                            ? l10n.calendarExportBusy
                            : l10n.calendarExportSave,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (file.value case final saved?) ...[
              ListTile(
                title: Text(l10n.calendarExportSaved),
                subtitle: SelectableText(saved.path),
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(l10n.papersOpenFile),
                onTap: busy.value
                    ? null
                    : () => action(() async {
                        final opened = Platform.isAndroid || Platform.isIOS
                            ? (await OpenFilex.open(saved.path)).type ==
                                  ResultType.done
                            : await launchUrl(
                                Uri.file(saved.path),
                                mode: LaunchMode.externalApplication,
                              );
                        if (!opened) throw StateError(l10n.papersOpenFailed);
                      }),
              ),
              if (!Platform.isLinux)
                Builder(
                  builder: (buttonContext) => ListTile(
                    leading: const Icon(Icons.share_outlined),
                    title: Text(l10n.papersShareFile),
                    onTap: busy.value
                        ? null
                        : () => action(() async {
                            final box =
                                buttonContext.findRenderObject() as RenderBox?;
                            await SharePlus.instance.share(
                              ShareParams(
                                files: [
                                  XFile(saved.path, mimeType: 'text/calendar'),
                                ],
                                sharePositionOrigin: box == null
                                    ? null
                                    : box.localToGlobal(Offset.zero) & box.size,
                              ),
                            );
                          }),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: Text(l10n.papersCopyLocalPath),
                onTap: () => Clipboard.setData(ClipboardData(text: saved.path)),
              ),
            ],
            if (failure.value != null)
              ListTile(
                title: Text(
                  failure.value!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
