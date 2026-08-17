import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_mounted.dart';
import 'package:fzu_assistant/common/utils/context_ext.dart';
import 'package:fzu_assistant/common/utils/course_sessions.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/calendar.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/home/timeline_events.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:fzu_assistant/service/api/course_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

class TimelineHomePage extends HookWidget {
  final ValueNotifier<int>? refreshTrigger;

  const TimelineHomePage({super.key, this.refreshTrigger});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final calendar = useState<SchoolCalendar?>(null);
    final term = useState<CalTerm?>(null);
    final events = useState<List<CalTermEvent>>([]);
    final courses = useState<List<Course>>([]);
    final firstMonday = useState<DateTime?>(null);
    final loading = useState(true);
    final error = useState<String?>(null);
    final academic = useMemoized(AcademicService.new);
    final courseService = useMemoized(CourseService.new);
    final mounted = useMounted();
    final refreshSerial = useRef(0);

    Future<void> load({bool useCache = true}) async {
      refreshSerial.value++;
      final serial = refreshSerial.value;
      bool isLatest() => mounted.value && serial == refreshSerial.value;

      loading.value = true;
      error.value = null;
      try {
        final loadedCalendar = await academic.loadOrFetchCalendar(
          useCache: useCache,
        );
        if (!isLatest()) return;
        calendar.value = loadedCalendar;

        final currentTerm = AcademicService.getCurrentTermFromCalendar(
          loadedCalendar,
        );
        final selected = settings.selectedSemesterKey.value;
        final targetTerm = selected.isNotEmpty ? selected : currentTerm;
        final matches = loadedCalendar.terms.where(
          (candidate) => candidate.term == targetTerm,
        );
        if (matches.isEmpty) {
          term.value = null;
          events.value = [];
          courses.value = [];
          firstMonday.value = null;
          return;
        }

        final matchedTerm = matches.first;
        if (term.value?.term != matchedTerm.term) {
          term.value = matchedTerm;
          events.value = [];
          courses.value = [];
          firstMonday.value = null;
        }

        final loadedFirstMonday = CourseService.getFirstMondayFromTerm(
          matchedTerm,
        );
        var loadedEvents = <CalTermEvent>[];
        var loadedCourses = <Course>[];
        await Future.wait([
          () async {
            try {
              final result = await academic.loadOrFetchTermEvents(
                matchedTerm.termId,
                useCache: useCache,
              );
              loadedEvents = result.events;
            } catch (_) {}
          }(),
          () async {
            try {
              loadedCourses = await courseService.getCourses(
                targetTerm,
                useCache: useCache,
              );
            } catch (_) {}
          }(),
        ]);

        if (!isLatest()) return;
        term.value = matchedTerm;
        firstMonday.value = loadedFirstMonday;
        events.value = loadedEvents;
        courses.value = loadedCourses;
      } catch (e) {
        if (isLatest()) error.value = e.toString();
      } finally {
        if (isLatest()) loading.value = false;
      }
    }

    useEffect(() {
      load();
      return null;
    }, []);

    useEffect(() {
      void onSemesterChanged() => load();

      settings.selectedSemesterKey.addListener(onSemesterChanged);
      return () =>
          settings.selectedSemesterKey.removeListener(onSemesterChanged);
    }, []);

    final trigger = refreshTrigger;
    useEffect(() {
      if (trigger == null) return null;
      void onRefreshRequested() => load(useCache: false);

      trigger.addListener(onRefreshRequested);
      return () => trigger.removeListener(onRefreshRequested);
    }, [trigger]);

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: context.isLandscape
            ? null
            : Padding(
                padding: const EdgeInsets.all(4),
                child: Hero(
                  tag: 'app-icon',
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 40,
                    height: 40,
                  ),
                ),
              ),
        title: Text(l10n.navHome),
        actions: [
          const HomeViewToggle(),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.pushNamed(AppRoutes.homeSettings),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          settings.timelineDaysKey,
          settings.autoAdjustCourse,
        ]),
        builder: (_, _) => _TimelineBody(
          calendar: calendar.value,
          term: term.value,
          events: events.value,
          courses: courses.value,
          firstMonday: firstMonday.value,
          timelineDays: settings.timelineDaysKey.value,
          autoAdjustCourse: settings.autoAdjustCourse.value,
          loading: loading.value,
          error: error.value,
          onRetry: () => load(),
          onRefresh: () => load(useCache: false),
        ),
      ),
    );
  }
}

class _TimelineBody extends StatelessWidget {
  final SchoolCalendar? calendar;
  final CalTerm? term;
  final List<CalTermEvent> events;
  final List<Course> courses;
  final DateTime? firstMonday;
  final int timelineDays;
  final bool autoAdjustCourse;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;

  const _TimelineBody({
    required this.calendar,
    required this.term,
    required this.events,
    required this.courses,
    required this.firstMonday,
    required this.timelineDays,
    required this.autoAdjustCourse,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (loading && calendar == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && calendar == null) {
      return _MessageState(
        message: l10n.loadingFailed(error!),
        onRetry: onRetry,
      );
    }
    if (calendar == null || calendar!.terms.isEmpty || term == null) {
      return _MessageState(message: l10n.noCalendarData, onRetry: onRetry);
    }

    final eventGroups = TimelineEvents.split(events);
    final milestones = _buildMilestones(
      context,
      term!,
      eventGroups.dated,
      courses,
      firstMonday,
      timelineDays,
      autoAdjustCourse,
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _SemesterHeader(term: term!, firstMonday: firstMonday),
          ),
          Section.sliver(
            title: l10n.timeline,
            child: SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverList.builder(
                itemCount: milestones.length,
                itemBuilder: (context, index) => _TimelineNode(
                  milestone: milestones[index],
                  first: index == 0,
                  last: index == milestones.length - 1,
                ),
              ),
            ),
          ),
          if (eventGroups.other.isNotEmpty)
            SliverToBoxAdapter(
              child: _OtherEventsCard(events: eventGroups.other),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

List<_Milestone> _buildMilestones(
  BuildContext context,
  CalTerm term,
  List<TimelineEventEntry> events,
  List<Course> courses,
  DateTime? firstMonday,
  int timelineDays,
  bool autoAdjustCourse,
) {
  final l10n = AppLocalizations.of(context)!;
  final scheme = Theme.of(context).colorScheme;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final milestones = <_Milestone>[];
  final termStart = DateTime.tryParse(term.startDate);
  final termEnd = DateTime.tryParse(term.endDate);

  if (termStart != null) {
    milestones.add(
      _Milestone(
        title: l10n.semesterStart,
        start: termStart,
        end: termStart,
        color: scheme.primary,
        sortOrder: 0,
        timeText: _formatDate(termStart),
      ),
    );
  }

  milestones.add(
    _Milestone(
      title: l10n.today,
      start: today,
      end: today,
      color: scheme.primary,
      isToday: true,
      sortOrder: 10,
      timeText: '${_formatDate(today)} · ${_weekdayName(l10n, today.weekday)}',
    ),
  );

  if (firstMonday != null) {
    for (var dayOffset = 0; dayOffset < timelineDays; dayOffset++) {
      final date = today.add(Duration(days: dayOffset));
      final week = CourseService.getScheduleWeekForDate(firstMonday, date);
      if (week == null) continue;
      final sessions = CourseSessions.forDay(
        courses: courses,
        week: week,
        weekday: date.weekday,
        autoAdjust: autoAdjustCourse,
      );
      if (sessions.isEmpty) continue;

      if (dayOffset > 0) {
        milestones.add(
          _Milestone(
            title:
                '${_weekdayName(l10n, date.weekday)} · ${date.month}/${date.day}',
            start: date,
            end: date,
            color: scheme.primary,
            isDayHeader: true,
            sortOrder: 5,
          ),
        );
      }

      for (final session in sessions) {
        final startTime = coursePeriodTimes[session.startClass - 1].$1;
        final endTime = coursePeriodTimes[session.endClass - 1].$2;
        final periodText = session.startClass == session.endClass
            ? l10n.classPeriod(session.startClass)
            : l10n.classPeriodRange(session.startClass, session.endClass);
        milestones.add(
          _Milestone(
            title:
                '${session.adjusted ? l10n.adjustedMark : ''}${session.course.name}',
            start: date,
            end: date,
            color: scheme.primary,
            isCourse: true,
            periodText: periodText,
            timeText: '$startTime-$endTime',
            location: session.location,
            sortOrder: 20 + session.startClass,
          ),
        );
      }
    }
  }

  for (final entry in events) {
    final color = _eventColor(entry.event.name, scheme);
    final suffix = switch (entry.boundary) {
      TimelineEventBoundary.starts => l10n.starts,
      TimelineEventBoundary.ends => l10n.ends,
      TimelineEventBoundary.single => '',
    };
    milestones.add(
      _Milestone(
        title: '${entry.event.name}$suffix',
        start: entry.date,
        end: entry.rangeEnd,
        rangeStart: entry.rangeStart,
        color: color,
        sortOrder: entry.boundary == TimelineEventBoundary.ends ? 41 : 40,
        timeText: entry.rangeStart.isAtSameMomentAs(entry.rangeEnd)
            ? _formatDate(entry.rangeStart)
            : '${_formatDate(entry.rangeStart)} ～ ${_formatDate(entry.rangeEnd)}',
      ),
    );
  }

  if (termEnd != null) {
    milestones.add(
      _Milestone(
        title: l10n.semesterEnd,
        start: termEnd,
        end: termEnd,
        color: scheme.secondary,
        sortOrder: 50,
        timeText: _formatDate(termEnd),
      ),
    );
  }

  milestones.sort((a, b) {
    final byDate = a.start.compareTo(b.start);
    return byDate != 0 ? byDate : a.sortOrder.compareTo(b.sortOrder);
  });
  return milestones;
}

class _Milestone {
  final String title;
  final DateTime start;
  final DateTime end;
  final DateTime? rangeStart;
  final Color color;
  final bool isToday;
  final bool isCourse;
  final bool isDayHeader;
  final String periodText;
  final String timeText;
  final String location;
  final int sortOrder;

  const _Milestone({
    required this.title,
    required this.start,
    required this.end,
    this.rangeStart,
    required this.color,
    this.isToday = false,
    this.isCourse = false,
    this.isDayHeader = false,
    this.periodText = '',
    this.timeText = '',
    this.location = '',
    required this.sortOrder,
  });
}

class _TimelineNode extends StatelessWidget {
  final _Milestone milestone;
  final bool first;
  final bool last;

  const _TimelineNode({
    required this.milestone,
    required this.first,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateUtils.dateOnly(DateTime.now());
    final isPastEvent =
        !milestone.isToday &&
        !milestone.isCourse &&
        !milestone.isDayHeader &&
        milestone.end.isBefore(today);
    final nodeColor = isPastEvent ? scheme.outline : milestone.color;

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 48,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _TimelineRailPainter(
                        color: scheme.outlineVariant,
                        drawTop: !first,
                        drawBottom: !last,
                      ),
                    ),
                    Center(
                      child: _MilestoneDot(
                        milestone: milestone,
                        color: nodeColor,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: milestone.isDayHeader
                    ? _DayHeader(milestone: milestone)
                    : _MilestoneCard(
                        milestone: milestone,
                        isPastEvent: isPastEvent,
                      ),
              ),
            ],
          ),
        ),
        if (!last)
          SizedBox(
            height: 12,
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Center(
                    child: Container(width: 2, color: scheme.outlineVariant),
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
      ],
    );
  }
}

class _TimelineRailPainter extends CustomPainter {
  final Color color;
  final bool drawTop;
  final bool drawBottom;

  const _TimelineRailPainter({
    required this.color,
    required this.drawTop,
    required this.drawBottom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    if (drawTop) canvas.drawLine(Offset(center.dx, 0), center, paint);
    if (drawBottom) {
      canvas.drawLine(center, Offset(center.dx, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_TimelineRailPainter oldDelegate) =>
      color != oldDelegate.color ||
      drawTop != oldDelegate.drawTop ||
      drawBottom != oldDelegate.drawBottom;
}

class _MilestoneDot extends StatelessWidget {
  final _Milestone milestone;
  final Color color;

  const _MilestoneDot({required this.milestone, required this.color});

  @override
  Widget build(BuildContext context) {
    final size = milestone.isToday
        ? 14.0
        : milestone.isDayHeader
        ? 10.0
        : 12.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final _Milestone milestone;

  const _DayHeader({required this.milestone});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 15, color: primary),
          const SizedBox(width: 7),
          Text(
            milestone.title,
            style: TextStyle(color: primary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final _Milestone milestone;
  final bool isPastEvent;

  const _MilestoneCard({required this.milestone, required this.isPastEvent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = isPastEvent ? scheme.outline : scheme.onSurface;
    final subtitle = milestone.isToday
        ? ''
        : milestone.isCourse
        ? milestone.location.isEmpty
              ? milestone.periodText
              : '${milestone.periodText} · ${milestone.location}'
        : milestone.timeText;

    return Card(
      margin: EdgeInsets.zero,
      color: milestone.isToday ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    milestone.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (milestone.isCourse)
                  _Chip(text: milestone.timeText, color: milestone.color)
                else if (!milestone.isToday)
                  _EventStatusChip(milestone: milestone)
                else
                  Icon(Icons.today, color: scheme.onPrimaryContainer),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: milestone.isToday
                      ? scheme.onPrimaryContainer
                      : isPastEvent
                      ? scheme.outline
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (milestone.isToday && milestone.timeText.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                milestone.timeText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventStatusChip extends StatelessWidget {
  final _Milestone milestone;

  const _EventStatusChip({required this.milestone});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final today = DateUtils.dateOnly(DateTime.now());
    final rangeStart = milestone.rangeStart ?? milestone.start;

    if (today.isAfter(milestone.end)) {
      return _Chip(text: l10n.finished, color: scheme.outline);
    }
    if (!today.isBefore(rangeStart)) {
      return _Chip(text: l10n.inProgress, color: Colors.green);
    }
    return _Chip(
      text: l10n.daysLeft(milestone.start.difference(today).inDays),
      color: milestone.color,
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;

  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SemesterHeader extends StatelessWidget {
  final CalTerm term;
  final DateTime? firstMonday;

  const _SemesterHeader({required this.term, required this.firstMonday});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final today = DateUtils.dateOnly(DateTime.now());
    final start = DateTime.tryParse(term.startDate);
    final end = DateTime.tryParse(term.endDate);
    final beforeStart = start != null && today.isBefore(start);
    final afterEnd = end != null && today.isAfter(end);
    final fm = firstMonday;

    final status = beforeStart
        ? l10n.notStarted
        : afterEnd
        ? l10n.finished
        : l10n.weekN(fm == null ? 1 : CourseService.getWeekFromFirstMonday(fm));
    final statusColor = beforeStart
        ? scheme.outline
        : afterEnd
        ? scheme.outline
        : scheme.primary;
    final showProgress = start != null && end != null && !beforeStart;
    final totalDays = start == null || end == null
        ? 1
        : end.difference(start).inDays.clamp(1, 9999);
    final elapsedDays = start == null
        ? 0
        : today.difference(start).inDays.clamp(0, totalDays);
    final progress = showProgress ? elapsedDays / totalDays : 0.0;
    final startYear = int.tryParse(term.schoolYear);
    final termNumber = term.term.length >= 6 ? term.term.substring(4, 6) : '';

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.academicYearTerm(
                      term.schoolYear,
                      startYear == null ? term.schoolYear : '${startYear + 1}',
                      termNumber,
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _Chip(text: status, color: statusColor),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${term.startDate} ～ ${term.endDate}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (showProgress) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: Text(l10n.semesterProgress)),
                  Text('${(progress * 100).round()}%'),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: progress),
            ],
          ],
        ),
      ),
    );
  }
}

class _OtherEventsCard extends StatelessWidget {
  final List<CalTermEvent> events;

  const _OtherEventsCard({required this.events});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.otherEvents,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final event in events)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_note_outlined),
                  title: Text(event.name),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _MessageState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}

Color _eventColor(String name, ColorScheme scheme) {
  if (_containsAny(name, ['考试', '测试', '考核', '答辩'])) {
    return Colors.deepOrange;
  }
  if (_containsAny(name, [
    '放假',
    '假期',
    '节日',
    '元旦',
    '春节',
    '清明',
    '劳动',
    '端午',
    '中秋',
    '国庆',
  ])) {
    return Colors.teal;
  }
  if (_containsAny(name, ['开学', '报到', '注册'])) {
    return scheme.primary;
  }
  if (_containsAny(name, ['补课', '调课', '调休', '补休'])) {
    return Colors.blue;
  }
  if (_containsAny(name, ['报名', '选课', '评教', '评议'])) {
    return Colors.indigo;
  }
  if (_containsAny(name, ['运动', '校庆', '活动'])) {
    return Colors.amber;
  }
  if (_containsAny(name, ['毕业', '学位'])) {
    return Colors.purple;
  }
  if (_containsAny(name, ['补考', '缓考', '重修'])) {
    return Colors.brown;
  }
  return Colors.blueGrey;
}

bool _containsAny(String value, List<String> keywords) =>
    keywords.any(value.contains);

String _weekdayName(AppLocalizations l10n, int weekday) => switch (weekday) {
  DateTime.monday => l10n.monday,
  DateTime.tuesday => l10n.tuesday,
  DateTime.wednesday => l10n.wednesday,
  DateTime.thursday => l10n.thursday,
  DateTime.friday => l10n.friday,
  DateTime.saturday => l10n.saturday,
  _ => l10n.sunday,
};

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
