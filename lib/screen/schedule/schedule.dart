import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_mounted.dart';
import 'package:fzu_assistant/common/utils/context_ext.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/model/exam_room.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/schedule/widgets/schedule_grid.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:fzu_assistant/service/api/course_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

const _totalWeeks = 19;

class SchedulePage extends HookWidget {
  final ValueNotifier<int>? jumpToWeekTrigger;

  const SchedulePage({super.key, this.jumpToWeekTrigger});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final courses = useState<List<Course>>([]);
    final examRooms = useState<List<ExamRoomInfo>>([]);
    final displayWeek = useState<int>(1);
    final loading = useState(true);
    final error = useState<String?>(null);
    final service = useMemoized(() => CourseService());
    final academic = useMemoized(() => AcademicService());
    final pageController = useState<PageController?>(null);
    final firstMonday = useState<DateTime?>(null);
    final mounted = useMounted();
    final currentLoadedTerm = useState<String?>(null);
    final currentWeek = useState<int>(1);
    final currentTerm = useState<String>('');
    final refreshSerial = useRef(0);

    Future<int?> refresh(String term, {bool useCache = true}) async {
      refreshSerial.value += 1;
      final serial = refreshSerial.value;
      bool isLatest() => mounted.value && serial == refreshSerial.value;

      error.value = null;
      loading.value = true;
      var week = 1;
      try {
        final list = await service.getCourses(term, useCache: useCache);
        if (!isLatest()) return null;
        courses.value = list;
        currentLoadedTerm.value = term;
        if (service.cachedTerms.isNotEmpty) {
          settings.termsKey.value = service.cachedTerms;
        }

        // 从缓存加载考试数据
        final exams = await academic.getExamRooms(term, useCache: useCache);
        if (!isLatest()) return null;
        examRooms.value = exams;

        final fm = await service.getFirstMondayForTerm(term);
        if (!isLatest()) return null;
        firstMonday.value = fm;

        if (fm != null) {
          week = CourseService.getWeekFromFirstMonday(fm);
          currentWeek.value = week;
        }
      } catch (e) {
        if (!isLatest()) return null;
        if (courses.value.isEmpty) error.value = e.toString();
      } finally {
        if (isLatest()) loading.value = false;
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

          final hasCachedData = await Future.wait([
            service.hasCachedCourses(targetTerm),
            academic.hasCachedExamRooms(targetTerm),
          ]);
          final latestSelected = settings.selectedSemesterKey.value;
          final latestTarget = latestSelected.isNotEmpty
              ? latestSelected
              : currentTerm.value;
          if (latestTarget != targetTerm) return;

          // 先从缓存加载，快速显示
          final week = await refresh(targetTerm);
          if (week == null || !mounted.value) return;
          pageController.value = PageController(initialPage: week - 1);
          displayWeek.value = week;

          if (hasCachedData.every((cached) => cached)) {
            // 异步强制刷新，更新最新数据
            refresh(targetTerm, useCache: false);
          }
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

    // 监听底部 tab 再次点击 → 跳转本周
    final trigger = jumpToWeekTrigger;
    useEffect(() {
      if (trigger == null) return null;
      void onTrigger() {
        final pc = pageController.value;
        if (pc != null && currentWeek.value > 0) {
          pc.animateToPage(
            currentWeek.value - 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }

      trigger.addListener(onTrigger);
      return () => trigger.removeListener(onTrigger);
    }, [trigger]);

    final pc = pageController.value;

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
        title: Text(AppLocalizations.of(context)!.weekN(displayWeek.value)),
        actions: [
          if (context.isLandscape)
            IconButton(
              icon: loading.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: loading.value
                  ? null
                  : () async {
                      final selected = settings.selectedSemesterKey.value;
                      final target = selected.isNotEmpty
                          ? selected
                          : currentTerm.value;
                      if (target.isNotEmpty) {
                        await refresh(target, useCache: false);
                      }
                    },
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.pushNamed(AppRoutes.scheduleSettings),
          ),
          if (context.isLandscape) ...[
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
        ],
      ),
      body: _ScheduleBody(
        loading: loading.value,
        error: error.value,
        courses: courses.value,
        examRooms: examRooms.value,
        pageController: pc,
        displayWeek: displayWeek,
        firstMonday: firstMonday.value,
        onRetry: () {
          final selected = settings.selectedSemesterKey.value;
          final target = selected.isNotEmpty ? selected : currentTerm.value;
          if (target.isNotEmpty) refresh(target);
        },
        onRefresh: () async {
          final selected = settings.selectedSemesterKey.value;
          final target = selected.isNotEmpty ? selected : currentTerm.value;
          if (target.isNotEmpty) await refresh(target, useCache: false);
        },
      ),
    );
  }
}

class _ScheduleBody extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<Course> courses;
  final List<ExamRoomInfo> examRooms;
  final PageController? pageController;
  final ValueNotifier<int> displayWeek;
  final DateTime? firstMonday;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;

  const _ScheduleBody({
    required this.loading,
    required this.error,
    required this.courses,
    required this.examRooms,
    required this.pageController,
    required this.displayWeek,
    required this.firstMonday,
    required this.onRetry,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && (courses.isEmpty || pageController == null)) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)!.loadingFailed(error!)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      );
    }

    if (courses.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noScheduleData));
    }

    if (pageController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return PageView.builder(
      controller: pageController,
      physics: const BouncingScrollPhysics(),
      itemCount: _totalWeeks,
      onPageChanged: (i) => displayWeek.value = i + 1,
      itemBuilder: (context, i) => ScheduleGrid(
        courses: courses,
        examRooms: examRooms,
        week: i + 1,
        firstMonday: firstMonday,
        onRefresh: onRefresh,
      ),
    );
  }
}
