import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/next_course_widget_service.dart';

/// Widget tests have no native widget host. Keep responses inside the test's
/// microtask queue instead of waiting for an unhandled platform message.
List<MethodCall> mockNextCourseWidgetChannel({bool supportsPin = false}) {
  final calls = <MethodCall>[];
  // Logout now also invalidates the background sync generation. Respond inside
  // this test's microtask queue, just like the widget snapshot channel below.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(NextCourseWidgetService.backgroundChannel, (
        call,
      ) async {
        return switch (call.method) {
          'getState' || 'configure' || 'cancel' || 'markFailed' => null,
          'prepare' || 'readInputs' => null,
          'commit' => false,
          _ => throw MissingPluginException(
            'Unexpected widget sync method: ${call.method}',
          ),
        };
      });
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(NextCourseWidgetService.channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'clear' || 'invalidate' || 'setSnapshot' => null,
          'requestPin' => supportsPin,
          _ => throw MissingPluginException(
            'Unexpected widget method: ${call.method}',
          ),
        };
      });
  return calls;
}
