import 'dart:io';

import 'package:flutter/services.dart';

/// Real text for optional headless captures; ordinary tests do no font I/O.
Future<void> loadWindowsSettingsCaptureFonts({required bool capture}) async {
  const path = String.fromEnvironment('WINDOWS_SETTINGS_CAPTURE_FONT');
  if (!capture || path.isEmpty) return;

  final bytes = await File(path).readAsBytes();
  for (final family in [
    'Roboto',
    'Segoe UI',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
  ]) {
    await (FontLoader(family)..addFont(
          Future.value(
            bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes),
          ),
        ))
        .load();
  }
  // Text aliases must not replace the independent icon font.
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}
