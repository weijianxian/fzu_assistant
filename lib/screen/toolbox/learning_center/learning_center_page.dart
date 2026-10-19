import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_async_data.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/toolbox/learning_center/learning_center_widgets.dart';
import 'package:fzu_assistant/service/api/sso_service.dart';

class LearningCenterPage extends HookWidget {
  const LearningCenterPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = useAsyncData<String?>(() async {
      final cached = await SsoService.instance.loadStudyToken();
      if (cached != null && cached.isNotEmpty) return cached;
      try {
        return await SsoService.instance.getStudyToken();
      } on SsoLoginRequired {
        return null;
      }
    });
    Future<void> login() async {
      await context.pushNamed(AppRoutes.ssoLogin);
      if (context.mounted) await session.refresh();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.learningCenter),
        actions: [
          if (session.data != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: l10n.ssoLogout,
              onPressed: () async {
                if (!await confirmLearningAction(
                  context,
                  l10n.ssoLogout,
                  l10n.ssoLogoutDescription,
                )) {
                  return;
                }
                try {
                  await SsoService.instance.logout();
                  if (context.mounted) await session.refresh();
                } catch (e) {
                  if (context.mounted) await showLearningError(context, e);
                }
              },
            ),
        ],
      ),
      body: ToolPageWrapper(
        loading: session.loading,
        error: session.error,
        emptyText: l10n.noData,
        onRefresh: session.refresh,
        refreshTime: session.updatedAt,
        child: ListView(
          children: [
            if (session.error != null)
              ListTile(
                title: Text(session.error!),
                trailing: TextButton(
                  onPressed: session.refresh,
                  child: Text(l10n.retry),
                ),
              ),
            if (session.data == null)
              LearningLoginPrompt(onLogin: login)
            else ...[
              ChevronListTile(
                leading: const Icon(Icons.event_seat_outlined),
                title: Text(l10n.learningReserve),
                subtitle: Text(l10n.learningReserveSubtitle),
                onTap: () async {
                  await context.pushNamed(AppRoutes.learningSeats);
                  if (context.mounted) await session.refresh();
                },
              ),
              ChevronListTile(
                leading: const Icon(Icons.history),
                title: Text(l10n.learningAppointments),
                onTap: () async {
                  await context.pushNamed(AppRoutes.learningAppointments);
                  if (context.mounted) await session.refresh();
                },
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.learningInstructions),
            ),
          ],
        ),
      ),
    );
  }
}
