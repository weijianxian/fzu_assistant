import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_mounted.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/unified_exam.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';

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
    final mounted = useMounted();

    Future<void> load() async {
      try {
        final results = await Future.wait([service.getCET(), service.getJS()]);
        cet.value = results[0];
        js.value = results[1];
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.unifiedExam)),
      body: ToolPageWrapper(
        onRefresh: load,
        loading: loading.value,
        error: error.value,
        refreshTime: refreshTime.value,
        hasData: cet.value.isNotEmpty || js.value.isNotEmpty,
        emptyText: AppLocalizations.of(context)!.noUnifiedExamData,
        child: _buildContent(context, cet.value, js.value),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<UnifiedExam> cet,
    List<UnifiedExam> js,
  ) {
    if (cet.isEmpty && js.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.noUnifiedExamData),
      );
    }

    return ListView(
      children: [
        if (cet.isNotEmpty)
          Section(
            title: AppLocalizations.of(context)!.cetScores,
            child: Column(children: [for (final e in cet) _buildTile(e)]),
          ),
        if (js.isNotEmpty)
          Section(
            title: AppLocalizations.of(context)!.provincialComputerScores,
            child: Column(children: [for (final e in js) _buildTile(e)]),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTile(UnifiedExam e) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Text(
          e.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: e.term.isNotEmpty ? Text(e.term) : null,
        trailing: Text(
          e.score,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
