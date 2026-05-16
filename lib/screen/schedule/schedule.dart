import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/service/course_service.dart';

const _maxPeriod = 11;
const _headerHeight = 48.0;

List<String> _weekdays(AppLocalizations l10n) => [
  l10n.monday, l10n.tuesday, l10n.wednesday, l10n.thursday,
  l10n.friday, l10n.saturday, l10n.sunday,
];
const _labelWidth = 44.0;
const _minCellHeight = 52.0;
const _totalWeeks = 19;

const _timeSlots = [
  ('8:20', '9:05'),
  ('9:15', '10:00'),
  ('10:20', '11:05'),
  ('11:15', '12:00'),
  ('14:00', '14:45'),
  ('14:55', '15:40'),
  ('15:50', '16:35'),
  ('16:45', '17:30'),
  ('19:00', '19:45'),
  ('19:55', '20:40'),
  ('20:50', '21:35'),
];

class SchedulePage extends HookWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    final courses = useState<List<Course>>([]);
    final currentWeek = useState<int>(1);
    final displayWeek = useState<int>(1);
    final firstMonday = useState<DateTime?>(null);
    final loading = useState(true);
    final error = useState<String?>(null);
    final service = useMemoized(() => CourseService());
    final pageController = useState<PageController?>(null);

    // 加载缓存 → 创建 PageController → 刷新 API
    useEffect(() {
      () async {
        // 1. 读缓存
        final cached = await service.loadCache();
        int startWeek = 1;
        if (cached != null) {
          final (week, list, fm) = cached;
          courses.value = list;
          currentWeek.value = week;
          displayWeek.value = week;
          firstMonday.value = fm;
          startWeek = week;
        }

        // 2. 创建 PageController（正确的 initialPage）
        pageController.value = PageController(initialPage: startWeek - 1);

        // 3. 后台刷新 API
        _refresh(service, courses, currentWeek, displayWeek, firstMonday,
            loading, error, pageController);
      }();
      return null;
    }, []);

    final pc = pageController.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.weekN(displayWeek.value)),
        actions: [
          if (pc != null && currentWeek.value != displayWeek.value)
            TextButton(
              onPressed: () => pc.animateToPage(
                currentWeek.value - 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
              child: Text(AppLocalizations.of(context)!.thisWeek),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: pc != null && displayWeek.value > 1
                ? () => pc.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    )
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: pc != null && displayWeek.value < _totalWeeks
                ? () => pc.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    )
                : null,
          ),
        ],
      ),
      body: pc == null
          ? const Center(child: CircularProgressIndicator())
          : error.value != null && courses.value.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(AppLocalizations.of(context)!.loadingFailed(error.value ?? '')),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _refresh(service, courses, currentWeek,
                            displayWeek, firstMonday, loading, error, pageController),
                        child: Text(AppLocalizations.of(context)!.retry),
                      ),
                    ],
                  ),
                )
              : courses.value.isEmpty
                  ? Center(child: Text(AppLocalizations.of(context)!.noScheduleData))
                  : PageView.builder(
                      controller: pc,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _totalWeeks,
                      onPageChanged: (i) => displayWeek.value = i + 1,
                      itemBuilder: (context, i) =>
                          _buildBody(courses.value, i + 1, firstMonday.value),
                    ),
    );
  }

  Future<void> _refresh(
    CourseService service,
    ValueNotifier<List<Course>> courses,
    ValueNotifier<int> currentWeek,
    ValueNotifier<int> displayWeek,
    ValueNotifier<DateTime?> firstMonday,
    ValueNotifier<bool> loading,
    ValueNotifier<String?> error,
    ValueNotifier<PageController?> pageController,
  ) async {
    error.value = null;
    loading.value = true;
    try {
      final weekInfo = await service.getCurrentWeek();
      final termStr =
          '${weekInfo.year}${weekInfo.term.toString().padLeft(2, '0')}';
      final termInfo = await service.getTerms();
      final targetTerm =
          termInfo.terms.contains(termStr) ? termStr : termInfo.terms.first;

      final list = await service.getCourses(
        targetTerm,
        termInfo.viewState,
        termInfo.eventValidation,
      );
      courses.value = list;
      currentWeek.value = weekInfo.week;
      displayWeek.value = weekInfo.week;
      firstMonday.value = weekInfo.firstMonday;
      service.saveCache(weekInfo.week, list, weekInfo.firstMonday);

      // API 返回的周次和缓存不同时，动画跳转
      final pc = pageController.value;
      if (pc != null && pc.hasClients && pc.page?.round() != weekInfo.week - 1) {
        pc.animateToPage(
          weekInfo.week - 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      if (courses.value.isEmpty) error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  /// 当前正在进行的节次（0-based），不在上课时间返回 -1
  static int _currentPeriod() {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    const starts = [500, 555, 620, 675, 840, 895, 950, 1005, 1140, 1195, 1250];
    const ends   = [545, 600, 665, 720, 885, 940, 995, 1050, 1185, 1240, 1295];
    for (var i = 0; i < starts.length; i++) {
      if (minutes >= starts[i] && minutes <= ends[i]) return i;
    }
    return -1;
  }

  Widget _buildBody(List<Course> courses, int week, DateTime? firstMonday) {
    final minGridHeight = _maxPeriod * _minCellHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight - _headerHeight;
        final canFill = available >= minGridHeight;
        final cellHeight = canFill ? available / _maxPeriod : _minCellHeight;
        final gridHeight = _maxPeriod * cellHeight;

        // 计算本周每天的日期
        final weekDates = <DateTime>[];
        if (firstMonday != null) {
          final monday = firstMonday.add(Duration(days: (week - 1) * 7));
          for (var i = 0; i < 7; i++) {
            weekDates.add(monday.add(Duration(days: i)));
          }
        }

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final isCurrentWeek = weekDates.isNotEmpty && weekDates.contains(today);
        final highlightPeriod = isCurrentWeek ? _currentPeriod() : -1;

        final highlightColor = Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3);

        final weekdays = _weekdays(AppLocalizations.of(context)!);

    final content = Column(
          children: [
            SizedBox(
              height: _headerHeight,
              child: Row(
                children: [
                  const SizedBox(width: _labelWidth),
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Center(
                        child: weekDates.isNotEmpty
                            ? _buildDateHeader(
                                weekdays[i],
                                weekDates[i],
                                weekDates[i] == today,
                              )
                            : Text(weekdays[i],
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: gridHeight,
              child: Stack(
                children: [
                  // 背景高亮层
                  if (highlightPeriod >= 0)
                    Positioned(
                      top: highlightPeriod * cellHeight,
                      height: cellHeight,
                      left: 0,
                      right: 0,
                      child: Container(color: highlightColor),
                    ),
                  // 内容层：左侧索引 + 课程卡片
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: _labelWidth,
                        child: Column(
                          children: [
                            for (var p = 0; p < _maxPeriod; p++)
                              SizedBox(
                                height: cellHeight,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('${p + 1}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                        '${_timeSlots[p].$1}\n${_timeSlots[p].$2}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 7.5,
                                            height: 1.2,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      for (var wd = 1; wd <= 7; wd++)
                        Expanded(
                          child: SizedBox(
                            height: gridHeight,
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children:
                                  _buildCards(courses, wd, week, cellHeight),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );

        if (canFill) return content;
        return SingleChildScrollView(child: content);
      },
    );
  }

  Widget _buildDateHeader(String weekday, DateTime date, bool isToday) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(weekday,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isToday ? null : null)),
        Text('${date.month}/${date.day}',
            style: TextStyle(
                fontSize: 10,
                color: isToday
                    ? null
                    : Colors.grey)),
      ],
    );
  }

  List<Widget> _buildCards(
      List<Course> courses, int wd, int week, double cellHeight) {
    final cards = <Widget>[];
    for (final c in courses) {
      for (final r in c.scheduleRules) {
        if (r.weekday != wd) continue;
        if (r.startWeek > week || r.endWeek < week) continue;
        if (r.single && !r.double && week % 2 == 0) continue;
        if (r.double && !r.single && week % 2 == 1) continue;
        if (r.startClass < 1 || r.startClass > _maxPeriod) continue;

        final end = r.endClass > _maxPeriod ? _maxPeriod : r.endClass;
        final top = (r.startClass - 1) * cellHeight;
        final height = (end - r.startClass + 1) * cellHeight;

        cards.add(Positioned(
          top: top + 1,
          left: 2,
          right: 2,
          height: height - 2,
          child: _CourseCard(course: c, location: r.location),
        ));
      }
    }
    return cards;
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final String location;

  static const _lightColors = [
    Color(0xFFE3F2FD),
    Color(0xFFF3E5F5),
    Color(0xFFE8F5E9),
    Color(0xFFFFF3E0),
    Color(0xFFE0F7FA),
    Color(0xFFFCE4EC),
    Color(0xFFF1F8E9),
    Color(0xFFFFFDE7),
    Color(0xFFE8EAF6),
  ];

  static const _darkColors = [
    Color(0xFF1A3A5C),
    Color(0xFF3A1F4A),
    Color(0xFF1A3D2A),
    Color(0xFF4A3010),
    Color(0xFF1A3A3A),
    Color(0xFF4A1A2A),
    Color(0xFF2A3D1A),
    Color(0xFF3D3A10),
    Color(0xFF2A2D4A),
  ];

  const _CourseCard({required this.course, required this.location});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? _darkColors : _lightColors;
    final bg = colors[course.name.hashCode.abs() % colors.length];

    return Container(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            course.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              location,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
