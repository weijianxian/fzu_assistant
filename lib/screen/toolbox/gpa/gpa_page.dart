import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_mounted.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/gpa.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';

class GpaPage extends HookWidget {
  const GpaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final gpa = useState<GPABean?>(null);
    final loading = useState(true);
    final error = useState<String?>(null);
    final refreshTime = useState<DateTime?>(null);
    final service = useMemoized(() => AcademicService());
    final mounted = useMounted();

    Future<void> load() async {
      try {
        gpa.value = await service.getGPA();
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.gpaInfo)),
      body: ToolPageWrapper(
        onRefresh: load,
        loading: loading.value,
        error: error.value,
        refreshTime: refreshTime.value,
        hasData: gpa.value != null && gpa.value!.data.isNotEmpty,
        emptyText: AppLocalizations.of(context)!.noGpaData,
        child: gpa.value != null
            ? _buildContent(context, gpa.value!)
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildContent(BuildContext context, GPABean gpa) {
    if (gpa.data.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noGpaData));
    }

    // 找出所有不同的 type（列头）
    final headers = <String>[];
    for (final d in gpa.data) {
      if (!headers.contains(d.type)) headers.add(d.type);
    }
    final width = headers.length;
    if (width == 0) {
      return Center(child: Text(AppLocalizations.of(context)!.dataParseError));
    }

    // 按行分组
    final rows = <List<GPAData>>[];
    for (var i = 0; i < gpa.data.length; i += width) {
      rows.add(gpa.data.sublist(i, (i + width).clamp(0, gpa.data.length)));
    }

    // 转置：每列（type）变成一行
    final List<List<String>> transposed = [];
    for (var c = 0; c < width; c++) {
      final row = <String>[headers[c]];
      for (final r in rows) {
        if (c < r.length) row.add(r[c].value);
      }
      transposed.add(row);
    }

    return ListView(
      children: [
        Card(
          margin: const EdgeInsets.all(12),
          clipBehavior: Clip.antiAlias,
          child: Table(
            columnWidths: {
              for (var i = 0; i < transposed[0].length; i++)
                i: i == 0
                    ? const IntrinsicColumnWidth()
                    : const FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              for (var r = 0; r < transposed.length; r++)
                TableRow(
                  decoration: r < transposed.length - 1
                      ? BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.15),
                            ),
                          ),
                        )
                      : null,
                  children: [
                    for (var c = 0; c < transposed[r].length; c++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Text(
                          transposed[r][c],
                          style: TextStyle(
                            fontSize: 14,
                            color: c == 0 ? Colors.grey : null,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
