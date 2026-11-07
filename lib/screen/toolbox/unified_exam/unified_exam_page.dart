import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_async_data.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/unified_exam.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';

class UnifiedExamPage extends HookWidget {
  const UnifiedExamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = useMemoized(() => AcademicService());
    final result = useAsyncData(
      () => Future.wait([service.getCET(), service.getJS()]),
      initialData: const [<UnifiedExam>[], <UnifiedExam>[]],
    );
    final [cet, js] = result.data!;

    return AppScaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.unifiedExam)),
      body: ToolPageWrapper(
        onRefresh: result.refresh,
        loading: result.loading,
        error: result.error,
        refreshTime: result.updatedAt,
        hasData: cet.isNotEmpty || js.isNotEmpty,
        emptyText: AppLocalizations.of(context)!.noUnifiedExamData,
        child: _buildContent(context, cet, js),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<UnifiedExam> cet,
    List<UnifiedExam> js,
  ) {
    return AppListView(
      children: [
        if (cet.isNotEmpty)
          AppSection.list(
            title: AppLocalizations.of(context)!.cetScores,
            children: [for (final e in cet) _buildTile(e)],
          ),
        if (js.isNotEmpty)
          AppSection.list(
            title: AppLocalizations.of(context)!.provincialComputerScores,
            children: [for (final e in js) _buildTile(e)],
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTile(UnifiedExam e) {
    return ListTile(
      title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: e.term.isNotEmpty ? Text(e.term) : null,
      trailing: Text(
        e.score,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
