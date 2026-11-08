import 'package:fzu_assistant/common/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widget/input/password_field.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/webdav_sync_service.dart';
import 'package:intl/intl.dart';

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
        Text('${l10n.webdavSchemaVersion}: ${snapshot.schemaVersion}'),
        Text(
          '${l10n.webdavAppVersion}: ${snapshot.appVersion?.label ?? l10n.webdavAppVersionUnknown}',
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
      Future<String?> Function(WebDavConfig config, bool Function() isCurrent)
      action, {
      bool saveConfiguration = true,
      bool configurationOnly = false,
    }) async {
      if (busy.value) return;
      busy.value = true;
      error.value = null;
      try {
        Future<String?> operation() async {
          final current = config();
          if (saveConfiguration) await api.saveConfig(current);
          final isCurrent = api.captureValidity();
          final result = await action(current, isCurrent);
          if (!configurationOnly && !isCurrent()) throw WebDavLocalChanged();
          return result;
        }

        // Configuration writes have their own serialized queue and invalidate
        // an older sync immediately, including from another settings page.
        final message = configurationOnly
            ? await operation()
            : await api.exclusive(operation);
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

    Future<String?> restorePreview(
      WebDavSnapshot snapshot,
      WebDavSnapshot local,
      bool Function() isCurrent,
    ) async {
      if (!context.mounted || !isCurrent()) return null;
      if (!await confirm(
        l10n.webdavHistoryRestore,
        l10n.webdavHistoryRestoreDescription,
        snapshot,
      )) {
        return null;
      }
      await api.restore(
        snapshot,
        expectedLocal: local,
        canApply: isCurrent,
        apply: (value) => applyWebDavSettings(settings, value),
      );
      // An old history selection has not been synced with the current cloud
      // backup. restore() clears the baseline, so automatic sync must request
      // a deliberate upload/download choice instead of replacing it again.
      return l10n.webdavDownloaded;
    }

    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.webdavSync),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: SizedBox(
            height: 4,
            child: busy.value
                ? const LinearProgressIndicator(minHeight: 4)
                : null,
          ),
        ),
      ),
      body: AppListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SettingsSection(
            title: l10n.settingsConnectionSection,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: directory,
                    enabled: !busy.value,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.webdavDirectory,
                      prefixIcon: const Icon(Icons.link_outlined),
                      hintText: l10n.webdavDirectoryHint,
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  PasswordField(controller: password, enabled: !busy.value),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: busy.value
                        ? null
                        : () => perform(
                            (current, isCurrent) async {
                              await api.testConnection(current);
                              if (!context.mounted || !isCurrent()) {
                                throw WebDavLocalChanged();
                              }
                              await api.saveConfig(
                                current,
                                canSave: () => context.mounted,
                              );
                              return l10n.webdavSaved;
                            },
                            saveConfiguration: false,
                            configurationOnly: true,
                          ),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(l10n.webdavSave),
                  ),
                ],
              ),
            ),
          ),
          SettingsSection(
            title: l10n.settingsAutoSyncSection,
            child: SettingSwitchTile.controlled(
              title: Text(l10n.webdavAutoSync),
              subtitle: Text(l10n.webdavAutoSyncDescription),
              value: automatic.value,
              onChanged: busy.value
                  ? null
                  : (enabled) => perform(
                      (_, _) async {
                        await api.setAutoSyncEnabled(enabled);
                        if (context.mounted) automatic.value = enabled;
                        return null;
                      },
                      saveConfiguration: enabled,
                      configurationOnly: true,
                    ),
            ),
          ),
          if (error.value != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SelectableText(
                error.value!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          SettingsSection(
            title: l10n.settingsManualSyncSection,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy.value
                        ? null
                        : () => perform((current, _) async {
                            await api.testConnection(current);
                            return l10n.webdavConnectionValid;
                          }, saveConfiguration: false),
                    icon: const Icon(Icons.network_check),
                    label: Text(l10n.webdavTestConnection),
                  ),
                  FilledButton.icon(
                    onPressed: busy.value
                        ? null
                        : () => perform((current, isCurrent) async {
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
                            if (!isCurrent() ||
                                (await api.exportSnapshot()).fingerprint !=
                                    local.fingerprint) {
                              throw WebDavLocalChanged();
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
                        : () => perform((current, isCurrent) async {
                            final local = await api.exportSnapshot();
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
                              expectedLocal: local,
                              canApply: isCurrent,
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
            ),
          ),
          SettingsSection.list(
            title: l10n.webdavHistory,
            children: [
              ChevronListTile(
                leading: const Icon(Icons.history),
                title: Text(l10n.webdavHistory),
                subtitle: Text(l10n.webdavHistoryDescription),
                onTap: busy.value
                    ? null
                    : () => perform((current, isCurrent) async {
                        final local = await api.exportSnapshot();
                        final entries = await api.listHistory(current);
                        if (!context.mounted || !isCurrent()) return null;
                        final selected = await showHalfScreenSheet<WebDavHistoryEntry>(
                          context,
                          builder: (controller) => Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  8,
                                  24,
                                  12,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    l10n.webdavHistory,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: entries.isEmpty
                                    ? AppListView(
                                        controller: controller,
                                        children: [
                                          AppInfoCard(
                                            title: Text(
                                              l10n.webdavHistoryEmpty,
                                            ),
                                          ),
                                        ],
                                      )
                                    : AppListView.grouped(
                                        controller: controller,
                                        itemCount: entries.length,
                                        itemBuilder: (sheetContext, index) {
                                          final entry = entries[index];
                                          return ChevronListTile(
                                            leading: const Icon(Icons.restore),
                                            title: Text(
                                              DateFormat('yyyy-MM-dd HH:mm')
                                                  .format(
                                                    entry.recordedAt.toLocal(),
                                                  ),
                                            ),
                                            subtitle: Text(
                                              [
                                                entry.reason ==
                                                        WebDavHistoryReason
                                                            .beforeUpload
                                                    ? l10n.webdavHistoryPrevious
                                                    : l10n.webdavHistorySaved,
                                                '${l10n.webdavSchemaVersion}: ${entry.schemaVersion}',
                                                '${l10n.webdavAppVersion}: ${entry.appVersion?.label ?? l10n.webdavAppVersionUnknown}',
                                              ].join('\n'),
                                            ),
                                            onTap: () =>
                                                Navigator.of(sheetContext)
                                                    .pop(entry),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        );
                        if (selected == null || !isCurrent()) return null;
                        final snapshot = await api.readHistorySnapshot(
                          current,
                          selected,
                        );
                        return restorePreview(snapshot, local, isCurrent);
                      }),
              ),
              ChevronListTile(
                leading: const Icon(Icons.settings_backup_restore),
                title: Text(l10n.webdavLocalRecovery),
                subtitle: Text(l10n.webdavLocalRecoveryDescription),
                onTap: busy.value
                    ? null
                    : () => perform((_, isCurrent) async {
                        final local = await api.exportSnapshot();
                        final recovery = await api.loadLocalRecovery();
                        if (recovery == null) {
                          return l10n.webdavHistoryEmpty;
                        }
                        return restorePreview(recovery, local, isCurrent);
                      }, saveConfiguration: false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
