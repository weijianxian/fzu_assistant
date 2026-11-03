import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';
import 'package:fzu_assistant/service/webdav_sync_service.dart';

/// Sync after opening the app without delaying login or route construction.
class WebDavAutoSync extends HookWidget {
  const WebDavAutoSync({
    super.key,
    required this.settings,
    required this.ready,
    required this.navigatorKey,
    required this.messengerKey,
    required this.child,
    this.service,
  });

  final AppSettings settings;
  final Future<void> ready;
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final Widget child;
  final WebDavSyncService? service;

  @override
  Widget build(BuildContext context) {
    final api = service ?? WebDavSyncService.instance;
    final busy = useRef(false);
    final wasBackground = useRef(false);

    Future<void> sync() async {
      if (busy.value) return;
      busy.value = true;
      String? message;
      try {
        await ready;
        if (!context.mounted) return;
        final state = WidgetsBinding.instance.lifecycleState;
        if (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached) {
          return;
        }
        final result = await api.autoSync(
          apply: (snapshot) {
            if (context.mounted) applyWebDavSettings(settings, snapshot);
          },
        );
        if (!context.mounted) return;
        final l10n = AppLocalizations.of(context)!;
        message = switch (result) {
          WebDavAutoSyncResult.conflict => l10n.webdavAutoSyncConflict,
          WebDavAutoSyncResult.manualUploadRequired =>
            l10n.webdavAutoSyncManualUpload,
          _ => null,
        };
      } catch (_) {
        if (!context.mounted) return;
        message = AppLocalizations.of(context)!.webdavAutoSyncFailed;
      } finally {
        busy.value = false;
      }
      if (!context.mounted || message == null) return;
      final l10n = AppLocalizations.of(context)!;
      messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            actionOverflowThreshold: 1,
            action: SnackBarAction(
              label: l10n.settings,
              onPressed: () {
                final routeContext =
                    navigatorKey.currentState?.overlay?.context;
                if (routeContext != null) {
                  unawaited(routeContext.pushNamed(AppRoutes.webDavSettings));
                }
              },
            ),
          ),
        );
    }

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) unawaited(sync());
      });
      return null;
    }, [api, ready, settings]);
    useOnAppLifecycleStateChange((_, state) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden) {
        wasBackground.value = true;
      } else if (state == AppLifecycleState.resumed && wasBackground.value) {
        wasBackground.value = false;
        unawaited(sync());
      }
    });
    return child;
  }
}
