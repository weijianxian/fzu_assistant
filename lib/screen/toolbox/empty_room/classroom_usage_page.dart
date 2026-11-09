import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/classroom_usage.dart';
import 'package:fzu_assistant/service/api/classroom_usage_service.dart';
import 'package:intl/intl.dart';

class ClassroomUsagePage extends HookWidget {
  const ClassroomUsagePage({super.key, this.service});
  final ClassroomUsageService? service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final api = useMemoized(() => service ?? ClassroomUsageService(), [
      service,
    ]);
    final date = useState(DateTime.now().toUtc().add(const Duration(hours: 8)));
    final campuses = useState<List<ClassroomChoice>>([]);
    final buildings = useState<List<ClassroomChoice>>([]);
    final campus = useState<String?>(null);
    final building = useState<String?>(null);
    final rooms = useState<List<ClassroomUsage>?>(null);
    final busy = useState(false);
    final optionsError = useState<Object?>(null);
    final error = useState<Object?>(null);
    final sequence = useRef(0);
    String dateText() => DateFormat('yyyy-MM-dd').format(date.value);

    void clearResults() {
      rooms.value = null;
      error.value = null;
    }

    Future<void> loadOptions({bool initial = false}) async {
      final ticket = ++sequence.value;
      busy.value = true;
      optionsError.value = null;
      clearResults();
      bool current() => context.mounted && ticket == sequence.value;
      try {
        if (initial) {
          final values = await api.campuses(dateText());
          if (!current()) return;
          campuses.value = values;
          campus.value = values.firstOrNull?.value;
        }
        if (campus.value == null) return;
        final previousBuilding = building.value;
        buildings.value = [];
        building.value = null;
        final values = await api.buildings(dateText(), campus.value!);
        if (!current()) return;
        buildings.value = values;
        building.value = values.any((item) => item.value == previousBuilding)
            ? previousBuilding
            : values.firstOrNull?.value;
      } catch (e) {
        if (current()) optionsError.value = e;
      } finally {
        if (current()) busy.value = false;
      }
    }

    Future<void> query() async {
      if (busy.value ||
          campus.value == null ||
          building.value == null ||
          optionsError.value != null) {
        return;
      }
      final ticket = ++sequence.value;
      final selectedDate = dateText();
      final selectedCampus = campus.value!;
      final selectedBuilding = building.value!;
      busy.value = true;
      clearResults();
      bool current() => context.mounted && ticket == sequence.value;
      try {
        final values = await api.usage(
          selectedDate,
          selectedCampus,
          selectedBuilding,
        );
        if (current()) rooms.value = values;
      } catch (e) {
        if (current()) error.value = e;
      } finally {
        if (current()) busy.value = false;
      }
    }

    useEffect(() {
      loadOptions(initial: true);
      return () {
        sequence.value++;
      };
    }, [api]);

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.classroomUsage)),
      body: AppListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 1 + (rooms.value?.length ?? 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsSection.list(
                  title: l10n.usageFilters,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: Text(l10n.selectDate),
                      subtitle: Text(dateText()),
                      onTap: busy.value
                          ? null
                          : () async {
                              final selected = await showDatePicker(
                                context: context,
                                initialDate: date.value,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (selected != null &&
                                  context.mounted &&
                                  !DateUtils.isSameDay(selected, date.value)) {
                                date.value = selected;
                                clearResults();
                              }
                            },
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            key: ValueKey('campus-${campus.value}'),
                            initialValue: campus.value,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: l10n.usageCampus,
                            ),
                            items: [
                              for (final item in campuses.value)
                                DropdownMenuItem(
                                  value: item.value,
                                  child: Text(item.label),
                                ),
                            ],
                            onChanged: busy.value
                                ? null
                                : (value) {
                                    if (value == null ||
                                        value == campus.value) {
                                      return;
                                    }
                                    campus.value = value;
                                    loadOptions();
                                  },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            key: ValueKey('building-${building.value}'),
                            initialValue: building.value,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: l10n.usageBuilding,
                            ),
                            items: [
                              for (final item in buildings.value)
                                DropdownMenuItem(
                                  value: item.value,
                                  child: Text(item.label),
                                ),
                            ],
                            onChanged: busy.value
                                ? null
                                : (value) {
                                    if (value == null ||
                                        value == building.value) {
                                      return;
                                    }
                                    building.value = value;
                                    clearResults();
                                  },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: FilledButton(
                    onPressed:
                        busy.value ||
                            campus.value == null ||
                            building.value == null ||
                            optionsError.value != null
                        ? null
                        : query,
                    child: Text(l10n.query),
                  ),
                ),
                if (busy.value) const LinearProgressIndicator(),
                if (optionsError.value != null ||
                    (!busy.value && buildings.value.isEmpty))
                  ListTile(
                    title: Text(
                      optionsError.value != null
                          ? l10n.loadingFailed('${optionsError.value}')
                          : l10n.noData,
                    ),
                    trailing: IconButton(
                      tooltip: l10n.retry,
                      onPressed: busy.value
                          ? null
                          : () => loadOptions(initial: campuses.value.isEmpty),
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                if (error.value != null)
                  ListTile(title: Text(l10n.loadingFailed('${error.value}'))),
                if (rooms.value != null) ...[
                  AppInfoCard(title: Text(l10n.usageLegend)),
                  if (rooms.value!.isEmpty) ListTile(title: Text(l10n.noData)),
                ],
              ],
            );
          }
          final room = rooms.value![index - 1];
          return AppSection(
            child: AppExpansionTile(
              key: PageStorageKey(
                '${dateText()}-${campus.value}-${building.value}-${room.name}',
              ),
              title: Text(room.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${room.capacity} · ${room.type}'),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (var section = 1; section <= 11; section++)
                          Tooltip(
                            message:
                                '${l10n.usagePeriod} $section · ${room.occupied(section) ? l10n.usageOccupied : l10n.usageFree}',
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 28,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: room.occupied(section)
                                    ? Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer
                                    : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$section${room.occupied(section) ? '•' : ''}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: room.occupied(section)
                                      ? Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              children: [
                if (room.occupancies.isEmpty)
                  ListTile(title: Text(l10n.usageAllFree)),
                for (final item in room.occupancies)
                  ListTile(
                    leading: Text('${item.start}–${item.end}'),
                    title: Text(item.event),
                    subtitle: item.occupant.isEmpty
                        ? null
                        : Text(item.occupant),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
