import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class ToolPageWrapper extends HookWidget {
  final Future<void> Function() onRefresh;
  final DateTime? refreshTime;
  final bool loading;
  final String? error;
  final bool hasData;
  final Widget child;
  final String emptyText;

  const ToolPageWrapper({
    super.key,
    required this.onRefresh,
    required this.loading,
    required this.child,
    this.refreshTime,
    this.error,
    this.hasData = true,
    this.emptyText = '暂无数据',
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator.adaptive());
    }

    if (error != null && !hasData) {
      return Center(child: Text('加载失败: $error'));
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: hasData ? _withFooter(child) : _emptyView(),
    );
  }

  Widget _withFooter(Widget content) {
    // 如果 child 本身是 ListView，把 footer 插到末尾
    if (content is ListView) {
      final delegate = content.childrenDelegate;
      if (delegate is SliverChildListDelegate) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: content.padding,
          children: [...delegate.children, _footer()],
        );
      }
      if (delegate is SliverChildBuilderDelegate) {
        final originalCount = delegate.childCount ?? 0;
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: content.padding,
          itemCount: originalCount + 1,
          itemBuilder: (context, i) {
            if (i == originalCount) return _footer();
            return delegate.builder(context, i);
          },
        );
      }
    }

    // 通用情况：用 ListView 包一层
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [content, _footer()],
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          refreshTime != null
              ? '数据更新于 ${_formatTime(refreshTime!)}'
              : '',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _emptyView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 200),
        Center(child: Text(emptyText)),
        _footer(),
      ],
    );
  }

  static String _formatTime(DateTime t) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${pad(t.month)}-${pad(t.day)} ${pad(t.hour)}:${pad(t.minute)}';
  }
}
