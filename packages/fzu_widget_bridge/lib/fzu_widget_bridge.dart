import 'package:flutter/services.dart';

/// Storage and rendering channel registered on every Android Flutter engine.
///
/// This plugin requires no Activity and does not schedule background work.
/// See the package README for the baseline and commit wire contracts.
abstract final class FzuWidgetBridge {
  static const channel = MethodChannel(
    'com.weijx.fzu_assistant/widget_background',
  );
}
