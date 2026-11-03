import 'package:fzu_assistant/common/widget/layout/app_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';

class ThirdPartySettingsPage extends HookWidget {
  const ThirdPartySettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final l10n = AppLocalizations.of(context)!;
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.thirdPartyServices)),
      body: AppListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.thirdPartyDescription),
          ),
          FeatureAccessTile(
            title: l10n.west2AdjustmentsEnabled,
            description: l10n.west2AdjustmentsDescription,
            notifier: settings.west2AdjustmentsAccess,
          ),
          FeatureAccessTile(
            title: l10n.pastPapers,
            description: l10n.pastPapersDescription,
            notifier: settings.papersAccess,
          ),
        ],
      ),
    );
  }
}

class FeatureAccessTile extends HookWidget {
  const FeatureAccessTile({
    super.key,
    required this.title,
    required this.description,
    required this.notifier,
  });
  final String title, description;
  final ValueNotifier<FeatureAccess> notifier;
  @override
  Widget build(BuildContext context) {
    final value = useValueListenable(notifier);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(description),
          const SizedBox(height: 12),
          SegmentedButton<FeatureAccess>(
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            style: const ButtonStyle(
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
            ),
            segments: [
              ButtonSegment(
                value: FeatureAccess.hide,
                label: Text(l10n.accessHide),
              ),
              ButtonSegment(
                value: FeatureAccess.tip,
                label: Text(l10n.accessTip),
              ),
              ButtonSegment(
                value: FeatureAccess.allow,
                label: Text(l10n.accessAllow),
              ),
            ],
            selected: {value},
            onSelectionChanged: (selection) =>
                notifier.value = selection.single,
          ),
        ],
      ),
    );
  }
}
