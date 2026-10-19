import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/learning_center.dart';
import 'package:fzu_assistant/router/app_routes.dart';

class LearningSeatsPage extends HookWidget {
  const LearningSeatsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final initial = useMemoized(() {
      final now = learningBeijingTime(DateTime.now());
      return DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: now.hour >= 22 ? 1 : 0));
    });
    final date = useState(initial);
    final begin = useState<String?>(null);
    final end = useState<String?>(null);
    final floor = useState('4');
    final navigating = useState(false);
    final times = useMemoized(
      () => List.generate(
        30,
        (i) =>
            '${(8 + i ~/ 2).toString().padLeft(2, '0')}:${i.isEven ? '00' : '30'}',
      ),
    );

    final clock = useState(DateTime.now());
    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 30), (_) {
        clock.value = DateTime.now();
      });
      return timer.cancel;
    }, const []);
    final today = learningBeijingTime(clock.value);
    final colors = Theme.of(context).colorScheme;
    final locked = navigating.value;

    Future<void> query() async {
      if (navigating.value || begin.value == null || end.value == null) return;
      navigating.value = true;
      try {
        await context.pushNamed(
          AppRoutes.learningAvailableSeats,
          arguments: LearningAvailableSeatsArgs(
            date: learningDate(date.value),
            begin: begin.value!,
            end: end.value!,
            floor: floor.value,
          ),
        );
      } finally {
        if (context.mounted) navigating.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.learningReserve)),
      body: ToolPageWrapper(
        loading: false,
        emptyText: l10n.learningNoSeats,
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Builder(
                    builder: (context) {
                      final day = DateTime(
                        today.year,
                        today.month,
                        today.day + i,
                      );
                      final selected =
                          learningDate(day) == learningDate(date.value);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Tooltip(
                            message: learningDate(day),
                            child: Material(
                              color: selected
                                  ? colors.primary
                                  : colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: locked
                                    ? null
                                    : () {
                                        date.value = day;
                                        begin.value = null;
                                        end.value = null;
                                      },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: selected
                                              ? colors.onPrimary
                                              : colors.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat.E(
                                          Localizations.localeOf(context)
                                              .toString(),
                                        ).format(day),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: selected
                                              ? colors.onPrimary
                                              : colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.learningSelectPeriod, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                children: [
                  for (final time in times)
                    Builder(
                      builder: (context) {
                        final instant = parseLearningDateTime(
                          '${learningDate(date.value)}T$time',
                        )!;
                        final startIndex = times.indexOf(begin.value ?? '');
                        final disabled =
                            !instant.isAfter(clock.value) ||
                            (startIndex >= 0 &&
                                times.indexOf(time) - startIndex > 8);
                        final selected =
                            time == begin.value || time == end.value;
                        final included =
                            begin.value != null &&
                            end.value != null &&
                            time.compareTo(begin.value!) > 0 &&
                            time.compareTo(end.value!) < 0;
                        return SizedBox(
                          width: constraints.maxWidth / 4,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Semantics(
                              selected: selected || included,
                              child: Material(
                                color: disabled
                                    ? colors.surfaceContainerHighest.withValues(
                                        alpha: 0.4,
                                      )
                                    : selected
                                    ? colors.primary
                                    : included
                                    ? colors.primary.withValues(alpha: 0.5)
                                    : colors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(8),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: locked || disabled
                                      ? null
                                      : () {
                                          if (begin.value == null) {
                                            begin.value = time;
                                          } else if (end.value == null) {
                                            if (time == begin.value) {
                                              begin.value = null;
                                            } else if (time.compareTo(
                                                  begin.value!,
                                                ) <
                                                0) {
                                              begin.value = time;
                                            } else {
                                              end.value = time;
                                            }
                                          } else {
                                            begin.value = null;
                                            end.value = null;
                                          }
                                        },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      time,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: disabled
                                            ? colors.onSurface.withValues(
                                                alpha: 0.38,
                                              )
                                            : selected || included
                                            ? colors.onPrimary
                                            : colors.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (begin.value != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '${learningDate(date.value)}  ${l10n.learningBegin}: ${begin.value} · ${l10n.learningEnd}: ${end.value ?? '—'}',
                  textAlign: TextAlign.center,
                ),
              ),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                SegmentedButton<String>(
                  segments: [
                    for (final f in ['4', '5'])
                      ButtonSegment(
                        value: f,
                        label: Text(l10n.learningFloor(f)),
                      ),
                  ],
                  selected: {floor.value},
                  onSelectionChanged: locked
                      ? null
                      : (v) {
                          floor.value = v.first;
                        },
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: locked || begin.value == null || end.value == null
                  ? null
                  : query,
              icon: const Icon(Icons.search),
              label: Text(l10n.query),
            ),
          ],
        ),
      ),
    );
  }
}
