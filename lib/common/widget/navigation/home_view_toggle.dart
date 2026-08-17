import 'package:flutter/material.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

class HomeViewToggle extends StatelessWidget {
  const HomeViewToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = AppSettingsProvider.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: settings.homeStyleKey,
      builder: (_, homeStyle, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: AppSettings.scheduleHomeStyle,
              label: Text(l10n.homeStyleSchedule),
            ),
            ButtonSegment(
              value: AppSettings.timelineHomeStyle,
              label: Text(l10n.homeStyleTimeline),
            ),
          ],
          selected: {homeStyle},
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 9),
            ),
          ),
          onSelectionChanged: (selection) =>
              settings.homeStyleKey.value = selection.first,
        ),
      ),
    );
  }
}
