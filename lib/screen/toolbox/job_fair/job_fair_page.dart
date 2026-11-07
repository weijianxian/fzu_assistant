import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/job_fair.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/api/job_fair_service.dart';
import 'package:intl/intl.dart';

class JobFairPage extends HookWidget {
  const JobFairPage({super.key, this.service, this.now});

  final JobFairService? service;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final clock = now ?? DateTime.now;
    final time = useState(clock());
    final selectedMonth = useState(JobFairMonth.fromInstant(time.value));
    final client = useMemoized(() => service ?? JobFairService(), [service]);
    final data = useState<JobFairMonthData?>(null);
    final loading = useState(true);
    final failed = useState(false);
    final refreshTime = useState<DateTime?>(null);
    final serial = useRef(0);
    final locale = Localizations.localeOf(context).toString();
    final scrollController = useScrollController();

    Future<void> load() async {
      final request = ++serial.value;
      final month = selectedMonth.value;
      bool isLatest() =>
          context.mounted &&
          request == serial.value &&
          selectedMonth.value == month;
      loading.value = true;
      failed.value = false;
      try {
        final result = await client.getMonth(month);
        if (!isLatest()) return;
        data.value = result;
        refreshTime.value = clock();
        time.value = clock();
      } catch (_) {
        if (isLatest()) failed.value = true;
      } finally {
        if (isLatest()) loading.value = false;
      }
    }

    useEffect(() {
      return () {
        serial.value++;
        if (service == null) client.close();
      };
    }, [client]);

    useEffect(() {
      load();
      final month = selectedMonth.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted &&
            selectedMonth.value == month &&
            scrollController.hasClients) {
          scrollController.jumpTo(0);
        }
      });
      return null;
    }, [client, selectedMonth.value]);

    useEffect(() {
      final timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (context.mounted) time.value = clock();
      });
      return timer.cancel;
    }, [clock]);

    final result = data.value;
    final previousMonthShown =
        result != null && result.month != selectedMonth.value;
    final groups = result?.groupsAt(time.value);
    final theme = Theme.of(context);
    final currentMonth = JobFairMonth.fromInstant(time.value);

    Future<void> chooseMonth() async {
      final month = await showDialog<JobFairMonth>(
        context: context,
        builder: (_) => _MonthPicker(initialMonth: selectedMonth.value),
      );
      if (context.mounted && month != null) selectedMonth.value = month;
    }

    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.jobFairTitle),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: loading.value ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: l10n.jobFairPreviousMonth,
                      onPressed:
                          selectedMonth.value.year == 1 &&
                              selectedMonth.value.month == 1
                          ? null
                          : () => selectedMonth.value = selectedMonth.value
                                .shift(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: chooseMonth,
                        child: Tooltip(
                          message: l10n.jobFairSelectMonth,
                          child: Text(
                            DateFormat.yMMMM(locale)
                                .format(selectedMonth.value.calendarDate),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.jobFairNextMonth,
                      onPressed:
                          selectedMonth.value.year == 9999 &&
                              selectedMonth.value.month == 12
                          ? null
                          : () => selectedMonth.value = selectedMonth.value
                                .shift(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    IconButton(
                      tooltip: l10n.jobFairCurrentMonth,
                      onPressed: selectedMonth.value == currentMonth
                          ? null
                          : () => selectedMonth.value = currentMonth,
                      icon: const Icon(Icons.today_outlined),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    l10n.jobFairDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (loading.value && result != null)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ToolPageWrapper(
              onRefresh: load,
              loading: loading.value && result == null,
              refreshTime: refreshTime.value,
              emptyText: l10n.jobFairNoEvents,
              scrollController: scrollController,
              slivers: [
                if (failed.value)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              previousMonthShown
                                  ? l10n.jobFairShowingPreviousMonth
                                  : result == null
                                  ? l10n.jobFairLoadFailed
                                  : l10n.jobFairRefreshFailed,
                            ),
                          ),
                          TextButton(onPressed: load, child: Text(l10n.retry)),
                        ],
                      ),
                    ),
                  ),
                if (previousMonthShown)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        DateFormat.yMMMM(locale)
                            .format(result.month.calendarDate),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                if (result != null && result.skippedCount > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        l10n.jobFairPartialData,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                if (result != null && result.events.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text(l10n.jobFairNoEvents)),
                  ),
                if (groups != null) ...[
                  ..._eventSlivers(
                    context,
                    l10n.jobFairUpcoming,
                    groups.upcoming,
                    locale,
                  ),
                  ..._eventSlivers(
                    context,
                    l10n.jobFairPast,
                    groups.past,
                    locale,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _eventSlivers(
    BuildContext context,
    String heading,
    List<JobFair> events,
    String locale,
  ) {
    if (events.isEmpty) return [];
    final theme = Theme.of(context);
    final byDate = <DateTime, List<JobFair>>{};
    for (final event in events) {
      final start = event.beijingStart;
      final day = DateTime.utc(start.year, start.month, start.day);
      byDate.putIfAbsent(day, () => []).add(event);
    }
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(heading, style: theme.textTheme.titleMedium),
        ),
      ),
      for (final entry in byDate.entries) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              DateFormat.yMMMEd(locale).format(entry.key),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        AppSliverList(
          itemCount: entry.value.length,
          itemBuilder: (context, index) =>
              _JobFairTile(event: entry.value[index]),
        ),
      ],
    ];
  }
}

class _JobFairTile extends StatelessWidget {
  const _JobFairTile({required this.event});
  final JobFair event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final title = event.title.isEmpty ? l10n.jobFairUnknownTitle : event.title;
    final place = event.place.isEmpty ? l10n.jobFairUnknownPlace : event.place;
    final type = event.type == JobFairType.careerTalk
        ? l10n.jobFairKeynote
        : l10n.jobFairRecruitment;
    return ListTile(
      key: ValueKey('job-fair-${event.type.name}-${event.id}'),
      leading: Text(
        DateFormat.Hm().format(event.beijingStart),
        style: theme.textTheme.titleSmall?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      title: Text(title, maxLines: 3, overflow: TextOverflow.ellipsis),
      subtitle: Text('$type · $place'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        final uri = event.detailUri;
        if (uri == null || !JobFair.isOfficialDetailUri(uri)) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.jobFairInvalidDetails)));
          return;
        }
        context.pushNamed(
          AppRoutes.webview,
          arguments: WebViewArgs(
            url: uri.toString(),
            title: title,
            injectCookies: false,
          ),
        );
      },
    );
  }
}

class _MonthPicker extends HookWidget {
  const _MonthPicker({required this.initialMonth});
  final JobFairMonth initialMonth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    final year = useState(initialMonth.year);
    final locale = Localizations.localeOf(context).toString();
    return AlertDialog(
      title: Text(l10n.jobFairSelectMonth),
      content: SizedBox(
        width: 304,
        child: AppSingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: material.previousPageTooltip,
                    onPressed: year.value <= 1 ? null : () => year.value--,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat.y(locale).format(DateTime.utc(year.value)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    tooltip: material.nextPageTooltip,
                    onPressed: year.value >= 9999 ? null : () => year.value++,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (var month = 1; month <= 12; month++)
                    SizedBox(
                      width: 88,
                      child: TextButton(
                        onPressed: () =>
                            Navigator.of(context)
                                .pop(JobFairMonth(year.value, month)),
                        style:
                            initialMonth.year == year.value &&
                                initialMonth.month == month
                            ? TextButton.styleFrom(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              )
                            : null,
                        child: Text(
                          DateFormat.MMM(locale)
                              .format(DateTime.utc(year.value, month)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.cancelButtonLabel),
        ),
      ],
    );
  }
}
