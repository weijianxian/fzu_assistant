import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/notice.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';

class NoticePage extends HookWidget {
  const NoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notices = useState<List<NoticeInfo>>([]);
    final loading = useState(true);
    final error = useState<String?>(null);
    final refreshTime = useState<DateTime?>(null);
    final currentPage = useState(1);
    final totalPages = useState(1);
    final service = useMemoized(() => AcademicService());

    Future<void> load([int? page]) async {
      final p = page ?? currentPage.value;
      loading.value = true;
      error.value = null;
      try {
        final (list, total) = await service.getNotices(p);
        if (!context.mounted) return;
        notices.value = list;
        totalPages.value = total;
        currentPage.value = p;
        refreshTime.value = DateTime.now();
        error.value = null;
      } catch (e) {
        if (!context.mounted) return;
        error.value = e.toString();
      }
      if (context.mounted) loading.value = false;
    }

    useEffect(() {
      load(1);
      return null;
    }, []);

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.officeNotice)),
      body: Column(
        children: [
          Expanded(
            child: ToolPageWrapper(
              onRefresh: load,
              loading: loading.value,
              error: error.value,
              refreshTime: refreshTime.value,
              hasData: notices.value.isNotEmpty,
              emptyText: l10n.noNoticeData,
              slivers: [
                MasonrySliverGrid.grouped(
                  childCount: notices.value.length,
                  itemBuilder: (context, i) {
                    final notice = notices.value[i];
                    return ListTile(
                      title: Text(
                        notice.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        notice.department.isNotEmpty
                            ? '${notice.department} · ${notice.date}'
                            : notice.date,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        context.pushNamed(
                          AppRoutes.webview,
                          arguments: WebViewArgs(
                            url: notice.url,
                            title: notice.title,
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          // 分页控件
          AppBottomBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppDivider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: currentPage.value > 1 && !loading.value
                            ? () => load(currentPage.value - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        '${currentPage.value} / ${totalPages.value}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      IconButton(
                        onPressed:
                            currentPage.value < totalPages.value &&
                                !loading.value
                            ? () => load(currentPage.value + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
