import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/utility_payment.dart';
import 'package:url_launcher/url_launcher.dart';

class UtilityPaymentPage extends HookWidget {
  const UtilityPaymentPage({super.key, this.launcher});
  final Future<bool> Function(Uri uri)? launcher;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final busy = useState<UtilityCampus?>(null);
    final mobile =
        !kIsWeb &&
        {
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform);
    Future<bool> open(Uri uri) async {
      try {
        return await (launcher?.call(uri) ??
            launchUrl(uri, mode: LaunchMode.externalApplication));
      } catch (_) {
        return false;
      }
    }

    Future<void> showMissingApp(UtilityCampus campus) async {
      final uri = campus.paymentUri;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.utilityOpenFailed),
          content: AppSingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.utilityInstallDescription),
                const SizedBox(height: 12),
                SelectableText(uri.toString()),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.utilityClose),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: uri.toString()));
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.utilityCopied)));
                }
              },
              child: Text(l10n.utilityCopyLink),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final success = await open(
                  UtilityPaymentLinks.installationUri(
                    ios: defaultTargetPlatform == TargetPlatform.iOS,
                  ),
                );
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.utilityDownloadFailed)),
                  );
                }
              },
              child: Text(l10n.utilityInstall),
            ),
          ],
        ),
      );
    }

    String name(UtilityCampus campus) => switch (campus) {
      UtilityCampus.qishan => l10n.utilityCampusQishan,
      UtilityCampus.tongpan => l10n.utilityCampusTongpan,
      UtilityCampus.jinjiang => l10n.utilityCampusJinjiang,
      UtilityCampus.yishan => l10n.utilityCampusYishan,
    };

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.utilityPayment)),
      body: ToolPageWrapper(
        loading: false,
        emptyText: l10n.noData,
        onRefresh: () async {},
        child: AppListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                mobile ? l10n.utilityDescription : l10n.utilityMobileRequired,
              ),
            ),
            if (mobile)
              AppSection.list(
                children: [
                  for (final campus in UtilityCampus.values)
                    ListTile(
                      leading: const Icon(Icons.location_city_outlined),
                      title: Text(name(campus)),
                      trailing: busy.value == campus
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.open_in_new),
                      onTap: busy.value != null
                          ? null
                          : () async {
                              busy.value = campus;
                              try {
                                final success = await open(campus.paymentUri);
                                if (!success && context.mounted) {
                                  await showMissingApp(campus);
                                }
                              } finally {
                                if (context.mounted) busy.value = null;
                              }
                            },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
