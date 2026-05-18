import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/common/tool_page_wrapper.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';

class CalendarPage extends HookWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final calendar = useState<SchoolCalendar?>(null);
    final loading = useState(true);
    final error = useState<String?>(null);
    final refreshTime = useState<DateTime?>(null);
    final expandedIds = useState<Set<String>>({});
    final eventsMap = useState<Map<String, CalTermEvents>>({});
    final eventsLoadingMap = useState<Map<String, bool>>({});
    final eventsErrorMap = useState<Map<String, String>>({});
    final service = useMemoized(() => AcademicService());
    final mounted = useRef(true);
    useEffect(
      () => () {
        mounted.value = false;
      },
      [],
    );

    Future<void> load() async {
      try {
        calendar.value = await service.getSchoolCalendar();
        if (!mounted.value) return;
        refreshTime.value = DateTime.now();
        error.value = null;
      } catch (e) {
        if (!mounted.value) return;
        error.value = e.toString();
      }
      if (mounted.value) loading.value = false;
    }

    useEffect(() {
      load();
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.calendar)),
      body: ToolPageWrapper(
        onRefresh: load,
        loading: loading.value,
        error: error.value,
        refreshTime: refreshTime.value,
        hasData: calendar.value != null && calendar.value!.terms.isNotEmpty,
        emptyText: AppLocalizations.of(context)!.noCalendarData,
        child: calendar.value != null
            ? _buildContent(
                calendar.value!,
                service,
                expandedIds,
                eventsMap,
                eventsLoadingMap,
                eventsErrorMap,
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Future<void> _loadEvents(
    String termId,
    AcademicService service,
    ValueNotifier<Map<String, CalTermEvents>> eventsMap,
    ValueNotifier<Map<String, bool>> loadingMap,
    ValueNotifier<Map<String, String>> errorMap,
  ) async {
    if (eventsMap.value.containsKey(termId)) return;
    loadingMap.value = {...loadingMap.value, termId: true};
    try {
      final data = await service.getTermEvents(termId);
      eventsMap.value = {...eventsMap.value, termId: data};
    } catch (e) {
      errorMap.value = {...errorMap.value, termId: e.toString()};
    }
    loadingMap.value = {...loadingMap.value, termId: false};
  }

  Widget _buildContent(
    SchoolCalendar cal,
    AcademicService service,
    ValueNotifier<Set<String>> expandedIds,
    ValueNotifier<Map<String, CalTermEvents>> eventsMap,
    ValueNotifier<Map<String, bool>> loadingMap,
    ValueNotifier<Map<String, String>> errorMap,
  ) {
    return ListView.builder(
      itemCount: cal.terms.length,
      itemBuilder: (context, i) {
        final t = cal.terms[i];
        final isCurrent = t.termId == cal.currentTerm;
        return _TermCard(
          term: t,
          isCurrent: isCurrent,
          expanded: expandedIds.value.contains(t.termId),
          events: eventsMap.value[t.termId],
          eventsLoading: loadingMap.value[t.termId] ?? false,
          eventsError: errorMap.value[t.termId],
          onExpansionChanged: (open) {
            final next = Set<String>.of(expandedIds.value);
            if (open) {
              next.add(t.termId);
              _loadEvents(t.termId, service, eventsMap, loadingMap, errorMap);
            } else {
              next.remove(t.termId);
            }
            expandedIds.value = next;
          },
        );
      },
    );
  }
}

class _TermCard extends StatelessWidget {
  final CalTerm term;
  final bool isCurrent;
  final bool expanded;
  final CalTermEvents? events;
  final bool eventsLoading;
  final String? eventsError;
  final ValueChanged<bool> onExpansionChanged;

  const _TermCard({
    required this.term,
    required this.isCurrent,
    required this.expanded,
    required this.events,
    required this.eventsLoading,
    required this.eventsError,
    required this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey(term.termId),
        initiallyExpanded: expanded,
        shape: const Border(),
        collapsedShape: const Border(),
        onExpansionChanged: onExpansionChanged,
        title: Row(
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.academicYearTerm(
                  term.schoolYear,
                  '${int.parse(term.schoolYear) + 1}',
                  term.term.substring(4, 6),
                ),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  AppLocalizations.of(context)!.current,
                  style: const TextStyle(fontSize: 11, color: Colors.green),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                '${term.startDate} ～ ${term.endDate}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        children: [
          if (eventsLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (eventsError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocalizations.of(context)!.loadingFailed(eventsError ?? ''),
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            )
          else if (events != null && events!.events.isNotEmpty)
            _EventsTable(events: events!.events)
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocalizations.of(context)!.noScheduleEvents,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}

class _EventsTable extends StatelessWidget {
  final List<CalTermEvent> events;

  const _EventsTable({required this.events});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Table(
        columnWidths: const {
          0: IntrinsicColumnWidth(),
          1: FixedColumnWidth(12),
          2: FlexColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: events.map((e) {
          final hasDate = e.startDate.isNotEmpty;
          final dateText = hasDate
              ? (e.startDate == e.endDate
                    ? e.startDate
                    : '${e.startDate} ～ ${e.endDate}')
              : '';
          return TableRow(
            children: [
              Text(
                dateText,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(e.name, style: const TextStyle(fontSize: 14)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
