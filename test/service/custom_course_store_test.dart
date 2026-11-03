import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/utils/course_sessions.dart';
import 'package:fzu_assistant/model/custom_course.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

CustomCourse _course({
  String id = 'first',
  String account = 'student-a',
  String term = '202601',
  String name = '实验课',
  int color = 0xff83b6b1,
}) => CustomCourse(
  id: id,
  account: account,
  term: term,
  name: name,
  teacher: '教师',
  location: '实验楼 101',
  startClass: 3,
  endClass: 4,
  startWeek: 2,
  endWeek: 8,
  weekday: 2,
  single: false,
  double: true,
  remark: '携带电脑',
  color: color,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'saving, editing and removing a course preserve other accounts and terms',
    () async {
      final store = CustomCourseStore();
      addTearDown(store.dispose);
      await store.save(_course());
      await store.save(_course(account: 'student-b', color: 0xff92c5f2));
      await store.save(_course(term: '202501'));
      await store.save(_course(name: '编辑后的课', color: 0xfffdc683));
      expect(store.value, hasLength(3));
      expect(store.forTerm('student-a', '202601').single.name, '编辑后的课');
      expect(store.forTerm('student-b', '202601').single.name, '实验课');
      expect(
        store.colorForCourse(
          store.coursesForTerm('student-a', '202601').single,
        ),
        0xfffdc683,
      );
      expect(
        store.colorForCourse(
          store.coursesForTerm('student-b', '202601').single,
        ),
        0xff92c5f2,
      );

      final reload = CustomCourseStore();
      addTearDown(reload.dispose);
      await reload.load();
      expect(
        reload.value.map((entry) => entry.toJson()),
        store.value.map((entry) => entry.toJson()),
      );
      await reload.remove(reload.forTerm('student-a', '202601').single);
      expect(reload.forTerm('student-a', '202601'), isEmpty);
      expect(reload.forTerm('student-a', '202501'), hasLength(1));
      expect(reload.forTerm('student-b', '202601'), hasLength(1));
    },
  );

  test(
    'saving without first loading never discards existing persisted courses',
    () async {
      final existing = _course(id: 'existing');
      SharedPreferences.setMockInitialValues({
        CustomCourseStore.storageKey: jsonEncode([existing.toJson()]),
      });
      final store = CustomCourseStore();
      addTearDown(store.dispose);
      await store.save(_course(id: 'new'));
      expect(store.value.map((entry) => entry.id), ['existing', 'new']);
      expect(() => store.value.clear(), throwsUnsupportedError);
    },
  );

  test('editing across terms moves the old identity and forbids changing its owner', () async {
    final store = CustomCourseStore();
    addTearDown(store.dispose);
    final original = _course();
    await store.save(original);
    await store.save(_course(id: 'unrelated', term: '202501'));
    final moved = _course(term: '202501', name: '移到历史学期');
    await store.save(moved, previous: original);
    expect(store.forTerm('student-a', '202601'), isEmpty);
    expect(store.forTerm('student-a', '202501'), hasLength(2));
    await expectLater(
      store.save(_course(account: 'student-b'), previous: moved),
      throwsStateError,
    );
    expect(store.value, hasLength(2));
    final reloaded = CustomCourseStore();
    addTearDown(reloaded.dispose);
    await reloaded.load();
    expect(reloaded.forTerm('student-a', '202601'), isEmpty);
    expect(reloaded.forTerm('student-a', '202501'), hasLength(2));
  });

  test(
    'course conversion uses the shared week, parity, day and period filter',
    () {
      final course = _course().toCourse();
      List<CourseSession> sessions(int week, int weekday) =>
          CourseSessions.forDay(
            courses: [course],
            week: week,
            weekday: weekday,
            autoAdjust: true,
          );
      expect(sessions(2, 2).single.startClass, 3);
      expect(sessions(2, 2).single.endClass, 4);
      expect(sessions(2, 2).single.location, '实验楼 101');
      expect(sessions(1, 2), isEmpty);
      expect(sessions(3, 2), isEmpty);
      expect(sessions(10, 2), isEmpty);
      expect(sessions(2, 3), isEmpty);
    },
  );

  test(
    'imports reject malformed fields, invalid ranges and duplicate identities',
    () {
      final valid = _course().toJson();
      expect(CustomCourse.parseList([valid]).single.toJson(), valid);
      for (final patch in [
        {'account': ''},
        {'term': '2026'},
        {'name': ''},
        {'startWeek': 0},
        {'endWeek': 20},
        {'startWeek': 9, 'endWeek': 8},
        {'startClass': 0},
        {'endClass': 12},
        {'startClass': 5, 'endClass': 4},
        {'weekday': 8},
        {'single': false, 'double': false},
        {'color': -1},
        {'color': 0x0083b6b1},
        {'startClass': '3'},
        {'remark': null},
      ]) {
        expect(
          () => CustomCourse.parseList([
            {...valid, ...patch},
          ]),
          throwsFormatException,
          reason: '$patch',
        );
      }
      expect(
        () => CustomCourse.parseList([valid, valid]),
        throwsFormatException,
      );
      expect(() => CustomCourse.parseList([null]), throwsFormatException);
      expect(
        () => CustomCourse.parseList({'courses': []}),
        throwsFormatException,
      );
    },
  );

  test(
    'reload supports a validated WebDAV replacement and notifies observers',
    () async {
      final store = CustomCourseStore();
      addTearDown(store.dispose);
      await store.load();
      var notifications = 0;
      store.addListener(() => notifications++);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        CustomCourseStore.storageKey,
        jsonEncode([_course().toJson()]),
      );
      await store.load();
      expect(notifications, 1);
      expect(store.value.single.name, '实验课');
    },
  );
}
