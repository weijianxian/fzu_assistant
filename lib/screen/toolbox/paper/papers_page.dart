import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_async_data.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/toolbox/paper/paper_download_sheet.dart';
import 'package:fzu_assistant/service/api/paper_service.dart';
import 'package:fzu_assistant/service/paper_download_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

class PapersPage extends HookWidget {
  const PapersPage({super.key, this.path = '/', this.service});
  final String path;
  final PaperService? service;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final access = useValueListenable(settings.papersAccess);
    final l10n = AppLocalizations.of(context)!;
    if (access == FeatureAccess.allow) {
      return _AllowedPapersPage(path: path, service: service);
    }
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.pastPapers)),
      body: ToolPageWrapper(
        loading: false,
        emptyText: l10n.noData,
        onRefresh: () async {},
        child: AppSection(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  access == FeatureAccess.hide
                      ? Icons.visibility_off_outlined
                      : Icons.info_outline,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  access == FeatureAccess.hide
                      ? l10n.papersHidden
                      : l10n.pastPapersDescription,
                ),
                const SizedBox(height: 12),
                Text(l10n.thirdPartyDisabled),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      context.pushNamed(AppRoutes.thirdPartySettings),
                  child: Text(l10n.thirdPartyServices),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AllowedPapersPage extends HookWidget {
  const _AllowedPapersPage({required this.path, this.service});
  final String path;
  final PaperService? service;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final l10n = AppLocalizations.of(context)!;
    final api = useMemoized(
      () => service ?? PaperService(access: () => settings.papersAccess.value),
      [service, settings],
    );
    useEffect(() => service == null ? api.close : null, [api]);
    final downloads = useMemoized(
      () => PaperDownloadService(access: settings.papersAccess, api: api),
      [api, settings],
    );
    useEffect(() => downloads.close, [downloads]);
    final state = useAsyncData(() => api.list(path));
    final search = useTextEditingController();
    useListenable(search);
    final busy = useState(false);
    final keyword = search.text.trim().toLowerCase();
    final entries =
        state.data?.entries
            .where((entry) => entry.name.toLowerCase().contains(keyword))
            .toList() ??
        [];

    Future<void> file(PaperEntry entry) async {
      if (busy.value) return;
      busy.value = true;
      try {
        await showAppBottomSheet<void>(
          context: context,
          builder: (_) => PaperDownloadSheet(
            path: PaperService.childPath(path, entry.name),
            name: entry.name,
            service: downloads,
            access: settings.papersAccess,
          ),
        );
      } catch (error) {
        if (context.mounted &&
            settings.papersAccess.value == FeatureAccess.allow) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.toString())));
        }
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.pastPapers),
        actions: [
          IconButton(
            tooltip: l10n.thirdPartyServices,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.pushNamed(AppRoutes.thirdPartySettings),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: search,
              decoration: InputDecoration(
                labelText: l10n.papersSearch,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: search.clear,
                      ),
              ),
            ),
          ),
          AppSection.list(
            children: [
              ListTile(
                leading: Icon(
                  path == '/' ? Icons.folder_open : Icons.arrow_upward,
                ),
                title: Text(path == '/' ? l10n.papersRoot : path),
                subtitle: path == '/' ? null : Text(l10n.papersParent),
                onTap: path == '/' || state.data == null
                    ? null
                    : () => context.pushReplacementNamed(
                        AppRoutes.papers,
                        arguments: PapersArgs(
                          path: PaperService.parentPath(path),
                        ),
                      ),
              ),
            ],
          ),
          if (state.error != null)
            ListTile(
              title: Text(state.error!),
              trailing: TextButton(
                onPressed: state.refresh,
                child: Text(l10n.retry),
              ),
            ),
          Expanded(
            child: ToolPageWrapper(
              loading: state.loading,
              error: state.error,
              hasData: state.data != null,
              refreshTime: state.updatedAt,
              emptyText: l10n.papersEmpty,
              onRefresh: state.refresh,
              child: AppListView.grouped(
                itemCount: entries.isEmpty ? 1 : entries.length,
                itemBuilder: (context, index) {
                  if (entries.isEmpty) {
                    return ListTile(title: Text(l10n.papersEmpty));
                  }
                  final entry = entries[index];
                  return ListTile(
                    leading: Icon(
                      entry.isFolder
                          ? Icons.folder_outlined
                          : Icons.description_outlined,
                    ),
                    title: Text(entry.name),
                    trailing: Icon(
                      entry.isFolder
                          ? Icons.chevron_right
                          : Icons.download_outlined,
                    ),
                    onTap: busy.value
                        ? null
                        : () {
                            if (entry.isFolder) {
                              context.pushNamed(
                                AppRoutes.papers,
                                arguments: PapersArgs(
                                  path: PaperService.childPath(
                                    path,
                                    entry.name,
                                  ),
                                ),
                              );
                            } else {
                              file(entry);
                            }
                          },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
