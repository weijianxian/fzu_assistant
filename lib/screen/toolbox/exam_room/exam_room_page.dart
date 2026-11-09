import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widget/academic_change_notice.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/semester_utils.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/exam_room.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

class ExamRoomPage extends HookWidget {
  const ExamRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final rooms = useState<List<ExamRoomInfo>>([]);
    final loading = useState(true);
    final error = useState<String?>(null);
    final refreshTime = useState<DateTime?>(null);
    final effectiveTerm = useState<String>('');
    final service = useMemoized(() => AcademicService());
    final requestSerial = useRef(0);
    final now = useState(DateTime.now());

    useEffect(() {
      final timer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => now.value = DateTime.now(),
      );
      return timer.cancel;
    }, const []);

    Future<void> load({bool useCache = true}) async {
      final request = ++requestSerial.value;
      bool isLatest() => context.mounted && request == requestSerial.value;
      error.value = null;
      loading.value = true;
      try {
        // 确定目标学期：优先使用用户选择的，否则使用缓存的
        final selected = settings.selectedSemesterKey.value;
        final (targetTerm, data) = await service.getExamRoomsForPreferredTerm(
          selected,
          useCache: useCache,
        );
        if (!isLatest()) return;
        rooms.value = data;
        effectiveTerm.value = targetTerm;
        refreshTime.value = DateTime.now();
        error.value = null;
      } catch (e) {
        if (!isLatest()) return;
        error.value = e.toString();
      }
      if (isLatest()) loading.value = false;
    }

    useEffect(() {
      load(useCache: false);
      return null;
    }, []);

    // 监听学期切换
    useEffect(() {
      void onSemesterChanged() {
        load(useCache: false);
      }

      settings.selectedSemesterKey.addListener(onSemesterChanged);
      return () =>
          settings.selectedSemesterKey.removeListener(onSemesterChanged);
    }, []);

    final selectedTerm = settings.selectedSemesterKey.value;
    final terms = service.cachedExamTerms;
    final menuTerm = selectedTerm.isEmpty
        ? ''
        : terms.contains(selectedTerm)
        ? selectedTerm
        : effectiveTerm.value;

    return AppScaffold(
      appBar: AppBar(
        title: Text(
          menuTerm.isEmpty || terms.isEmpty
              ? AppLocalizations.of(context)!.examRoom
              : SemesterUtils.formatSemester(menuTerm),
        ),
        actions: [
          TermSelectorButton(
            terms: terms,
            selected: menuTerm,
            onSelected: (term) => settings.selectedSemesterKey.value = term,
          ),
        ],
      ),
      body: ToolPageWrapper(
        onRefresh: () => load(useCache: false),
        loading: loading.value,
        error: error.value,
        refreshTime: refreshTime.value,
        hasData: rooms.value.isNotEmpty,
        emptyText: AppLocalizations.of(context)!.noExamRoomInfo,
        slivers: _buildSlivers(
          context,
          ExamRoomInfo.sorted(rooms.value, now.value),
          now.value,
        ),
      ),
    );
  }

  List<Widget> _buildSlivers(
    BuildContext context,
    List<ExamRoomInfo> rooms,
    DateTime now,
  ) {
    final colors = Theme.of(context).colorScheme;
    return [
      const SliverToBoxAdapter(child: AcademicChangeNotice(exams: true)),
      MasonrySliverGrid.grouped(
        childCount: rooms.length,
        itemBuilder: (context, i) {
          final r = rooms[i];
          final past = r.hasFinished(now);

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Opacity(
              opacity: past ? 0.4 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.courseName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: past ? colors.onSurfaceVariant : null,
                          ),
                        ),
                      ),
                      if (past)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.examTaken,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (r.date.isNotEmpty)
                        _infoTag(context, Icons.calendar_today, r.date),
                      if (r.time.isNotEmpty)
                        _infoTag(context, Icons.access_time, r.time),
                      if (r.date.isEmpty && r.rawExamTime.isNotEmpty)
                        _infoTag(context, Icons.info_outline, r.rawExamTime),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (r.location.isNotEmpty)
                        _infoTag(
                          context,
                          Icons.location_on_outlined,
                          r.location,
                        ),
                      if (r.teacher.isNotEmpty)
                        _infoTag(context, Icons.person_outline, r.teacher),
                      if (r.credit.isNotEmpty)
                        _infoTag(
                          context,
                          Icons.school_outlined,
                          AppLocalizations.of(context)!.creditSuffix(r.credit),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ];
  }

  Widget _infoTag(BuildContext context, IconData icon, String text) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: muted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
