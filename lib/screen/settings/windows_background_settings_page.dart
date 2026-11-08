import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/service/windows_background_service.dart';

class WindowsBackgroundSettingsPage extends StatefulWidget {
  const WindowsBackgroundSettingsPage({super.key, this.service});

  final WindowsBackgroundService? service;

  @override
  State<WindowsBackgroundSettingsPage> createState() =>
      _WindowsBackgroundSettingsPageState();
}

class _WindowsBackgroundSettingsPageState
    extends State<WindowsBackgroundSettingsPage> {
  late final _service = widget.service ?? WindowsBackgroundService.instance;
  bool? _lastRequestedValue;

  @override
  void initState() {
    super.initState();
    unawaited(_service.initialize());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    _service.updateLabels(
      WindowsBackgroundLabels(
        appName: l10n.appName,
        showWindow: l10n.windowsBackgroundRestore,
        exit: l10n.windowsBackgroundExit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.windowsBackground)),
      body: ListenableBuilder(
        listenable: _service,
        builder: (context, _) => AppListView(
          children: [
            if (!_service.isSupported)
              AppInfoCard(title: Text(l10n.windowsBackgroundUnsupported))
            else ...[
              AppInfoCard(title: Text(l10n.windowsBackgroundHelp)),
              SettingsSection.list(
                children: [
                  SettingSwitchTile.controlled(
                    title: Text(l10n.windowsBackgroundCloseToTray),
                    subtitle: Text(
                      l10n.windowsBackgroundCloseToTrayDescription,
                    ),
                    secondary: const Icon(Icons.desktop_windows_outlined),
                    value: _service.enabled,
                    onChanged: !_service.initialized || _service.busy
                        ? null
                        : (value) async {
                            _lastRequestedValue = value;
                            await _service.setEnabled(value);
                          },
                  ),
                ],
              ),
              SettingsStatus(
                title: _service.failed
                    ? l10n.windowsBackgroundFailed
                    : _service.enabled && _service.trayReady
                    ? l10n.windowsBackgroundReady
                    : l10n.windowsBackgroundDisabled,
                isError: _service.failed,
                action: _service.failed
                    ? TextButton(
                        onPressed: _service.busy
                            ? null
                            : () async {
                                await _service.setEnabled(
                                  _lastRequestedValue ?? _service.enabled,
                                );
                              },
                        child: Text(l10n.retry),
                      )
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
