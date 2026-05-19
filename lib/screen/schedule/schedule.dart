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
    final currentLoadedTerm = useState<String?>(null);
    final currentWeek = useState<int>(1);
    final currentTerm = useState<String>('');

    Future<int> refresh(String term, {bool useCache = true}) async {
      error.value = null;
      loading.value = true;
      var week = 1;
      try {
        final list = await service.getCourses(term, useCache: useCache);
        if (!mounted.value) return week;
        courses.value = list;
        currentLoadedTerm.value = term;
        if (!useCache) settings.termsKey.value = service.cachedTerms;

        final fm = await service.getFirstMondayForTerm(term);
        if (!mounted.value) return week;
        firstMonday.value = fm;

        if (fm != null) {
          week = CourseService.getWeekFromFirstMonday(fm);
          currentWeek.value = week;
        }
      } catch (e) {
        if (!mounted.value) return week;
        if (courses.value.isEmpty) error.value = e.toString();
      } finally {
        if (mounted.value) loading.value = false;
      }
      return week;
    }

    // 初始化：校历 → 当前学期 → 课表 → 创建 PageController
    useEffect(() {
      () async {
        try {
          final cal = await AcademicService().loadOrFetchCalendar();
          currentTerm.value = AcademicService.getCurrentTermFromCalendar(cal);

          final selected = settings.selectedSemesterKey.value;
          final targetTerm = selected.isNotEmpty ? selected : currentTerm.value;
          if (targetTerm.isEmpty) {
            loading.value = false;
            return;
          }

          final week = await refresh(targetTerm);
          displayWeek.value = week;
          pageController.value = PageController(initialPage: week - 1);
        } catch (e) {
          if (mounted.value) error.value = e.toString();
        }
      }();
      return null;
    }, []);

    // 监听学期切换
    useEffect(() {
      void onSemesterChanged() {
        final selected = settings.selectedSemesterKey.value;
        // 确定目标学期：手动选的 或 自动取当前学期
        final target = selected.isNotEmpty ? selected : currentTerm.value;
        if (target.isEmpty || target == currentLoadedTerm.value) return;

        courses.value = [];
        currentLoadedTerm.value = null;
        displayWeek.value = 1;
        pageController.value = PageController(initialPage: 0);
        refresh(target, useCache: selected.isEmpty);
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
          if (displayWeek.value != currentWeek.value &&
              _isCurrentSemester(currentTerm.value, currentLoadedTerm.value))
            TextButton(
              onPressed: () => pc?.animateToPage(
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
      body: loading.value && courses.value.isEmpty
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
                    onPressed: () {
                      final selected = settings.selectedSemesterKey.value;
                      final target = selected.isNotEmpty
                          ? selected
                          : currentTerm.value;
                      if (target.isNotEmpty) refresh(target);
                    },
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

  static bool _isCurrentSemester(String currentTerm, String? loadedTerm) {
    if (currentTerm.isEmpty || loadedTerm == null) return false;
    return currentTerm == loadedTerm;
  }
}
