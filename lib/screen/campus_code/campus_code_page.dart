import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/campus_code.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/api/campus_code_service.dart';
import 'package:fzu_assistant/service/api/sso_service.dart';
import 'package:intl/intl.dart';
import 'package:screen_brightness/screen_brightness.dart';

class CampusCodePage extends HookWidget {
  const CampusCodePage({super.key, this.service, this.isActive = true});
  final CampusCodeService? service;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final api = service ?? CampusCodeService.instance;
    final l10n = AppLocalizations.of(context)!;
    final selected = useState(0);
    final pages = usePageController();
    final user = useState<CampusUser?>(null);
    final payCode = useState<CampusPayCode?>(null);
    final error = useState<String?>(null);
    final needsLogin = useState(false);
    final loading = useState(true);
    final refreshing = useState(false);
    final busy = useRef(false);
    final generation = useRef(0);
    final clock = useState(DateTime.now());
    final lifecycle = useAppLifecycleState();
    final active =
        isActive &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    final activeRef = useRef(active)..value = active;

    Future<void> refresh() async {
      if (busy.value || !activeRef.value) return;
      busy.value = true;
      refreshing.value = true;
      final request = ++generation.value;
      bool current() =>
          context.mounted && activeRef.value && generation.value == request;
      error.value = null;
      try {
        final session = await api.loadSession();
        if (!current()) return;
        needsLogin.value = false;
        user.value = session.user;
        if (selected.value == 0) {
          final result = await api.getPayCode(session.token);
          if (current()) payCode.value = result;
        }
      } on SsoLoginRequired {
        if (current()) {
          needsLogin.value = true;
          user.value = null;
          payCode.value = null;
        }
      } catch (e) {
        if (current()) error.value = e.toString();
      } finally {
        if (generation.value == request) busy.value = false;
        if (current()) {
          loading.value = false;
          refreshing.value = false;
        }
      }
    }

    final refreshRef = useRef(refresh)..value = refresh;
    useEffect(() {
      if (!active) return null;
      scheduleMicrotask(() {
        if (context.mounted && activeRef.value) refreshRef.value();
      });
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        clock.value = DateTime.now();
      });
      final refreshTimer = Timer.periodic(const Duration(seconds: 50), (_) {
        if (selected.value == 0 && !needsLogin.value) {
          refreshRef.value();
        }
      });
      return () {
        timer.cancel();
        refreshTimer.cancel();
        generation.value++;
        busy.value = false;
      };
    }, [active, selected.value]);

    final hasCode =
        active &&
        (selected.value == 0 ? payCode.value != null : user.value != null);
    final brightnessQueue = useRef(Future<void>.value());
    useEffect(() {
      if (!hasCode ||
          kIsWeb ||
          !{
            TargetPlatform.android,
            TargetPlatform.iOS,
          }.contains(defaultTargetPlatform)) {
        return null;
      }
      void enqueue(Future<void> Function() action) {
        brightnessQueue.value = brightnessQueue.value
            .then((_) => action())
            .catchError((Object _) {});
      }

      enqueue(
        () => ScreenBrightness.instance.setApplicationScreenBrightness(1),
      );
      return () => enqueue(
        () => ScreenBrightness.instance.resetApplicationScreenBrightness(),
      );
    }, [hasCode]);

    Future<void> login() async {
      await context.pushNamed(AppRoutes.campusCodeLogin);
      // Route activation triggers refresh, including cancellation of login.
    }

    final beijing = clock.value.toUtc().add(const Duration(hours: 8));
    return TickerMode(
      enabled: active,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.campusCode),
          actions: [
            if (user.value != null)
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: l10n.ssoLogout,
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(l10n.ssoLogout),
                      content: Text(l10n.ssoLogoutDescription),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: Text(l10n.learningCancel),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: Text(l10n.learningConfirm),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !context.mounted) return;
                  try {
                    await api.sso.logout();
                    if (!context.mounted) return;
                    generation.value++;
                    busy.value = false;
                    user.value = null;
                    payCode.value = null;
                    await refresh();
                  } catch (e) {
                    if (context.mounted) error.value = e.toString();
                  }
                },
              ),
          ],
        ),
        floatingActionButton:
            needsLogin.value || (loading.value && user.value == null)
            ? null
            : FloatingActionButton(
                tooltip: l10n.refresh,
                onPressed: refreshing.value ? null : refresh,
                child: refreshing.value
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
        body: SafeArea(
          top: false,
          child: PageView(
            controller: pages,
            scrollDirection: Axis.vertical,
            onPageChanged: (page) => selected.value = page,
            children: [
              for (final library in [false, true])
                _CodePanel(
                  library: library,
                  user: user.value,
                  payCode: payCode.value,
                  time: DateFormat('yyyy-MM-dd HH:mm:ss').format(beijing),
                  loading: loading.value,
                  error: library && user.value != null ? null : error.value,
                  needsLogin: needsLogin.value,
                  onLogin: login,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodePanel extends StatelessWidget {
  const _CodePanel({
    required this.library,
    required this.user,
    required this.payCode,
    required this.time,
    required this.loading,
    required this.error,
    required this.needsLogin,
    required this.onLogin,
  });
  final bool library;
  final CampusUser? user;
  final CampusPayCode? payCode;
  final String time;
  final bool loading;
  final String? error;
  final bool needsLogin;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bytes = library
        ? (user == null ? null : ascii.encode(user!.account))
        : payCode?.bytes;
    if (bytes == null && !needsLogin) {
      return Center(
        child: error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(error!, textAlign: TextAlign.center),
              )
            : user == null
            ? const SizedBox.expand()
            : const CircularProgressIndicator(),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: math.min(448, math.max(1, constraints.maxWidth - 32)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    library ? l10n.campusLibraryCode : l10n.campusPayCode,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (needsLogin) ...[
                    Text(l10n.ssoLoginDescription),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onLogin,
                      icon: const Icon(Icons.login),
                      label: Text(l10n.ssoLogin),
                    ),
                  ] else ...[
                    Text(
                      user == null ? '' : '${user!.name}  ${user!.account}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: bytes != null
                                  ? BarcodeWidget.fromBytes(
                                      barcode: Barcode.qrCode(
                                        errorCorrectLevel:
                                            BarcodeQRCorrectionLevel.medium,
                                      ),
                                      data: bytes,
                                      padding: const EdgeInsets.all(16),
                                      backgroundColor: Colors.white,
                                      drawText: false,
                                    )
                                  : Center(
                                      child: loading || error == null
                                          ? const CircularProgressIndicator()
                                          : Text(
                                              error!,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.black87,
                                              ),
                                            ),
                                    ),
                            ),
                            if (library && user != null) ...[
                              const SizedBox(height: 16),
                              BarcodeWidget(
                                data: user!.account,
                                barcode: Barcode.code128(),
                                height: 72,
                                drawText: false,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                backgroundColor: Colors.white,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(time),
                    if (library) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.campusLibraryCodeHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (!library) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.campusSwipeHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    SizedBox(
                      height: 44,
                      child: error != null && bytes != null
                          ? Center(
                              child: Text(
                                error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
