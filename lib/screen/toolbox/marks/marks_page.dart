import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/masonry_sliver_grid.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/mark.dart';
import 'package:fzu_assistant/service/academic_service.dart';
import 'package:fzu_assistant/common/tool_page_wrapper.dart';

class MarksPage extends HookWidget {
  const MarksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final marks = useState<List<Mark>>([]);
    final loading = useState(true);
    final error = useState<String?>(null);
    final refreshTime = useState<DateTime?>(null);
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
        marks.value = await service.getMarks();
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.marksQuery)),
      body: ToolPageWrapper(
        onRefresh: load,
        loading: loading.value,
        error: error.value,
        refreshTime: refreshTime.value,
        hasData: marks.value.isNotEmpty,
        emptyText: AppLocalizations.of(context)!.noMarksData,
        slivers: _buildSlivers(context, marks.value),
      ),
    );
  }

  List<Widget> _buildSlivers(BuildContext context, List<Mark> marks) {
    // 按学期分组，保持顺序
    final grouped = <String, List<Mark>>{};
    for (final m in marks) {
      final key = m.semester.isEmpty
          ? AppLocalizations.of(context)!.unknownSemester
          : m.semester;
      grouped.putIfAbsent(key, () => []).add(m);
    }
    // 每学期按成绩倒序
    for (final list in grouped.values) {
      list.sort((a, b) {
        final sa = double.tryParse(a.score) ?? -1;
        final sb = double.tryParse(b.score) ?? -1;
        return sb.compareTo(sa);
      });
    }
    final semesters = grouped.keys.toList();

    return [
      MasonrySliverGrid(
        childCount: semesters.length,
        itemBuilder: (context, i) {
          final sem = semesters[i];
          final items = grouped[sem]!;
          return Card(
            margin: EdgeInsets.zero,
            child: ExpansionTile(
              initiallyExpanded: i == 0,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                sem,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.courseCount(items.length),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              children: [
                for (var j = 0; j < items.length; j++) ...[
                  _buildMarkTile(context, items[j]),
                  if (j < items.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          );
        },
      ),
    ];
  }

  Widget _buildMarkTile(BuildContext context, Mark m) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                m.score,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _scoreColor(m.score),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _tag(AppLocalizations.of(context)!.creditsTag(m.credits)),
              _tag(AppLocalizations.of(context)!.gpaTag(m.gpa)),
              if (m.teacher.isNotEmpty) _tag(m.teacher),
            ],
          ),
          if (m.electiveType.isNotEmpty || m.examType.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 8,
                children: [
                  if (m.electiveType.isNotEmpty)
                    _tag(m.electiveType, color: Colors.blue),
                  if (m.examType.isNotEmpty)
                    _tag(m.examType, color: Colors.orange),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tag(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: color ?? Colors.grey[700]),
      ),
    );
  }

  Color _scoreColor(String score) {
    final n = double.tryParse(score);
    if (n == null) return Colors.black87;
    if (n >= 90) return Colors.green;
    if (n >= 60) return Colors.orange;
    return Colors.red;
  }
}
