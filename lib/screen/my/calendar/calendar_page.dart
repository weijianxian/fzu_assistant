import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/common/tool_page_wrapper.dart';
import 'package:fzu_assistant/service/academic_service.dart';

class CalendarPage extends HookWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final calendar = useState<SchoolCalendar?>(null);
    final loading = useState(true);
    final error = useState<String?>(null);
    final refreshTime = useState<DateTime?>(null);
    final service = useMemoized(() => AcademicService());
    final mounted = useRef(true);
    useEffect(() => () { mounted.value = false; }, []);

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
            ? _buildContent(calendar.value!, service)
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildContent(SchoolCalendar cal, AcademicService service) {
    return ListView.builder(
      itemCount: cal.terms.length,
      itemBuilder: (context, i) {
        final t = cal.terms[i];
        final isCurrent = t.termId == cal.currentTerm;
        return _TermCard(term: t, isCurrent: isCurrent, service: service);
      },
    );
  }
}

class _TermCard extends HookWidget {
  final CalTerm term;
  final bool isCurrent;
  final AcademicService service;

  const _TermCard({
    required this.term,
    required this.isCurrent,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final events = useState<CalTermEvents?>(null);
    final eventsLoading = useState(false);
    final eventsError = useState<String?>(null);
    final expanded = useState(false);

    Future<void> loadEvents() async {
      if (events.value != null) return;
      eventsLoading.value = true;
      try {
        events.value = await service.getTermEvents(term.termId);
      } catch (e) {
        eventsError.value = e.toString();
      }
      eventsLoading.value = false;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        onExpansionChanged: (open) {
          expanded.value = open;
          if (open) loadEvents();
        },
        title: Row(
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.academicYearTerm(term.schoolYear, '${int.parse(term.schoolYear) + 1}', term.term.substring(4, 6)),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (isCurrent)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          if (eventsLoading.value)
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
          else if (eventsError.value != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocalizations.of(context)!.loadingFailed(eventsError.value ?? ''),
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            )
          else if (events.value != null && events.value!.events.isNotEmpty)
            _EventsTable(events: events.value!.events)
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
                child: Text(
                  e.name,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
