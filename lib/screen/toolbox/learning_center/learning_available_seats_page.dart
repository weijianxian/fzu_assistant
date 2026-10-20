import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_async_data.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/constants/breakpoints.dart';
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
    final scroll = useScrollController();
    final groups = useMemoized(() {
      final grouped = <LearningSeatArea?, List<LearningSeat>>{};
      for (final seat in data.data ?? <LearningSeat>[]) {
        (grouped[LearningSeatArea.forSeat(seat.name)] ??= []).add(seat);
      }
      for (final seats in grouped.values) {
        seats.sort((a, b) {
          final byNumber = (int.tryParse(a.name) ?? 100000).compareTo(
            int.tryParse(b.name) ?? 100000,
          );
          return byNumber != 0 ? byNumber : a.name.compareTo(b.name);
        });
      }
      return [
        for (final area in [...LearningSeatArea.all, null])
          if (grouped.containsKey(area)) (area: area, seats: grouped[area]!),
      ];
    }, [data.data]);
    final sectionKeys = useMemoized(
      () => [for (final _ in groups) GlobalKey()],
      [groups],
    );

    String areaTitle(LearningSeatArea? area) => area == null
        ? l10n.learningOtherArea
        : l10n.learningSeatArea(area.code);

    String seatType(LearningSeatArea? area) => switch (area?.type) {
      LearningSeatType.single => l10n.learningSingleSeat,
      LearningSeatType.shared => l10n.learningSharedSeat,
      LearningSeatType.sofa => l10n.learningSofaSeat,
      LearningSeatType.sharedAndSofa => l10n.learningSharedAndSofaSeat,
      null => '',
    };

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
            tooltip: l10n.learningSeatGuide,
            icon: const Icon(Icons.map_outlined),
            onPressed: () => showLearningSeatGuide(context),
          ),
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: acting.value || querying.value ? null : data.refresh,
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: ToolPageWrapper(
              scrollController: scroll,
              loading: data.loading,
              error: data.error,
              hasData: data.data?.isNotEmpty == true,
              emptyText: l10n.learningNoSeats,
              onRefresh: () async {
                if (!acting.value && !querying.value) await data.refresh();
              },
              refreshTime: data.updatedAt,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$date $begin–$end · ${l10n.learningFloor(floor)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(l10n.learningSeatLegend),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 4,
                          child: acting.value || querying.value
                              ? const LinearProgressIndicator()
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                for (var index = 0; index < groups.length; index++) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      key: sectionKeys[index],
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${areaTitle(groups[index].area)}'
                            '${groups[index].area == null ? '' : '  ${groups[index].area!.start}–${groups[index].area!.end}'}'
                            '  ${seatType(groups[index].area)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.learningAreaSummary(
                              groups[index].seats
                                  .where((seat) => seat.available)
                                  .length,
                              groups[index].seats
                                  .where((seat) => !seat.available)
                                  .length,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: kLearningSeatMaxWidth,
                            mainAxisExtent: kLearningSeatHeight,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: groups[index].seats.length,
                      itemBuilder: (context, seatIndex) {
                        final seat = groups[index].seats[seatIndex];
                        return OutlinedButton(
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
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (groups.length > 1)
            SizedBox(
              width: kLearningAreaNavigationWidth,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  primary: false,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      for (var index = 0; index < groups.length; index++)
                        TextButton(
                          onPressed: () {
                            final target = sectionKeys[index].currentContext;
                            if (target != null) {
                              Scrollable.ensureVisible(
                                target,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          },
                          child: Text(
                            groups[index].area?.code ?? l10n.learningOtherArea,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
