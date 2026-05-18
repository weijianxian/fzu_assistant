import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/credit.dart';
import 'package:fzu_assistant/common/tool_page_wrapper.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';

class CreditPage extends HookWidget {
  const CreditPage({super.key});

  @override
  Widget build(BuildContext context) {
    final credits = useState<List<CreditStatistics>>([]);
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
        credits.value = await service.getCredit();
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.creditStats)),
      body: ToolPageWrapper(
        onRefresh: load,
        loading: loading.value,
        error: error.value,
        refreshTime: refreshTime.value,
        hasData: credits.value.isNotEmpty,
        emptyText: AppLocalizations.of(context)!.noCreditData,
        child: _buildList(credits.value),
      ),
    );
  }

  Widget _buildList(List<CreditStatistics> credits) {
    return ListView.builder(
      itemCount: credits.length,
      itemBuilder: (context, i) {
        final c = credits[i];
        final gain = double.tryParse(c.gain) ?? 0;
        final total = double.tryParse(c.total) ?? 1;
        final progress = (total > 0) ? (gain / total).clamp(0.0, 1.0) : 0.0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.type,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${c.gain} / ${c.total}',
                      style: TextStyle(
                        fontSize: 14,
                        color: progress >= 1.0
                            ? Colors.green
                            : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
