import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_mounted.dart';
import 'package:fzu_assistant/common/widget/masonry_sliver_grid.dart';
import 'package:fzu_assistant/common/widget/term_selector_button.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/exam_room.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/common/widget/tool_page_wrapper.dart';

class ExamRoomPage extends HookWidget {
  const ExamRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final rooms = useState<List<ExamRoomInfo>>([]);
    final loading = useState(true);
    final error = useState<String?>(null);
    final refreshTime = useState<DateTime?>(null);
    final service = useMemoized(() => AcademicService());
    final mounted = useMounted();

    Future<void> load({bool useCache = true}) async {
      error.value = null;
      loading.value = true;
      try {
        // 确定目标学期：优先使用用户选择的，否则使用缓存的
        final selected = settings.selectedSemesterKey.value;
        var targetTerm = selected.isNotEmpty
            ? selected
            : service.cachedExamTerms.firstOrNull ?? '';

        // 如果没有学期信息，先调用一次获取可用学期列表
        if (targetTerm.isEmpty) {
          await service.getExamRooms('', useCache: false);
          if (!mounted.value) return;
          targetTerm = service.cachedExamTerms.firstOrNull ?? '';
          if (targetTerm.isEmpty) {
            loading.value = false;
            return;
          }
        }

        final data = await service.getExamRooms(targetTerm, useCache: useCache);
        if (!mounted.value) return;
        data.sort((a, b) => _parseDate(b.date).compareTo(_parseDate(a.date)));
        rooms.value = data;
        refreshTime.value = DateTime.now();
        error.value = null;
      } catch (e) {
        if (!mounted.value) return;
        error.value = e.toString();
      }
      if (mounted.value) loading.value = false;
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectedTerm.isEmpty || terms.isEmpty
              ? AppLocalizations.of(context)!.examRoom
              : AppSettings.formatSemester(selectedTerm),
        ),
        actions: [
          TermSelectorButton(
            terms: terms,
            selected: selectedTerm,
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
        slivers: _buildSlivers(context, rooms.value),
      ),
    );
  }

  List<Widget> _buildSlivers(BuildContext context, List<ExamRoomInfo> rooms) {
    final now = DateTime.now();

    return [
      MasonrySliverGrid(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childCount: rooms.length,
        itemBuilder: (context, i) {
          final r = rooms[i];
          final examDate = _parseDate(r.date);
          final past = examDate.isBefore(now) && r.date.isNotEmpty;

          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
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
                              color: past ? Colors.grey : null,
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
                              color: Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.examTaken,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
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
                          _infoTag(Icons.calendar_today, r.date),
                        if (r.time.isNotEmpty)
                          _infoTag(Icons.access_time, r.time),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (r.location.isNotEmpty)
                          _infoTag(Icons.location_on_outlined, r.location),
                        if (r.teacher.isNotEmpty)
                          _infoTag(Icons.person_outline, r.teacher),
                        if (r.credit.isNotEmpty)
                          _infoTag(
                            Icons.school_outlined,
                            AppLocalizations.of(
                              context,
                            )!.creditSuffix(r.credit),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ];
  }

  Widget _infoTag(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static DateTime _parseDate(String dateStr) {
    // "2024年11月17日" → DateTime
    final match = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(dateStr);
    if (match == null) return DateTime(1970);
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }
}
