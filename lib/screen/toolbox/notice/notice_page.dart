import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/masonry_sliver_grid.dart';
import 'package:fzu_assistant/common/tool_page_wrapper.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/notice.dart';
import 'package:fzu_assistant/screen/guest/webview_page.dart';
import 'package:fzu_assistant/service/academic_service.dart';

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
    final mounted = useRef(true);
    useEffect(
      () => () {
        mounted.value = false;
      },
      [],
    );

    Future<void> load([int? page]) async {
      final p = page ?? currentPage.value;
      loading.value = true;
      error.value = null;
      try {
        final (list, total) = await service.getNotices(p);
        if (!mounted.value) return;
        notices.value = list;
        totalPages.value = total;
        currentPage.value = p;
        refreshTime.value = DateTime.now();
        error.value = null;
      } catch (e) {
        if (!mounted.value) return;
        error.value = e.toString();
      }
      if (mounted.value) loading.value = false;
    }

    useEffect(() {
      load(1);
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.officeNotice)),
      body: Column(
        children: [
          Expanded(
            child: ToolPageWrapper(
              onRefresh: load,
              loading: loading.value,
              error: error.value,
              refreshTime: refreshTime.value,
              hasData: notices.value.isNotEmpty || loading.value,
              emptyText: l10n.noNoticeData,
              slivers: [
                if (notices.value.isEmpty && !loading.value)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: Center(
                        child: Text(
                          l10n.noNoticeData,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    ),
                  )
                else
                  MasonrySliverGrid(
                    childCount: notices.value.length,
                    itemBuilder: (context, i) {
                      final notice = notices.value[i];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
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
                              color: Colors.grey[500],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WebViewPage(
                                  url: notice.url,
                                  title: notice.title,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          // 分页控件
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
            ),
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
                      currentPage.value < totalPages.value && !loading.value
                      ? () => load(currentPage.value + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
