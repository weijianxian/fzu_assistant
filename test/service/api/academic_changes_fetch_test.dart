import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/academic_change.dart';
import 'package:fzu_assistant/service/academic_changes_service.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/reminder_channel.dart';
import 'exam_rooms_fetch_test.dart' show ExamAdapter;

class ChangesAdapter extends ExamAdapter {
  String score = '成绩尚未录入';
  bool invalidMarks = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!options.uri.path.endsWith('/score_sheet.aspx')) {
      return super.fetch(options, requestStream, cancelFuture);
    }
    requests.add(options);
    return htmlResponse(
      invalidMarks
          ? '<html>invalid</html>'
          : '''
      <table id="ContentPlaceHolder1_DataList_xxk">
        <tr><td>header</td></tr><tr><td>columns</td></tr>
        <tr style="background:white">
          <td>主修</td><td>202601</td><td>高等数学</td><td><span>3</span></td>
          <td><font>$score</font></td><td>3</td><td>3</td><td>必修</td>
          <td>期末</td><td>李老师</td><td>旗山</td><td></td>
        </tr>
      </table>
    ''',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient.instance;
  final changes = AcademicChangesService.instance;
  late HttpClientAdapter previousAdapter;
  late ChangesAdapter adapter;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mockReminderChannel();
    await changes.clear();
    previousAdapter = api.dio.httpClientAdapter;
    adapter = ChangesAdapter();
    api.dio.httpClientAdapter = adapter;
    await api.login('20230001', 'test-only', '1234');
    adapter.requests.clear();
  });
  tearDown(() async {
    await api.clearSession();
    api.dio.httpClientAdapter = previousAdapter;
  });

  test('真实成绩查询路径建立基线、识别出分，失败不改变基线，退出清理', () async {
    final academic = AcademicService();
    await academic.getMarks();
    expect(changes.value, isEmpty);
    adapter.score = '92';
    await academic.getMarks();
    expect(changes.value.single.type, AcademicChangeType.gradeAdded);
    adapter.invalidMarks = true;
    await expectLater(academic.getMarks(), throwsA(isA<Exception>()));
    adapter.invalidMarks = false;
    await academic.getMarks();
    expect(changes.value, hasLength(1));
    await api.clearSession();
    expect(changes.value, isEmpty);
    expect(
      (await SharedPreferences.getInstance()).getString(
        AcademicChangesService.storageKey,
      ),
      isNull,
    );
  });

  test('考试查询识别时间变动，缓存读取不产生变化，坏页面不误报撤回', () async {
    final academic = AcademicService();
    await academic.getExamRooms('202601', useCache: false);
    expect(changes.value, isEmpty);
    adapter.page = adapter.page.replaceAll('14:00-16:00', '15:00-17:00');
    await academic.getExamRooms('202601', useCache: false);
    expect(changes.value.single.type, AcademicChangeType.examChanged);
    expect(changes.value.single.after, contains('15:00-17:00'));
    adapter.page = '<html>invalid</html>';
    await expectLater(
      academic.getExamRooms('202601', useCache: false),
      throwsStateError,
    );
    api.usingCachedSession.value = true;
    await academic.getExamRooms('202601', useCache: false);
    expect(changes.value, hasLength(1));
  });

  test('考试查询不因缺少样式或截断课程行而误报撤回', () async {
    final academic = AcademicService();
    await academic.getExamRooms('202601', useCache: false);
    adapter.page = adapter.page.replaceAll(' style="background:white"', '');
    await academic.getExamRooms('202601', useCache: false);
    expect(changes.value, isEmpty);
    adapter.page = adapter.page.replaceFirst('<td></td><td></td>', '<td></td>');
    await expectLater(
      academic.getExamRooms('202601', useCache: false),
      throwsStateError,
    );
    expect(changes.value, isEmpty);
    api.usingCachedSession.value = true;
    expect((await academic.getExamRooms('202601')).single.courseName, '高等数学');
  });
}
