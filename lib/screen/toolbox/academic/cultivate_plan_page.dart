import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_async_data.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';

class CultivatePlanPage extends HookWidget {
  const CultivatePlanPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final data = useAsyncData<String>(
      () => AcademicService().getCultivatePlan(),
    );
    void open(String url) => context.pushNamed(
      AppRoutes.webview,
      arguments: WebViewArgs(url: url, title: l10n.cultivatePlan),
    );
    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.cultivatePlan),
        actions: [
          IconButton(
            onPressed: data.loading ? null : data.refresh,
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ToolPageWrapper(
        loading: data.loading,
        error: data.error,
        hasData: data.data != null,
        refreshTime: data.updatedAt,
        emptyText: l10n.noData,
        onRefresh: data.refresh,
        child: data.data == null
            ? const SizedBox.shrink()
            : AppListView(
                children: [
                  AppSection.list(
                    children: [
                      ListTile(
                        title: Text(l10n.cultivatePlan),
                        subtitle: Text(l10n.cultivatePlanDescription),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => open(data.data!),
                      ),
                    ],
                  ),
                ],
              ),
      ),
      bottomNavigationBar: AppBottomBar(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextButton(
            onPressed: () => open(AcademicService.cultivatePlanListUrl),
            child: Text(l10n.selectPlanManually),
          ),
        ),
      ),
    );
  }
}
