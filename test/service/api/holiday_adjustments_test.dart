import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/utils/cache_helper.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fzu_assistant/common/utils/course_sessions.dart';
import 'package:fzu_assistant/model/course.dart';
import 'package:fzu_assistant/service/api/course_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final course = Course.fromJson({
    'name': 'test',
    'scheduleRules': [
      const CourseScheduleRule(
        location: 'A',
        startClass: 1,
        endClass: 2,
        startWeek: 1,
        endWeek: 19,
        weekday: 1,
        single: true,
        double: false,
      ).toJson(),
    ],
  });
  Map<String, dynamic> holiday({int week = 3, bool canceled = false}) => {
    'enabled': true,
    'from_week': week,
    'from_weekday': 1,
    'to_date': canceled ? '' : '2026-10-10',
    'to_week': canceled ? 0 : 4,
    'to_weekday': canceled ? 0 : 6,
  };
  List<CourseSession> sessions(
    List<Course> courses,
    int week,
    int day, {
    bool autoAdjust = true,
  }) => CourseSessions.forDay(
    courses: courses,
    week: week,
    weekday: day,
    autoAdjust: autoAdjust,
  );

  test('补课保留原周单双周安排，自动调课关闭时显示原课程', () {
    final result = CourseService.applyHolidayAdjustments([course], [holiday()]);
    expect(sessions(result, 3, 1), isEmpty);
    expect(sessions(result, 4, 6).single.location, 'A');
    expect(sessions(result, 3, 1, autoAdjust: false), hasLength(1));
    expect(course.adjustRules, isEmpty);
  });
  test('开关关闭不请求 west2，开启解析公开响应，原始课表缓存不变', () async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.saveForKey(SpKeys.cacheCoursesMap, '202601', {
      'courses': [course.toJson()],
    });
    final dio = Dio();
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          expect(options.queryParameters, {'term': '202601'});
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'code': '10000',
                'message': 'ok',
                'data': [holiday()],
              },
            ),
          );
        },
      ),
    );
    final service = CourseService(holidayClient: dio);
    expect((await service.getCourses('202601')).single.adjustRules, isEmpty);
    expect(requests, 0);
    final adjusted = await service.getCourses(
      '202601',
      west2AdjustmentsEnabled: true,
    );
    expect(adjusted.single.adjustRules, hasLength(1));
    expect(requests, 1);
    await service.getCourses('202601', west2AdjustmentsEnabled: true);
    expect(requests, 1);
    expect((await service.getCourses('202601')).single.adjustRules, isEmpty);
  });
  test('放假仅取消原日课程', () {
    final result = CourseService.applyHolidayAdjustments(
      [course],
      [holiday(canceled: true)],
    );
    expect(sessions(result, 3, 1), isEmpty);
    expect(sessions(result, 4, 6), isEmpty);
  });
  test('禁用规则和无课的双周不生成补课，重复规则不重复添加', () {
    final result = CourseService.applyHolidayAdjustments(
      [course],
      [holiday(week: 2), holiday()..['enabled'] = false],
    );
    expect(result.single.adjustRules, isEmpty);
    final repeated = CourseService.applyHolidayAdjustments(
      [course],
      [holiday(), holiday()],
    );
    expect(repeated.single.adjustRules, hasLength(1));
  });
}
