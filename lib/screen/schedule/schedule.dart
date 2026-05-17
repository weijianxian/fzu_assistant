import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/screen/schedule/schedule_grid.dart';
import 'package:fzu_assistant/service/course_service.dart';

const _totalWeeks = 19;

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
    final mounted = useRef(true);
    useEffect(
      () => () {
        mounted.value = false;
      },
      [],
    );

    // 加载缓存 → 创建 PageController → 刷新 API
    useEffect(() {
      () async {
        // 1. 读周次缓存（splash 已持久化）
        final weekCache = await service.loadWeekCache();
        int startWeek = 1;
        if (weekCache != null) {
          final (week, fm) = weekCache;
          currentWeek.value = week;
          displayWeek.value = week;
          firstMonday.value = fm;
          startWeek = week;
        }

        // 2. 读课程缓存
        final coursesCache = await service.loadCoursesCache();
        if (coursesCache != null) {
          courses.value = coursesCache;
        }

        // 3. 创建 PageController（正确的 initialPage）
        pageController.value = PageController(initialPage: startWeek - 1);

        // 4. 后台刷新 API
        _refresh(
          service,
          courses,
          currentWeek,
          displayWeek,
          firstMonday,
          loading,
          error,
          pageController,
          mounted,
        );
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
      body: pc == null || firstMonday.value == null
          ? const Center(child: CircularProgressIndicator())
          : error.value != null && courses.value.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.loadingFailed(error.value ?? ''),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _refresh(
                      service,
                      courses,
                      currentWeek,
                      displayWeek,
                      firstMonday,
                      loading,
                      error,
                      pageController,
                      mounted,
                    ),
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
              itemBuilder: (context, i) => ScheduleGrid(
                courses: courses.value,
                week: i + 1,
                firstMonday: firstMonday.value,
              ),
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
    ObjectRef<bool> mounted,
  ) async {
    error.value = null;
    loading.value = true;
    try {
      final weekInfo = await service.getCurrentWeek();
      if (!mounted.value) return;
      final termStr =
          '${weekInfo.year}${weekInfo.term.toString().padLeft(2, '0')}';
      final termInfo = await service.getTerms();
      if (!mounted.value) return;
      final targetTerm = termInfo.terms.contains(termStr)
          ? termStr
          : termInfo.terms.first;

      final list = await service.getCourses(
        targetTerm,
        termInfo.viewState,
        termInfo.eventValidation,
      );
      if (!mounted.value) return;
      courses.value = list;
      currentWeek.value = weekInfo.week;
      displayWeek.value = weekInfo.week;
      firstMonday.value = weekInfo.firstMonday;
      service.saveCache(weekInfo.week, list, weekInfo.firstMonday);

      // API 返回的周次和缓存不同时，动画跳转
      final pc = pageController.value;
      if (pc != null &&
          pc.hasClients &&
          pc.page?.round() != weekInfo.week - 1) {
        pc.animateToPage(
          weekInfo.week - 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      if (!mounted.value) return;
      if (courses.value.isEmpty) error.value = e.toString();
    } finally {
      if (mounted.value) loading.value = false;
    }
  }
}
