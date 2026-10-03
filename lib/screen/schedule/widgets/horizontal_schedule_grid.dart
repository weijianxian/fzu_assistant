import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/course_sessions.dart';
import 'package:fzu_assistant/constants/breakpoints.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';

/// 课程、表头和时间线共用的横向节次坐标，午休与晚饭前留出分组间隔。
class HorizontalScheduleMetrics {
  const HorizontalScheduleMetrics({
    required this.periodWidth,
    required this.groupGap,
  });

  final double periodWidth;
  final double groupGap;

  double start(int index) => index * periodWidth + (index ~/ 4) * groupGap;
  double end(int index) => start(index) + periodWidth;
  double get width => end(maxCoursePeriod - 1);

  double? timeOffset(int minutes, {bool clampToSchedule = false}) {
    int parse(String time) {
      final parts = time.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }

    for (var i = 0; i < maxCoursePeriod; i++) {
      final from = parse(coursePeriodTimes[i].$1);
      final to = parse(coursePeriodTimes[i].$2);
      if (minutes >= from && minutes <= to) {
        return start(i) + (minutes - from) / (to - from) * periodWidth;
      }
      if (i + 1 < maxCoursePeriod) {
        final next = parse(coursePeriodTimes[i + 1].$1);
        if (minutes > to && minutes < next) {
          return end(i) +
              (minutes - to) / (next - to) * (start(i + 1) - end(i));
        }
      }
    }
    if (clampToSchedule) {
      return minutes < parse(coursePeriodTimes.first.$1) ? 0 : width;
    }
    return null;
  }
}

class HorizontalScheduleGrid extends HookWidget {
  const HorizontalScheduleGrid({
    super.key,
    required this.week,
    required this.weekdays,
    required this.weekDates,
    required this.now,
    required this.onRefresh,
    required this.cardBuilder,
  });

  final int week;
  final List<String> weekdays;
  final List<DateTime> weekDates;
  final DateTime now;
  final Future<void> Function() onRefresh;
  final List<Widget> Function(int weekday, HorizontalScheduleMetrics metrics)
  cardBuilder;

  @override
  Widget build(BuildContext context) {
    final horizontalController = useScrollController();
    final headerController = useScrollController();
    final verticalController = useScrollController();
    final datesController = useScrollController();
    final scheme = Theme.of(context).colorScheme;
    final showScrollbars = switch (Theme.of(context).platform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };
    final scale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );
    final dateWidth = kScheduleDateColumnWidth * scale;
    final groupHeight = 28.0 * scale;
    final headerHeight = 82.0 * scale;
    final groupGap = 16.0 * scale;
    final today = DateTime(now.year, now.month, now.day);
    final todayIndex = weekDates.indexOf(today);
    final minutes = now.hour * 60 + now.minute;

    useEffect(
      () {
        void syncHeader() {
          if (!horizontalController.hasClients ||
              !headerController.hasClients) {
            return;
          }
          final target = horizontalController.offset.clamp(
            0.0,
            headerController.position.maxScrollExtent,
          );
          if (headerController.offset != target) {
            headerController.jumpTo(target);
          }
        }

        horizontalController.addListener(syncHeader);
        void syncVertical(ScrollController source, ScrollController target) {
          if (!source.hasClients || !target.hasClients) {
            return;
          }
          final offset = source.offset.clamp(
            0.0,
            target.position.maxScrollExtent,
          );
          if ((target.offset - offset).abs() > 0.01) {
            target.jumpTo(offset);
          }
        }

        void syncDates() => syncVertical(verticalController, datesController);
        void syncBody() => syncVertical(datesController, verticalController);
        verticalController.addListener(syncDates);
        datesController.addListener(syncBody);
        return () {
          horizontalController.removeListener(syncHeader);
          verticalController.removeListener(syncDates);
          datesController.removeListener(syncBody);
        };
      },
      [
        horizontalController,
        headerController,
        verticalController,
        datesController,
      ],
    );

    return ColoredBox(
      color: scheme.surface,
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final timelineWidth = math.max(
              0.0,
              constraints.maxWidth - dateWidth,
            );
            final viewportHeight = math.max(
              0.0,
              constraints.maxHeight - headerHeight,
            );
            final metrics = HorizontalScheduleMetrics(
              periodWidth: math.max(
                kScheduleMinPeriodWidth * scale,
                (timelineWidth - groupGap * 2) / maxCoursePeriod,
              ),
              groupGap: groupGap,
            );
            final dayHeight = math.max(
              kScheduleMinDayHeight * scale,
              viewportHeight / 7,
            );
            final bodyHeight = dayHeight * 7;
            final nowOffset = todayIndex < 0
                ? null
                : metrics.timeOffset(minutes);

            return HookBuilder(
              builder: (context) {
                // 只在进入、日期/周次变化及窗口尺寸变化时聚焦；分钟更新不打断手动浏览。
                useEffect(
                  () {
                    var active = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!active ||
                          !verticalController.hasClients ||
                          !horizontalController.hasClients) {
                        return;
                      }
                      final dayOffset = todayIndex < 0
                          ? 0.0
                          : (todayIndex + 0.5) * dayHeight - viewportHeight / 2;
                      final timeOffset = todayIndex < 0
                          ? 0.0
                          : metrics.timeOffset(
                                  minutes,
                                  clampToSchedule: true,
                                )! -
                                timelineWidth / 2;
                      verticalController.jumpTo(
                        dayOffset.clamp(
                          0.0,
                          verticalController.position.maxScrollExtent,
                        ),
                      );
                      horizontalController.jumpTo(
                        timeOffset.clamp(
                          0.0,
                          horizontalController.position.maxScrollExtent,
                        ),
                      );
                      if (headerController.hasClients) {
                        headerController.jumpTo(
                          horizontalController.offset.clamp(
                            0.0,
                            headerController.position.maxScrollExtent,
                          ),
                        );
                      }
                    });
                    return () => active = false;
                  },
                  [
                    todayIndex,
                    weekDates.firstOrNull,
                    constraints.maxWidth,
                    constraints.maxHeight,
                    scale,
                  ],
                );

                return Column(
                  children: [
                    SizedBox(
                      height: headerHeight,
                      child: Row(
                        children: [
                          Container(
                            key: const ValueKey('schedule-week-header'),
                            width: dateWidth,
                            color: scheme.surfaceContainerLow,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              AppLocalizations.of(context)!.weekN(week),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Expanded(
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context)
                                  .copyWith(scrollbars: false),
                              child: SingleChildScrollView(
                                key: const ValueKey('schedule-header-scroll'),
                                controller: headerController,
                                scrollDirection: Axis.horizontal,
                                physics: const NeverScrollableScrollPhysics(),
                                child: SizedBox(
                                  width: metrics.width,
                                  height: headerHeight,
                                  child: _TimeHeader(
                                    metrics: metrics,
                                    groupHeight: groupHeight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: onRefresh,
                        notificationPredicate: (notification) =>
                            notification.metrics.axis == Axis.vertical &&
                            notification.depth == 0,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: dateWidth,
                              child: ScrollConfiguration(
                                behavior: ScrollConfiguration.of(context)
                                    .copyWith(scrollbars: false),
                                child: SingleChildScrollView(
                                  key: const ValueKey('schedule-date-scroll'),
                                  controller: datesController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: Column(
                                    children: [
                                      for (var day = 0; day < 7; day++)
                                        _DayLabel(
                                          weekday: weekdays[day],
                                          date: weekDates.isEmpty
                                              ? null
                                              : weekDates[day],
                                          isToday: day == todayIndex,
                                          height: dayHeight,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final timeline = SingleChildScrollView(
                                    key: const ValueKey('schedule-day-scroll'),
                                    controller: verticalController,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: ScrollConfiguration(
                                      behavior: ScrollConfiguration.of(context)
                                          .copyWith(
                                            scrollbars: false,
                                            dragDevices: {
                                              PointerDeviceKind.touch,
                                              PointerDeviceKind.mouse,
                                              PointerDeviceKind.stylus,
                                              PointerDeviceKind.trackpad,
                                            },
                                          ),
                                      child: SingleChildScrollView(
                                        key: const ValueKey(
                                          'schedule-time-scroll',
                                        ),
                                        controller: horizontalController,
                                        scrollDirection: Axis.horizontal,
                                        physics: const ClampingScrollPhysics(),
                                        child: SizedBox(
                                          width: metrics.width,
                                          height: bodyHeight,
                                          child: _TimeBody(
                                            metrics: metrics,
                                            dayHeight: dayHeight,
                                            todayIndex: todayIndex,
                                            nowOffset: nowOffset,
                                            cardBuilder: cardBuilder,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                  if (!showScrollbars) {
                                    return ScrollConfiguration(
                                      behavior: ScrollConfiguration.of(context)
                                          .copyWith(scrollbars: false),
                                      child: timeline,
                                    );
                                  }
                                  return Scrollbar(
                                    controller: horizontalController,
                                    thumbVisibility:
                                        metrics.width > timelineWidth + 0.5,
                                    scrollbarOrientation:
                                        ScrollbarOrientation.bottom,
                                    notificationPredicate: (notification) =>
                                        notification.metrics.axis ==
                                        Axis.horizontal,
                                    child: timeline,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TimeHeader extends StatelessWidget {
  const _TimeHeader({required this.metrics, required this.groupHeight});
  final HorizontalScheduleMetrics metrics;
  final double groupHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        for (final group in [
          (0, 3, l10n.scheduleMorning),
          (4, 7, l10n.scheduleAfternoon),
          (8, maxCoursePeriod - 1, l10n.scheduleEvening),
        ])
          Positioned(
            left: metrics.start(group.$1),
            width: metrics.end(group.$2) - metrics.start(group.$1),
            height: groupHeight,
            child: Center(
              child: Text(
                group.$3,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        for (var p = 0; p < maxCoursePeriod; p++)
          Positioned(
            left: metrics.start(p),
            width: metrics.periodWidth,
            top: groupHeight,
            bottom: 0,
            child: _PeriodHeader(index: p),
          ),
      ],
    );
  }
}

class _TimeBody extends StatelessWidget {
  const _TimeBody({
    required this.metrics,
    required this.dayHeight,
    required this.todayIndex,
    required this.nowOffset,
    required this.cardBuilder,
  });
  final HorizontalScheduleMetrics metrics;
  final double dayHeight;
  final int todayIndex;
  final double? nowOffset;
  final List<Widget> Function(int weekday, HorizontalScheduleMetrics metrics)
  cardBuilder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        for (var day = 0; day < 7; day++)
          Positioned(
            top: day * dayHeight,
            left: 0,
            right: 0,
            height: dayHeight,
            child: DecoratedBox(
              key: day == todayIndex
                  ? const ValueKey('schedule-today-row')
                  : null,
              decoration: BoxDecoration(
                color: day == todayIndex
                    ? scheme.primary.withValues(alpha: 0.07)
                    : null,
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ),
        for (final p in [4, 8])
          Positioned(
            left: metrics.end(p - 1),
            top: 0,
            bottom: 0,
            width: metrics.groupGap,
            child: ColoredBox(color: scheme.surfaceContainerLow),
          ),
        for (var p = 0; p < maxCoursePeriod; p++)
          Positioned(
            left: metrics.start(p),
            top: 0,
            bottom: 0,
            width: 1,
            child: ColoredBox(
              color: scheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
        for (var day = 0; day < 7; day++)
          Positioned(
            top: day * dayHeight,
            left: 0,
            right: 0,
            height: dayHeight,
            child: Stack(children: cardBuilder(day + 1, metrics)),
          ),
        if (nowOffset != null)
          Positioned(
            left: nowOffset!.clamp(0.0, metrics.width - 2),
            top: 0,
            bottom: 0,
            width: 2,
            child: IgnorePointer(
              child: ColoredBox(
                key: const ValueKey('schedule-current-time'),
                color: scheme.primary.withValues(alpha: 0.7),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({
    required this.weekday,
    required this.date,
    required this.isToday,
    required this.height,
  });
  final String weekday;
  final DateTime? date;
  final bool isToday;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isToday ? scheme.primaryContainer : scheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            weekday,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isToday ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
          ),
          if (date != null) ...[
            const SizedBox(height: 4),
            Text(
              '${date!.month}/${date!.day}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isToday
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slot = coursePeriodTimes[index];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppLocalizations.of(context)!.classPeriod(index + 1),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 3),
        Text(
          '${slot.$1}–${slot.$2}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
