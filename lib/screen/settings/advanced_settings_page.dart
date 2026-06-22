import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/utils/github_proxy.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

class AdvancedSettingsPage extends HookWidget {
  const AdvancedSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final l10n = AppLocalizations.of(context)!;
    final controller = useTextEditingController(
      text: settings.githubProxyBaseUrl.value,
    );

    useEffect(() {
      void syncController() {
        final value = settings.githubProxyBaseUrl.value;
        if (controller.text == value) return;
        controller.text = value;
      }

      settings.githubProxyBaseUrl.addListener(syncController);
      return () => settings.githubProxyBaseUrl.removeListener(syncController);
    }, [settings]);

    void normalizeProxyUrl() {
      final normalized = GitHubProxy.normalizeBaseUrl(controller.text);
      controller.text = normalized;
      settings.githubProxyBaseUrl.value = normalized;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.advancedSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Section(
            title: l10n.githubProxy,
            child: Column(
              children: [
                SettingSwitchTile(
                  notifier: settings.githubProxyEnabled,
                  title: Text(l10n.githubProxyEnabled),
                  subtitle: Text(l10n.githubProxyDescription),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: ValueListenableBuilder(
                    valueListenable: settings.githubProxyEnabled,
                    builder: (_, enabled, _) => TextField(
                      controller: controller,
                      enabled: enabled,
                      decoration: InputDecoration(
                        labelText: l10n.githubProxyBaseUrl,
                        helperText: l10n.githubProxyBaseUrlDescription,
                        hintText: GitHubProxy.defaultBaseUrl,
                        suffixIcon: IconButton(
                          tooltip: l10n.reset,
                          icon: const Icon(Icons.restore),
                          onPressed: enabled
                              ? () {
                                  controller.text = GitHubProxy.defaultBaseUrl;
                                  settings.githubProxyBaseUrl.value =
                                      GitHubProxy.defaultBaseUrl;
                                }
                              : null,
                        ),
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      onChanged: (v) => settings.githubProxyBaseUrl.value = v,
                      onSubmitted: (_) => normalizeProxyUrl(),
                      onEditingComplete: normalizeProxyUrl,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
