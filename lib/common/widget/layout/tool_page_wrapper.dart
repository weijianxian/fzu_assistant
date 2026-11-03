import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widget/layout/app_scroll_view.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';

class ToolPageWrapper extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final DateTime? refreshTime;
  final bool loading;
  final String? error;
  final bool hasData;
  final Widget? child;
  final List<Widget>? slivers;
  final String emptyText;
  final ScrollController? scrollController;

  const ToolPageWrapper({
    super.key,
    required this.onRefresh,
    required this.loading,
    this.child,
    this.slivers,
    this.refreshTime,
    this.error,
    required this.emptyText,
    this.hasData = true,
    this.scrollController,
  }) : assert(child != null || slivers != null, 'Provide child or slivers');

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator.adaptive());
    }

    if (error != null && !hasData) {
      return Center(
        child: Text(AppLocalizations.of(context)!.loadingFailed(error!)),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: hasData ? _withFooter(context) : _emptyView(context),
    );
  }

  Widget _withFooter(BuildContext context) {
    // slivers 模式：直接构建 CustomScrollView
    if (slivers != null) {
      return AppCustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ...slivers!,
          SliverToBoxAdapter(child: _footer(context)),
        ],
      );
    }

    final content = child!;

    // Preserve native delegates, list options and controllers when adding a footer.
    final list = content is AppListView
        ? content.nativeListView
        : content is ListView
        ? content
        : null;
    if (list != null) {
      return AppListView.fromListView(
        list,
        footer: _footer(context),
        controller: scrollController ?? list.controller,
        physics: const AlwaysScrollableScrollPhysics(),
      );
    }

    // 通用情况：用 ListView 包一层
    return AppListView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [content, _footer(context)],
    );
  }

  Widget _footer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          refreshTime != null
              ? AppLocalizations.of(context)!
                    .dataUpdatedAt(_formatTime(refreshTime!))
              : '',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _emptyView(BuildContext context) {
    return AppListView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 200),
        Center(child: Text(emptyText)),
        _footer(context),
      ],
    );
  }

  static String _formatTime(DateTime t) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${pad(t.month)}-${pad(t.day)} ${pad(t.hour)}:${pad(t.minute)}';
  }
}
