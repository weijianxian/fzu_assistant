import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/screen/toolbox/paper/paper_file_actions.dart';
import 'package:fzu_assistant/service/paper_library_service.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class PaperLibraryPage extends HookWidget {
  const PaperLibraryPage({super.key, this.service});
  final PaperLibraryService? service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final library = useMemoized(() => service ?? PaperLibraryService(), [
      service,
    ]);
    final files = useState<List<LocalPaper>>([]);
    final loading = useState(true);
    final busy = useState(false);
    final error = useState<Object?>(null);
    final search = useTextEditingController();
    useListenable(search);
    Future<void> refresh() async {
      loading.value = true;
      try {
        final values = await library.list();
        if (!context.mounted) return;
        files.value = values;
        error.value = null;
      } catch (e) {
        if (context.mounted) error.value = e;
      } finally {
        if (context.mounted) loading.value = false;
      }
    }

    useEffect(() {
      refresh();
      return null;
    }, [library]);
    final filtered = files.value
        .where(
          (file) => file.name.toLowerCase().contains(
            search.text.trim().toLowerCase(),
          ),
        )
        .toList();

    Future<void> action(
      LocalPaper paper,
      String action,
      BuildContext anchor,
    ) async {
      if (busy.value) return;
      busy.value = true;
      try {
        if (action == 'delete') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.downloadDelete),
              content: Text('${paper.name}\n${l10n.downloadDeletePrompt}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.learningCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.downloadDelete),
                ),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
          await library.delete(paper);
          if (context.mounted) await refresh();
          return;
        }
        final file = await library.validate(paper);
        if (!context.mounted) return;
        if (action == 'open') {
          if (!await openPaperFile(file.path)) {
            throw StateError(l10n.papersLocalOpenFailed);
          }
        } else if (action == 'copy') {
          await Clipboard.setData(ClipboardData(text: file.path));
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l10n.downloadPathCopied)));
          }
        } else if (action == 'share' && !Platform.isLinux) {
          final box = anchor.mounted
              ? anchor.findRenderObject() as RenderBox?
              : null;
          final origin = box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size;
          await SharePlus.instance.share(
            ShareParams(files: [XFile(file.path)], sharePositionOrigin: origin),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.downloadActionFailed}: $e')),
          );
        }
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.downloadLibrary),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: loading.value || busy.value ? null : refresh,
            icon: const Icon(Icons.refresh),
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
                labelText: l10n.downloadSearch,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${files.value.length} · ${_size(files.value.fold<int>(0, (sum, file) => sum + file.bytes))}',
            ),
          ),
          if (loading.value) const LinearProgressIndicator(),
          if (error.value != null)
            ListTile(
              title: Text(l10n.loadingFailed('${error.value}')),
              subtitle: Text('${error.value}'),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: filtered.isEmpty
                  ? AppListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        ListTile(
                          title: Text(
                            loading.value
                                ? l10n.downloadLibrary
                                : l10n.downloadEmpty,
                          ),
                        ),
                      ],
                    )
                  : AppListView.grouped(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final paper = filtered[index];
                        return ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: Text(paper.name),
                          subtitle: Text(
                            '${_size(paper.bytes)} · ${DateFormat.yMd().add_Hm().format(paper.modified)}',
                          ),
                          onTap: busy.value
                              ? null
                              : () => action(paper, 'open', context),
                          trailing: Builder(
                            builder: (anchor) => PopupMenuButton<String>(
                              enabled: !busy.value,
                              onSelected: (value) =>
                                  action(paper, value, anchor),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'open',
                                  child: Text(l10n.papersOpenFile),
                                ),
                                if (!Platform.isLinux)
                                  PopupMenuItem(
                                    value: 'share',
                                    child: Text(l10n.papersShareFile),
                                  ),
                                PopupMenuItem(
                                  value: 'copy',
                                  child: Text(l10n.downloadCopyPath),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(l10n.downloadDelete),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
