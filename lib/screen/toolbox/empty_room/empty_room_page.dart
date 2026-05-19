import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_mounted.dart';
import 'package:fzu_assistant/common/widget/masonry_sliver_grid.dart';
import 'package:fzu_assistant/common/widget/tool_page_wrapper.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/empty_room.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';

class EmptyRoomPage extends HookWidget {
  const EmptyRoomPage({super.key});

  static const _campuses = [
    '旗山校区',
    '铜盘校区',
    '晋江校区',
    '怡山校区',
    '集美校区',
    '鼓浪屿校区',
    '翔安校区',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rooms = useState<List<EmptyRoom>>([]);
    final loading = useState(false);
    final error = useState<String?>(null);
    final refreshTime = useState<DateTime?>(null);
    final hasSearched = useState(false);
    final service = useMemoized(() => AcademicService());
    final mounted = useMounted();

    final selectedDate = useState(DateTime.now());
    final startPeriod = useState('1');
    final endPeriod = useState('11');
    final selectedCampus = useState(_campuses[0]);

    Future<void> load() async {
      loading.value = true;
      error.value = null;
      hasSearched.value = true;
      try {
        final dateStr =
            '${selectedDate.value.year}-${selectedDate.value.month.toString().padLeft(2, '0')}-${selectedDate.value.day.toString().padLeft(2, '0')}';
        rooms.value = await service.getEmptyRooms(
          dateStr,
          startPeriod.value,
          endPeriod.value,
          selectedCampus.value,
        );
        if (!mounted.value) return;
        refreshTime.value = DateTime.now();
        error.value = null;
      } catch (e) {
        if (!mounted.value) return;
        error.value = e.toString();
      }
      if (mounted.value) loading.value = false;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.emptyClassroom)),
      body: Column(
        children: [
          // 查询条件卡片
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 日期选择
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(l10n.selectDate),
                    subtitle: Text(
                      '${selectedDate.value.year}-${selectedDate.value.month.toString().padLeft(2, '0')}-${selectedDate.value.day.toString().padLeft(2, '0')}',
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate.value,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) selectedDate.value = picked;
                    },
                  ),
                  const SizedBox(height: 8),
                  // 节次选择
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: startPeriod.value,
                          decoration: InputDecoration(
                            labelText: l10n.startPeriod,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: List.generate(
                            11,
                            (i) => DropdownMenuItem(
                              value: '${i + 1}',
                              child: Text('${i + 1}'),
                            ),
                          ),
                          onChanged: (v) {
                            if (v != null) startPeriod.value = v;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: endPeriod.value,
                          decoration: InputDecoration(
                            labelText: l10n.endPeriod,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: List.generate(
                            11,
                            (i) => DropdownMenuItem(
                              value: '${i + 1}',
                              child: Text('${i + 1}'),
                            ),
                          ),
                          onChanged: (v) {
                            if (v != null) endPeriod.value = v;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 校区选择
                  DropdownButtonFormField<String>(
                    initialValue: selectedCampus.value,
                    decoration: InputDecoration(
                      labelText: l10n.selectCampus,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _campuses
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) selectedCampus.value = v;
                    },
                  ),
                  const SizedBox(height: 16),
                  // 查询按钮
                  FilledButton.icon(
                    onPressed: loading.value ? null : load,
                    icon: const Icon(Icons.search),
                    label: Text(l10n.query),
                  ),
                ],
              ),
            ),
          ),
          // 结果列表
          Expanded(
            child: ToolPageWrapper(
              onRefresh: load,
              loading: loading.value,
              error: error.value,
              refreshTime: refreshTime.value,
              hasData: rooms.value.isNotEmpty || !hasSearched.value,
              emptyText: l10n.noEmptyRoomData,
              slivers: [
                if (hasSearched.value && !loading.value && rooms.value.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: Center(
                        child: Text(
                          l10n.noEmptyRoomData,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    ),
                  )
                else
                  MasonrySliverGrid(
                    childCount: rooms.value.length,
                    itemBuilder: (context, i) {
                      final room = rooms.value[i];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(Icons.meeting_room_outlined),
                          title: Text(room.name),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
