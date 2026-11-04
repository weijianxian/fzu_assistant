import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

/// A missing iOS preview/open-menu callback must not lock every file action.
Future<bool> openPaperFile(
  String path, {
  Duration timeout = const Duration(seconds: 20),
  Future<bool> Function(String path)? open,
}) async {
  try {
    // Normalize narrower futures (such as Future<Never>) before the fallback.
    final pending = (open ?? _openNative)(path).then<bool>((opened) => opened);
    return await pending.timeout(timeout, onTimeout: () => false);
  } catch (_) {
    return false;
  }
}

Future<bool> _openNative(String path) async {
  if (Platform.isAndroid || Platform.isIOS) {
    return (await OpenFilex.open(path)).type == ResultType.done;
  }
  return launchUrl(Uri.file(path), mode: LaunchMode.externalApplication);
}
