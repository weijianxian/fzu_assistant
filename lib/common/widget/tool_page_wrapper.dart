import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';

class ToolPageWrapper extends HookWidget {
  final Future<void> Function() onRefresh;
  final DateTime? refreshTime;
  final bool loading;
  final String? error;
  final bool hasData;
  final Widget? child;
  final List<Widget>? slivers;
  final String emptyText;

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
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ...slivers!,
          SliverToBoxAdapter(child: _footer(context)),
        ],
      );
    }

    final content = child!;

    // ListView：把 footer 插到末尾
    if (content is ListView) {
      final delegate = content.childrenDelegate;
      if (delegate is SliverChildListDelegate) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: content.padding,
          children: [...delegate.children, _footer(context)],
        );
      }
      if (delegate is SliverChildBuilderDelegate) {
        final originalCount = delegate.childCount ?? 0;
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: content.padding,
          itemCount: originalCount + 1,
          itemBuilder: (ctx, i) {
            if (i == originalCount) return _footer(context);
            return delegate.builder(ctx, i);
          },
        );
      }
    }

    // 通用情况：用 ListView 包一层
    return ListView(
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
              ? AppLocalizations.of(
                  context,
                )!.dataUpdatedAt(_formatTime(refreshTime!))
              : '',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _emptyView(BuildContext context) {
    return ListView(
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
