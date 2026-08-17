import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

WebViewEnvironment? webViewEnvironment;

Future<void> initWebViewEnvironment() async {
  if (!Platform.isWindows) return;

  try {
    if (await WebViewEnvironment.getAvailableVersion() == null) return;
    final directory = await getApplicationSupportDirectory();
    webViewEnvironment = await WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(
        userDataFolder: '${directory.path}/flutter_inappwebview',
      ),
    );
  } catch (_) {}
}
