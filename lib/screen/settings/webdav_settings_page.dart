import 'package:fzu_assistant/common/widget/layout/app_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widget/input/password_field.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/webdav_sync_service.dart';
import 'package:intl/intl.dart';
import 'package:fzu_assistant/common/widget/layout/app_scaffold.dart';

class WebDavSettingsPage extends HookWidget {
  const WebDavSettingsPage({super.key, this.service});
  final WebDavSyncService? service;

  @override
  Widget build(BuildContext context) {
    final api = useMemoized(() => service ?? WebDavSyncService.instance, [
      service,
    ]);
    final settings = AppSettingsProvider.of(context);
    final l10n = AppLocalizations.of(context)!;
    final directory = useTextEditingController();
    final username = useTextEditingController();
    final password = useTextEditingController();
    final busy = useState(true);
    final error = useState<String?>(null);
    final automatic = useState(false);

    useEffect(() {
      () async {
        try {
          final config = await api.loadConfig();
          final enabled = await api.loadAutoSyncEnabled();
          if (!context.mounted) return;
          directory.text = config.directory;
          username.text = config.username;
          password.text = config.password;
          automatic.value = enabled;
        } catch (e) {
          if (context.mounted) error.value = e.toString();
        } finally {
          if (context.mounted) busy.value = false;
        }
      }();
      return null;
    }, [api]);

    WebDavConfig config() => WebDavConfig(
      directory: directory.text,
      username: username.text,
      password: password.text,
    );

    Widget summary(WebDavSnapshot snapshot) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${l10n.webdavRemoteUpdated}: ${DateFormat('yyyy-MM-dd HH:mm').format(snapshot.createdAt.toLocal())}',
        ),
        Text('${l10n.webdavCustomCourses}: ${snapshot.customCourseCount}'),
        Text('${l10n.webdavHiddenCourses}: ${snapshot.hiddenCourseCount}'),
      ],
    );

    Future<bool> confirm(
      String title,
      String description,
      WebDavSnapshot snapshot,
    ) async =>
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: AppSingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(description),
                  const SizedBox(height: 16),
                  summary(snapshot),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.webdavCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.webdavConfirm),
              ),
            ],
          ),
        ) ??
        false;

    Future<void> perform(
      Future<String?> Function(WebDavConfig config) action, {
      bool saveConfiguration = true,
    }) async {
      if (busy.value) return;
      busy.value = true;
      error.value = null;
      try {
        final message = await api.exclusive(() async {
          final current = config();
          if (saveConfiguration) await api.saveConfig(current);
          return action(current);
        });
        if (context.mounted && message != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      } catch (e) {
        if (context.mounted) error.value = e.toString();
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.webdavSync)),
      body: AppListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.webdavDescription),
          const SizedBox(height: 20),
          TextField(
            controller: directory,
            enabled: !busy.value,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.webdavDirectory,
              prefixIcon: const Icon(Icons.link_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              helperText: l10n.webdavDirectoryHint,
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: username,
            enabled: !busy.value,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.webdavUsername,
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          PasswordField(controller: password, enabled: !busy.value),
          const SizedBox(height: 16),
          Text(l10n.webdavTestDescription),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.webdavAutoSync),
            subtitle: Text(l10n.webdavAutoSyncDescription),
            value: automatic.value,
            onChanged: busy.value
                ? null
                : (enabled) => perform((_) async {
                    await api.setAutoSyncEnabled(enabled);
                    if (context.mounted) automatic.value = enabled;
                    return null;
                  }, saveConfiguration: enabled),
          ),
          if (busy.value) const LinearProgressIndicator(),
          if (error.value != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SelectableText(
                error.value!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: busy.value
                    ? null
                    : () => perform((_) async => l10n.webdavSaved),
                icon: const Icon(Icons.save_outlined),
                label: Text(l10n.webdavSave),
              ),
              OutlinedButton.icon(
                onPressed: busy.value
                    ? null
                    : () => perform((current) async {
                        await api.testConnection(current);
                        return l10n.webdavConnectionValid;
                      }, saveConfiguration: false),
                icon: const Icon(Icons.network_check),
                label: Text(l10n.webdavTestConnection),
              ),
              FilledButton.icon(
                onPressed: busy.value
                    ? null
                    : () => perform((current) async {
                        final local = await api.exportSnapshot();
                        final remote = await api.readRemote(current);
                        if (!context.mounted) return null;
                        if (!await confirm(
                          l10n.webdavUpload,
                          remote.snapshot == null
                              ? l10n.webdavCreateDescription
                              : l10n.webdavUploadDescription,
                          remote.snapshot ?? local,
                        )) {
                          return null;
                        }
                        await api.upload(current, local, remote);
                        await api.rememberSynced(current, local);
                        return l10n.webdavUploaded;
                      }),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(l10n.webdavUpload),
              ),
              OutlinedButton.icon(
                onPressed: busy.value
                    ? null
                    : () => perform((current) async {
                        final remote = await api.readRemote(current);
                        final snapshot = remote.snapshot;
                        if (snapshot == null) {
                          throw Exception(l10n.webdavNotFound);
                        }
                        if (!context.mounted) return null;
                        if (!await confirm(
                          l10n.webdavDownload,
                          l10n.webdavDownloadDescription,
                          snapshot,
                        )) {
                          return null;
                        }
                        await api.restore(
                          snapshot,
                          apply: (value) =>
                              applyWebDavSettings(settings, value),
                        );
                        await api.rememberSynced(current, snapshot);
                        return l10n.webdavDownloaded;
                      }),
                icon: const Icon(Icons.cloud_download_outlined),
                label: Text(l10n.webdavDownload),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
