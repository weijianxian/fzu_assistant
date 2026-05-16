import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/model/unified_exam.dart';
import 'package:fzu_assistant/service/academic_service.dart';
import 'package:fzu_assistant/screen/toolbox/tool_page_wrapper.dart';

class UnifiedExamPage extends HookWidget {
  const UnifiedExamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cet = useState<List<UnifiedExam>>([]);
    final js = useState<List<UnifiedExam>>([]);
    final loading = useState(true);
    final error = useState<String?>(null);
    final refreshTime = useState<DateTime?>(null);
    final service = useMemoized(() => AcademicService());

    Future<void> load() async {
      try {
        final results = await Future.wait([service.getCET(), service.getJS()]);
        cet.value = results[0];
        js.value = results[1];
        refreshTime.value = DateTime.now();
        error.value = null;
      } catch (e) {
        error.value = e.toString();
      }
      loading.value = false;
    }

    useEffect(() {
      load();
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(title: const Text('统考成绩')),
      body: ToolPageWrapper(
        onRefresh: load,
        loading: loading.value,
        error: error.value,
        refreshTime: refreshTime.value,
        hasData: cet.value.isNotEmpty || js.value.isNotEmpty,
        emptyText: '暂无统考成绩',
        child: _buildContent(cet.value, js.value),
      ),
    );
  }

  Widget _buildContent(List<UnifiedExam> cet, List<UnifiedExam> js) {
    if (cet.isEmpty && js.isEmpty) {
      return const Center(child: Text('暂无统考成绩'));
    }

    return ListView(
      children: [
        if (cet.isNotEmpty) ...[
          _sectionHeader('CET 成绩'),
          for (final e in cet) _buildTile(e),
        ],
        if (js.isNotEmpty) ...[
          _sectionHeader('省计算机成绩'),
          for (final e in js) _buildTile(e),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTile(UnifiedExam e) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: e.term.isNotEmpty ? Text(e.term) : null,
        trailing: Text(
          e.score,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
