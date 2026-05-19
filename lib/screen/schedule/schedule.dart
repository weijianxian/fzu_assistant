import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_mounted.dart';
import 'package:fzu_assistant/common/widget/term_selector_button.dart';
import 'package:fzu_assistant/constants/breakpoints.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/screen/schedule/schedule_grid.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:fzu_assistant/service/api/course_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

const _totalWeeks = 19;

class SchedulePage extends HookWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final courses = useState<List<Course>>([]);
    final displayWeek = useState<int>(1);
    final loading = useState(true);
    final error = useState<String?>(null);
    final service = useMemoized(() => CourseService());
    final pageController = useState<PageController?>(null);
    final firstMonday = useState<DateTime?>(null);
    final mounted = useMounted();
    // 记录当前正在显示的学期，用于检测切换
    final currentLoadedTerm = useState<String?>(null);

    // 统一的刷新方法
    Future<void> refresh() async {
      error.value = null;
      loading.value = true;
      try {
        // 1. 获取当前周次
        final weekInfo = await service.getCurrentWeek();
        if (!mounted.value) return;
        settings.currentWeekKey.value = weekInfo.week;

        // 2. 确定目标学期
        final selected = settings.selectedSemesterKey.value;
        final currentTermStr =
            '${weekInfo.year}${weekInfo.term.toString().padLeft(2, '0')}';
        final targetTerm = selected.isNotEmpty ? selected : currentTermStr;
        final isCurrent = targetTerm == currentTermStr;

        // 3. 如果学期没变且已有数据，跳过
        if (currentLoadedTerm.value == targetTerm && courses.value.isNotEmpty) {
          if (isCurrent) {
            firstMonday.value = weekInfo.firstMonday;
            service.saveFirstMondayForTerm(targetTerm, weekInfo.firstMonday);
            displayWeek.value = weekInfo.week;
            _animateToWeek(pageController.value, weekInfo.week);
          }
          loading.value = false;
          return;
        }

        // 4. 获取课程（service 内部处理缓存 + getTerms）
        final list = await service.getCourses(targetTerm, useCache: false);
        if (!mounted.value) return;
        courses.value = list;
        currentLoadedTerm.value = targetTerm;
        settings.termsKey.value = service.cachedTerms;

        // 5. 更新周次和 firstMonday
        if (isCurrent) {
          firstMonday.value = weekInfo.firstMonday;
          service.saveFirstMondayForTerm(targetTerm, weekInfo.firstMonday);
          displayWeek.value = weekInfo.week;
          _animateToWeek(pageController.value, weekInfo.week);
        } else {
          // 旧学期：从缓存或校历获取 firstMonday
          var fm = await service.loadFirstMondayForTerm(targetTerm);
          debugPrint('[Schedule] old term=$targetTerm, cached fm=$fm');
          if (fm == null) {
            final cal = await AcademicService().getSchoolCalendar();
            debugPrint(
              '[Schedule] calendar terms: ${cal.terms.map((t) => '${t.term}/${t.startDate}').toList()}',
            );
            final termData = cal.terms.where((t) => t.term == targetTerm);
            debugPrint(
              '[Schedule] matched termData: ${termData.map((t) => '${t.term}/${t.startDate}').toList()}',
            );
            if (termData.isNotEmpty) {
              final startDate = DateTime.tryParse(termData.first.startDate);
              debugPrint('[Schedule] startDate=$startDate');
              if (startDate != null) {
                final offset = (startDate.weekday + 6) % 7;
                fm = startDate.subtract(Duration(days: offset));
                debugPrint('[Schedule] computed firstMonday=$fm');
                service.saveFirstMondayForTerm(targetTerm, fm);
              }
            }
          }
          firstMonday.value = fm;
          debugPrint('[Schedule] final firstMonday=$fm');
          displayWeek.value = 1;
        }
      } catch (e) {
        if (!mounted.value) return;
        if (courses.value.isEmpty) error.value = e.toString();
      } finally {
        if (mounted.value) loading.value = false;
      }
    }

    // 初始化：创建 PageController + 首次刷新
    useEffect(() {
      () async {
        final startWeek = settings.currentWeekKey.value;
        displayWeek.value = startWeek;

        // 用缓存快速填充（getCourses 内部处理缓存逻辑）
        final selected = settings.selectedSemesterKey.value;
        if (selected.isNotEmpty) {
          try {
            final cached = await service.getCourses(selected, useCache: true);
            if (cached.isNotEmpty && mounted.value) {
              courses.value = cached;
              currentLoadedTerm.value = selected;
            }
            firstMonday.value = await service.loadFirstMondayForTerm(selected);
          } catch (_) {}
        }

        pageController.value = PageController(initialPage: startWeek - 1);
        refresh();
      }();
      return null;
    }, []);

    // 监听学期切换
    useEffect(() {
      void onSemesterChanged() {
        final selected = settings.selectedSemesterKey.value;
        if (selected != currentLoadedTerm.value) {
          // 切换学期时先清空课程，避免显示旧数据
          courses.value = [];
          currentLoadedTerm.value = null;
          refresh();
        }
      }

      settings.selectedSemesterKey.addListener(onSemesterChanged);
      return () =>
          settings.selectedSemesterKey.removeListener(onSemesterChanged);
    }, []);

    final pc = pageController.value;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: MediaQuery.sizeOf(context).width >= kNavBreakpoint
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
        title: Text(AppLocalizations.of(context)!.weekN(displayWeek.value)),
        actions: [
          TermSelectorButton(
            terms: settings.termsKey.value,
            selected: settings.selectedSemesterKey.value,
            onSelected: (term) => settings.selectedSemesterKey.value = term,
          ),
          if (pc != null &&
              settings.currentWeekKey.value != displayWeek.value &&
              _isCurrentSemester(settings, firstMonday.value))
            TextButton(
              onPressed: () => pc.animateToPage(
                settings.currentWeekKey.value - 1,
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
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.loadingFailed(error.value ?? ''),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: refresh,
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

  static bool _isCurrentSemester(AppSettings settings, DateTime? fm) {
    final selected = settings.selectedSemesterKey.value;
    if (selected.isEmpty) return true; // 自动模式 = 当前学期
    if (fm == null) return true;
    final week = settings.currentWeekKey.value;
    // 计算当前学期的 firstMonday，与选中学期的比较
    final now = DateTime.now();
    final thisMonday = now.subtract(Duration(days: now.weekday - 1));
    final currentFirstMonday = thisMonday.subtract(
      Duration(days: (week - 1) * 7),
    );
    return (currentFirstMonday.difference(fm).inDays.abs() < 7);
  }

  static void _animateToWeek(PageController? pc, int week) {
    if (pc != null && pc.hasClients && pc.page?.round() != week - 1) {
      pc.animateToPage(
        week - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
}
