import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/empty_room.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';

class EmptyRoomPage extends HookWidget {
  const EmptyRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rooms = useState<List<EmptyRoom>>([]);
    final loading = useState(false);
    final error = useState<String?>(null);
    final refreshTime = useState<DateTime?>(null);
    final hasSearched = useState(false);
    final service = useMemoized(() => AcademicService());

    final selectedDate = useState(DateTime.now());
    final startPeriod = useState('1');
    final endPeriod = useState('11');
    final campuses = useState<List<String>>([]);
    final selectedCampus = useState('');
    final campusesLoading = useState(true);
    final campusesError = useState<String?>(null);

    Future<void> loadCampuses() async {
      campusesLoading.value = true;
      campusesError.value = null;
      try {
        final list = await service.getEmptyRoomCampuses();
        if (!context.mounted) return;
        campuses.value = list;
        if (list.isNotEmpty && !list.contains(selectedCampus.value)) {
          selectedCampus.value = list.first;
        }
      } catch (e) {
        if (!context.mounted) return;
        campusesError.value = e.toString();
      }
      if (context.mounted) campusesLoading.value = false;
    }

    useEffect(() {
      loadCampuses();
      return null;
    }, []);

    Future<void> load() async {
      loading.value = true;
      error.value = null;
      hasSearched.value = true;
      try {
        final dateStr =
            '${selectedDate.value.year}-${selectedDate.value.month.toString().padLeft(2, '0')}-${selectedDate.value.day.toString().padLeft(2, '0')}';
        final data = await service.getEmptyRooms(
          dateStr,
          startPeriod.value,
          endPeriod.value,
          selectedCampus.value,
        );
        if (!context.mounted) return;
        rooms.value = data;
        refreshTime.value = DateTime.now();
        error.value = null;
      } catch (e) {
        if (!context.mounted) return;
        error.value = e.toString();
      }
      if (context.mounted) loading.value = false;
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
                  // 校区选择：列表来自教务处页面，加载完成后才构建下拉框，
                  // 否则 FormField 的 initialValue 会停在空值上。
                  if (campusesLoading.value)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    )
                  else if (campusesError.value != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.error_outline),
                      title: Text(l10n.loadingFailed(campusesError.value!)),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: loadCampuses,
                      ),
                    )
                  else if (campuses.value.isEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.error_outline),
                      title: Text(l10n.noData),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: loadCampuses,
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue:
                          campuses.value.contains(selectedCampus.value)
                          ? selectedCampus.value
                          : null,
                      decoration: InputDecoration(
                        labelText: l10n.selectCampus,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: campuses.value
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) selectedCampus.value = v;
                      },
                    ),
                  const SizedBox(height: 16),
                  // 查询按钮
                  FilledButton.icon(
                    onPressed: loading.value || selectedCampus.value.isEmpty
                        ? null
                        : load,
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
