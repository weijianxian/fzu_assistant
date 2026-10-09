import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_async_data.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/gpa.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';

class GpaPage extends HookWidget {
  const GpaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = useMemoized(() => AcademicService());
    final result = useAsyncData(service.getGPA);
    final gpa = result.data;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.gpaInfo)),
      body: ToolPageWrapper(
        onRefresh: result.refresh,
        loading: result.loading,
        error: result.error,
        refreshTime: result.updatedAt,
        hasData: gpa != null && gpa.data.isNotEmpty,
        emptyText: AppLocalizations.of(context)!.noGpaData,
        child: gpa != null && gpa.data.isNotEmpty
            ? _buildContent(gpa)
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildContent(GPABean gpa) {
    // 找出所有不同的 type（列头）
    final headers = gpa.data.map((d) => d.type).toSet().toList();
    final width = headers.length;

    // 转置：每列（type）变成一行
    final transposed = [
      for (var c = 0; c < width; c++)
        [
          headers[c],
          for (var i = c; i < gpa.data.length; i += width) gpa.data[i].value,
        ],
    ];

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
