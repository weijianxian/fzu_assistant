import 'package:flutter_hooks/flutter_hooks.dart';

/// 查询结果与刷新入口；刷新期间保留旧数据，失败时保留上次更新时间。
class AsyncData<T> {
  final T? data;
  final bool loading;
  final String? error;
  final DateTime? updatedAt;
  final Future<void> Function() refresh;

  const AsyncData({
    required this.data,
    required this.loading,
    required this.error,
    required this.updatedAt,
    required this.refresh,
  });
}

/// 自动执行一次查询，统一处理错误、卸载和并发刷新，只有最新请求能更新页面。
AsyncData<T> useAsyncData<T>(
  Future<T> Function() fetch, {
  T? initialData,
  void Function(T data)? onLoaded,
}) {
  final context = useContext();
  final data = useState<T?>(initialData);
  final loading = useState(true);
  final error = useState<String?>(null);
  final updatedAt = useState<DateTime?>(null);
  final fetchRef = useRef(fetch)..value = fetch;
  final onLoadedRef = useRef(onLoaded)..value = onLoaded;
  final serial = useRef(0);

  Future<void> refresh() async {
    final request = ++serial.value;
    bool isLatest() => context.mounted && request == serial.value;
    try {
      final result = await fetchRef.value();
      if (!isLatest()) return;
      data.value = result;
      updatedAt.value = DateTime.now();
      error.value = null;
      onLoadedRef.value?.call(result);
    } catch (e) {
      if (isLatest()) error.value = e.toString();
    } finally {
      if (isLatest()) loading.value = false;
    }
  }

  useEffect(() {
    refresh();
    return null;
  }, const []);

  return AsyncData(
    data: data.value,
    loading: loading.value,
    error: error.value,
    updatedAt: updatedAt.value,
    refresh: refresh,
  );
}
