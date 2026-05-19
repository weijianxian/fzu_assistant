import 'package:flutter_hooks/flutter_hooks.dart';

/// widget dispose 后自动变为 false 的 mounted 标记。
///
/// 用法：
/// ```dart
/// final mounted = useMounted();
/// // ... async 回调中：
/// if (!mounted.value) return;
/// ```
// ignore: strict_top_level_inference
useMounted() {
  final mounted = useRef(true);
  useEffect(
    () => () {
      mounted.value = false;
    },
    [],
  );
  return mounted;
}
