import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:permission_handler/permission_handler.dart';

/// 通用权限 Hook —— 进入页面自动检查一次，返回可观察的状态。
///
/// 用法：
/// ```dart
/// final notif = usePermission(Permission.notification);
/// if (!notif.value.granted) {
///   await requestPermission(notif); // 申请并刷新
/// }
/// ```
ValueNotifier<PermissionStatus?> usePermission(Permission permission) {
  final status = useState<PermissionStatus?>(null);

  useEffect(() {
    permission.status.then((s) => status.value = s);
    return null;
  }, []);

  return status;
}

/// 申请权限并刷新状态
Future<PermissionStatus> requestPermission(
  ValueNotifier<PermissionStatus?> state,
  Permission permission,
) async {
  final s = await permission.request();
  state.value = s;
  return s;
}
