import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/course_sessions.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';
import 'package:fzu_assistant/common/widget/layout/app_scroll_view.dart';
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
    final loaded = useState(false);
    final operationFailed = useState(false);
    final failed = useValueListenable(service.error);
    final snapshot = useValueListenable(service.snapshot);
    final syncEnabled = useValueListenable(syncService.enabled);
    final syncMinutes = useValueListenable(syncService.minutes);
    final syncStatus = useValueListenable(syncService.status);
    final selection = snapshot?.select(DateTime.now().toUtc());
    final missing = selection?.state == NextCourseWidgetState.unknown;
    final working = busy.value || syncStatus.running;

    Future<void> reload() async {
      if (!NextCourseWidgetService.supported) return;
      try {
        await syncService.load();
        await syncService.reconcile();
        if (context.mounted) {
          loaded.value = true;
          operationFailed.value = false;
        }
      } catch (_) {
        if (context.mounted) operationFailed.value = true;
      }
    }

    Future<void> run(Future<void> Function() action) async {
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

    Future<void> update({bool pin = false}) => run(() async {
      String? message;
      try {
        final refreshed = pin || await syncService.refreshNow();
        await service.sync(settings);
        message = pin
            ? await service.requestPin(variant: variant.value)
                  ? null
                  : l10n.nextCourseWidgetPinUnavailable
            : !refreshed
            ? l10n.widgetSyncFailed
            : service.error.value
            ? l10n.nextCourseWidgetFailed
            : l10n.nextCourseWidgetUpdated;
      } catch (_) {
        message = pin ? l10n.nextCourseWidgetFailed : l10n.widgetSyncFailed;
        if (context.mounted) operationFailed.value = true;
      }
      if (context.mounted && message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    });

    useEffect(() {
      unawaited(reload());
      return null;
    }, []);
    useOnAppLifecycleStateChange((_, state) {
      if (state == AppLifecycleState.resumed) unawaited(reload());
    });

    String beijingDateTime(DateTime instant) {
      final beijing = instant.toUtc().add(
        NextCourseWidgetSnapshot.beijingOffset,
      );
      final date = MaterialLocalizations.of(context).formatMediumDate(beijing);
      final time = TimeOfDay.fromDateTime(beijing).format(context);
      return l10n.reminderBeijingTime('$date $time');
    }

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.nextCourseWidgetSettings)),
      body: AppListView(
        children: [
          ListTile(
            title: Text(l10n.nextCourseWidgetDescription),
            subtitle: Text(l10n.nextCourseWidgetPrivacy),
          ),
          if (!NextCourseWidgetService.supported)
            ListTile(title: Text(l10n.nextCourseWidgetUnsupported))
          else ...[
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
              onTap: working ? null : () => update(pin: true),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(l10n.nextCourseWidgetRefresh),
              subtitle: Text(l10n.nextCourseWidgetRefreshDescription),
              trailing: working
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: working ? null : update,
            ),
            if (missing)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.nextCourseWidgetMissing),
              ),
            if (failed)
              ListTile(
                title: Text(l10n.nextCourseWidgetFailed),
                trailing: TextButton(
                  onPressed: working ? null : update,
                  child: Text(l10n.retry),
                ),
              ),
            const Divider(),
            SwitchListTile(
              title: Text(l10n.widgetSyncEnabled),
              subtitle: Text(l10n.widgetSyncDescription),
              value: syncEnabled,
              onChanged: !loaded.value || working
                  ? null
                  : (value) => run(() => syncService.configure(enabled: value)),
            ),
            ListTile(
              title: Text(l10n.widgetSyncTime),
              subtitle: Text(
                l10n.reminderBeijingTime(
                  TimeOfDay(
                    hour: syncMinutes ~/ 60,
                    minute: syncMinutes % 60,
                  ).format(context),
                ),
              ),
              trailing: const Icon(Icons.schedule),
              onTap: !loaded.value || working || !syncEnabled
                  ? null
                  : () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: syncMinutes ~/ 60,
                          minute: syncMinutes % 60,
                        ),
                      );
                      if (time == null || !context.mounted) return;
                      await run(
                        () => syncService.configure(
                          minutes: time.hour * 60 + time.minute,
                        ),
                      );
                    },
            ),
            ListTile(
              title: Text(l10n.reminderExactPermission),
              subtitle: Text(
                !loaded.value
                    ? l10n.reminderPermissionLoading
                    : syncStatus.exactAllowed
                    ? l10n.reminderPermissionGranted
                    : l10n.reminderPermissionDenied,
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: working
                  ? null
                  : () => run(() async {
                      await syncService.requestExactPermission();
                      await reload();
                    }),
            ),
            ListTile(
              title: Text(l10n.widgetSyncLastSuccess),
              subtitle: Text(
                syncStatus.lastSuccess == null
                    ? l10n.widgetSyncNever
                    : beijingDateTime(syncStatus.lastSuccess!),
              ),
            ),
            if (syncEnabled && syncStatus.nextAt != null)
              ListTile(
                title: Text(l10n.widgetSyncNext),
                subtitle: Text(beijingDateTime(syncStatus.nextAt!)),
              ),
            if (syncStatus.failed || operationFailed.value)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.widgetSyncFailed),
                trailing: TextButton(
                  onPressed: working ? null : update,
                  child: Text(l10n.retry),
                ),
              ),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
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
                          ? Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      status,
                                      const SizedBox(height: 8),
                                      courseName,
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    startTime,
                                    const SizedBox(height: 4),
                                    startDate,
                                  ],
                                ),
                              ],
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
