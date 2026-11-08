import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/course_sessions.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/next_course_widget.dart';
import 'package:fzu_assistant/service/next_course_widget_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/widget_sync_service.dart';

class NextCourseWidgetSettingsPage extends HookWidget {
  const NextCourseWidgetSettingsPage({
    super.key,
    this.widgetService,
    this.syncService,
  });

  final NextCourseWidgetService? widgetService;
  final WidgetSyncService? syncService;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = AppSettingsProvider.of(context);
    final service = widgetService ?? NextCourseWidgetService.instance;
    final syncService = this.syncService ?? WidgetSyncService.instance;
    final variant = useState(NextCourseWidgetVariant.square);
    final busy = useState(false);
    final operationFailed = useState(false);
    final failed = useValueListenable(service.error);
    final snapshot = useValueListenable(service.snapshot);
    final syncStatus = useValueListenable(syncService.status);
    final selection = snapshot?.select(DateTime.now().toUtc());
    final missing = selection?.state == NextCourseWidgetState.unknown;
    final working = busy.value || syncStatus.running;

    Future<void> run(Future<void> Function() action) async {
      if (busy.value || syncService.status.value.running) return;
      busy.value = true;
      operationFailed.value = false;
      try {
        await action();
      } catch (_) {
        if (context.mounted) operationFailed.value = true;
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    Future<void> addWidget() => run(() async {
      final choice = variant.value;
      String message;
      try {
        await service.sync(settings);
        if (!context.mounted) return;
        message = await service.requestPin(variant: choice)
            ? l10n.nextCourseWidgetPinRequested
            : l10n.nextCourseWidgetPinUnavailable;
      } catch (_) {
        message = l10n.nextCourseWidgetPinFailed;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    });

    Future<void> openPinSettings() => run(() async {
      try {
        await service.openPinSettings();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.permissionSettingsFailed)),
          );
        }
      }
    });

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.nextCourseWidgetSettings)),
      body: AppListView(
        children: [
          if (!NextCourseWidgetService.supported)
            ListTile(title: Text(l10n.nextCourseWidgetUnsupported))
          else ...[
            SettingsSection.list(
              title: l10n.nextCourseWidgetAdd,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final choice in NextCourseWidgetVariant.values)
                        ChoiceChip(
                          key: ValueKey('widget-variant-${choice.name}'),
                          label: Text(_variantTitle(choice, l10n)),
                          selected: variant.value == choice,
                          showCheckmark: false,
                          onSelected: working
                              ? null
                              : (_) => variant.value = choice,
                        ),
                    ],
                  ),
                ),
                _WidgetPreview(
                  variant: variant.value,
                  snapshot: snapshot,
                  selection: selection,
                ),
                ListTile(
                  leading: const Icon(Icons.add_to_home_screen_outlined),
                  title: Text(
                    l10n.widgetAddVariant(_variantTitle(variant.value, l10n)),
                  ),
                  subtitle: Text(l10n.nextCourseWidgetAddDescription),
                  trailing: const Icon(Icons.add),
                  onTap: working ? null : addWidget,
                ),
              ],
            ),
            AppInfoCard(
              title: Text(l10n.nextCourseWidgetPinGuidance),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.nextCourseWidgetPinPermissionHint),
                  TextButton(
                    onPressed: working ? null : openPinSettings,
                    child: Text(l10n.nextCourseWidgetPinSettings),
                  ),
                ],
              ),
            ),
            if (missing || failed || operationFailed.value) ...[
              const SettingsDivider(),
              SettingsSection.list(
                title: l10n.settingsSyncSection,
                children: [
                  if (missing)
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(l10n.nextCourseWidgetMissing),
                    ),
                  if (failed || operationFailed.value)
                    ListTile(
                      title: Text(l10n.nextCourseWidgetFailed),
                      trailing: TextButton(
                        onPressed: working
                            ? null
                            : () => run(() => service.sync(settings)),
                        child: Text(l10n.retry),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

String _variantTitle(NextCourseWidgetVariant variant, AppLocalizations l10n) =>
    switch (variant) {
      NextCourseWidgetVariant.compact => l10n.widgetVariantCompact,
      NextCourseWidgetVariant.square => l10n.widgetVariantSquare,
      NextCourseWidgetVariant.timetable => l10n.widgetVariantTimetable,
    };

/// Material 3 preview uses the same semantic surface/container roles as the
/// native widgets. It renders local data only; selecting a size never logs in.
class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview({
    required this.variant,
    required this.snapshot,
    required this.selection,
  });

  final NextCourseWidgetVariant variant;
  final NextCourseWidgetSnapshot? snapshot;
  final NextCourseWidgetSelection? selection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final timetable = variant == NextCourseWidgetVariant.timetable;
    final compact = variant == NextCourseWidgetVariant.compact;
    final square = variant == NextCourseWidgetVariant.square;
    final course = selection?.courses.firstOrNull;
    final width = compact
        ? 288.0
        : square
        ? 184.0
        : 320.0;
    final ratio = compact ? 2.0 : 1.0;
    String time(DateTime instant) {
      final value = instant.toUtc().add(NextCourseWidgetSnapshot.beijingOffset);
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }

    final status = Text(
      selection?.state == NextCourseWidgetState.inProgress
          ? l10n.widgetInProgress
          : l10n.widgetNextClass,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text.labelMedium?.copyWith(color: colors.onSurfaceVariant),
    );
    final startTime = Text(
      course == null ? '—' : time(course.start),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text.headlineSmall?.copyWith(color: colors.primary),
    );
    final beijingStart = course?.start.toUtc().add(
      NextCourseWidgetSnapshot.beijingOffset,
    );
    final startDate = Text(
      beijingStart == null
          ? '—'
          : '${beijingStart.month.toString().padLeft(2, '0')}-${beijingStart.day.toString().padLeft(2, '0')}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
    );
    final courseName = Text(
      course?.name ?? l10n.noScheduleData,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: text.titleMedium,
    );

    return Padding(
      // Compact previews need the section's full width at large text sizes.
      // The preview surface already supplies its own horizontal content inset.
      padding: EdgeInsets.fromLTRB(compact ? 0 : 16, 20, compact ? 0 : 16, 8),
      child: Column(
        children: [
          Text(
            l10n.widgetPreview,
            style: text.labelLarge?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: width,
              child: LayoutBuilder(
                builder: (context, constraints) => ConstrainedBox(
                  // Preserve the launcher proportions unless scaled text needs
                  // more vertical room to keep the course details readable.
                  constraints: BoxConstraints(
                    minHeight: constraints.maxWidth / ratio,
                  ),
                  child: DecoratedBox(
                    key: ValueKey('widget-preview-${variant.name}'),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 12 : 16),
                      child: timetable
                          ? SizedBox(
                              height: constraints.maxWidth - 32,
                              child: _TimetablePreview(snapshot: snapshot),
                            )
                          : compact
                          ? LayoutBuilder(
                              builder: (context, constraints) {
                                // Keep room for both the course and the clock.
                                // Reflow instead of reducing accessibility text.
                                final sideBySide =
                                    constraints.maxWidth >=
                                    MediaQuery.textScalerOf(context).scale(264);
                                final details = Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    sideBySide
                                        ? status
                                        : Text(
                                            status.data!,
                                            style: status.style,
                                          ),
                                    const SizedBox(height: 8),
                                    sideBySide
                                        ? courseName
                                        : Text(
                                            courseName.data!,
                                            style: courseName.style,
                                          ),
                                  ],
                                );
                                final clock = Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: sideBySide
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    startTime,
                                    const SizedBox(height: 4),
                                    startDate,
                                  ],
                                );
                                return sideBySide
                                    ? Row(
                                        children: [
                                          Expanded(child: details),
                                          const SizedBox(width: 12),
                                          clock,
                                        ],
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          details,
                                          const SizedBox(height: 12),
                                          clock,
                                        ],
                                      );
                              },
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                status,
                                const SizedBox(height: 8),
                                startTime,
                                const SizedBox(height: 4),
                                courseName,
                                if (course != null &&
                                    course.location.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    course.location,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimetablePreview extends StatelessWidget {
  const _TimetablePreview({required this.snapshot});

  final NextCourseWidgetSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final days = snapshot?.days.take(7).toList() ?? [];
    final labels = [
      l10n.monday,
      l10n.tuesday,
      l10n.wednesday,
      l10n.thursday,
      l10n.friday,
      l10n.saturday,
      l10n.sunday,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.widgetWeeklyTimetable, style: text.titleMedium),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < 7; index++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      children: [
                        Text(
                          labels[index],
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: text.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: days.length <= index || !days[index].known
                              ? Center(
                                  child: Text(
                                    '—',
                                    style: text.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) => Stack(
                                    children: [
                                      for (final course in days[index].courses)
                                        Positioned(
                                          top:
                                              (course.startClass - 1) /
                                              maxCoursePeriod *
                                              constraints.maxHeight,
                                          height:
                                              (course.endClass -
                                                  course.startClass +
                                                  1) /
                                              maxCoursePeriod *
                                              constraints.maxHeight,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 2,
                                            ),
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: colors.primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              course.name,
                                              overflow: TextOverflow.fade,
                                              style: text.labelSmall?.copyWith(
                                                color:
                                                    colors.onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
