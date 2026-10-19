import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_async_data.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/learning_center.dart';
import 'package:fzu_assistant/service/api/learning_center_service.dart';

class LearningSeatTimesPage extends HookWidget {
  const LearningSeatTimesPage({
    super.key,
    required this.spaceId,
    required this.date,
    required this.floor,
    required this.seatName,
  });
  final String spaceId, date, floor, seatName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final querying = useState(false);
    final data = useAsyncData<List<LearningTimeSlot>>(() async {
      querying.value = true;
      try {
        return await LearningCenterService.instance.seatTimes(spaceId, date);
      } finally {
        if (context.mounted) querying.value = false;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.learningSeatTimes),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: querying.value ? null : data.refresh,
          ),
        ],
      ),
      body: ToolPageWrapper(
        loading: data.loading,
        error: data.error,
        hasData: data.data?.isNotEmpty == true,
        emptyText: l10n.noData,
        refreshTime: data.updatedAt,
        onRefresh: () async {
          if (!querying.value) await data.refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.learningSeatLabel(floor, seatName),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(date, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            if (querying.value) const LinearProgressIndicator(),
            if (data.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(data.error!),
              ),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                children: [
                  for (final slot in data.data ?? <LearningTimeSlot>[])
                    SizedBox(
                      width: constraints.maxWidth / 4,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Material(
                          color: slot.available
                              ? colors.primaryContainer
                              : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 12,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  slot.text,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: slot.available
                                        ? colors.onPrimaryContainer
                                        : colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  slot.available
                                      ? l10n.learningAvailable
                                      : l10n.learningOccupied,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: slot.available
                                        ? colors.onPrimaryContainer
                                        : colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
