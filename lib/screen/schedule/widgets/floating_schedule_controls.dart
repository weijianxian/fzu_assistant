import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/constants/breakpoints.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';

/// 叠在横屏课表上方的操作按钮，按钮之间的空白允许点击底下的课表。
class FloatingScheduleControls extends StatelessWidget {
  const FloatingScheduleControls({
    super.key,
    required this.onSettings,
    this.onPrevious,
    this.onNext,
  });

  final VoidCallback onSettings;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final scale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );
    final controls = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Material(
          color: scheme.surfaceContainerHigh,
          elevation: 3,
          shadowColor: scheme.shadow.withValues(alpha: 0.2),
          shape: const StadiumBorder(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: HomeViewToggle(),
          ),
        ),
        _FloatingButton(
          icon: Icons.settings_outlined,
          tooltip: l10n.homeSettings,
          onPressed: onSettings,
        ),
        _FloatingButton(
          icon: Icons.chevron_left,
          tooltip: l10n.schedulePreviousWeek,
          onPressed: onPrevious,
        ),
        _FloatingButton(
          icon: Icons.chevron_right,
          tooltip: l10n.scheduleNextWeek,
          onPressed: onNext,
        ),
      ],
    );

    return Padding(
      // 只覆盖时间轴区域，日期列/周次表头始终可以直接点击。
      padding: EdgeInsets.fromLTRB(
        kScheduleDateColumnWidth * scale + 12,
        12,
        12,
        12,
      ),
      child: controls,
    );
  }
}

class _FloatingButton extends StatelessWidget {
  const _FloatingButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 3,
      shadowColor: scheme.shadow.withValues(alpha: 0.2),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}
