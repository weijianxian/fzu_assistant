import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_async_data.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/learning_center.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/toolbox/learning_center/learning_center_widgets.dart';
import 'package:fzu_assistant/service/api/learning_center_service.dart';

class LearningAvailableSeatsPage extends HookWidget {
  const LearningAvailableSeatsPage({
    super.key,
    required this.date,
    required this.begin,
    required this.end,
    required this.floor,
  });
  final String date, begin, end, floor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final api = LearningCenterService.instance;
    final acting = useState(false);
    final querying = useState(false);
    final data = useAsyncData<List<LearningSeat>>(() async {
      querying.value = true;
      try {
        return await api.querySeats(
          date: date,
          begin: begin,
          end: end,
          floor: floor,
        );
      } catch (e) {
        if (context.mounted) await showLearningError(context, e);
        rethrow;
      } finally {
        if (context.mounted) querying.value = false;
      }
    });

    Future<void> selectSeat(LearningSeat seat) async {
      if (acting.value || querying.value) return;
      final selectedDate = date;
      final start = begin;
      final finish = end;
      acting.value = true;
      try {
        if (!seat.available) {
          await context.pushNamed(
            AppRoutes.learningSeatTimes,
            arguments: LearningSeatTimesArgs(
              spaceId: seat.id,
              date: date,
              floor: seat.floor,
              seatName: seat.name,
            ),
          );
          return;
        }
        if (!await confirmLearningAction(
          context,
          l10n.learningReserve,
          '${l10n.learningSeatLabel(seat.floor, seat.name)}\n$selectedDate $start–$finish',
        )) {
          return;
        }
        await api.reserve(
          spaceId: seat.id,
          date: selectedDate,
          begin: start,
          end: finish,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.learningReserved)));
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (context.mounted) await showLearningError(context, e);
      } finally {
        if (context.mounted) acting.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.learningSeatList),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: acting.value || querying.value ? null : data.refresh,
          ),
        ],
      ),
      body: ToolPageWrapper(
        loading: data.loading,
        error: data.error,
        hasData: data.data?.isNotEmpty == true,
        emptyText: l10n.learningNoSeats,
        onRefresh: () async {
          if (!acting.value && !querying.value) await data.refresh();
        },
        refreshTime: data.updatedAt,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '$date $begin–$end · ${l10n.learningFloor(floor)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(l10n.learningSeatLegend),
            const SizedBox(height: 8),
            if (acting.value || querying.value) const LinearProgressIndicator(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final seat in data.data ?? <LearningSeat>[])
                  SizedBox(
                    width: 80,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: seat.available
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                      ),
                      onPressed:
                          acting.value || querying.value || seat.id.isEmpty
                          ? null
                          : () => selectSeat(seat),
                      child: Text(seat.name),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
