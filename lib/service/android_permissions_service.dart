import 'package:flutter/services.dart';
import 'package:fzu_assistant/service/course_reminder_service.dart';

class AndroidAppPermission {
  const AndroidAppPermission({required this.name, required this.granted});
  final String name;
  final bool granted;
}

abstract final class AndroidPermissionsService {
  static const channel = MethodChannel('com.weijx.fzu_assistant/permissions');

  static Future<List<AndroidAppPermission>> load() async {
    if (!CourseReminderService.androidSupported) return [];
    final result = await channel.invokeListMethod<dynamic>('list') ?? [];
    return result.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return AndroidAppPermission(
        name: map['name'] as String,
        granted: map['granted'] as bool,
      );
    }).toList();
  }

  static Future<void> openSettings([String? name]) async {
    if (CourseReminderService.androidSupported) {
      await channel.invokeMethod<void>('open', {'name': name});
    }
  }
}
