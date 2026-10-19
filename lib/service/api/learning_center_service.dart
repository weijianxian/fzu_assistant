import 'package:dio/dio.dart';
import 'package:fzu_assistant/model/learning_center.dart';
import 'package:fzu_assistant/service/api/sso_service.dart';

/// Endpoints and payloads follow fzuhelper-app utils/learning-center/api-service.ts.
class LearningCenterService {
  LearningCenterService({Dio? dio, SsoService? sso})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://aiot.fzu.edu.cn/api/ibs',
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 45),
            ),
          ),
      sso = sso ?? SsoService.instance;
  final Dio dio;
  final SsoService sso;
  static final instance = LearningCenterService();

  Future<Map<String, dynamic>> request(
    String path,
    Map<String, dynamic> data, {
    String? token,
  }) async {
    final auth = token ?? await sso.loadStudyToken();
    if (auth == null || auth.isEmpty) throw const SsoLoginRequired();
    final response = await dio.post<dynamic>(
      path,
      data: data,
      options: Options(
        contentType: Headers.jsonContentType,
        followRedirects: false,
        validateStatus: (_) => true,
        headers: {
          'token': auth,
          'Referer': 'https://aiot.fzu.edu.cn/ibs/',
          'Origin': 'https://aiot.fzu.edu.cn',
          'User-Agent': SsoService.userAgent,
        },
      ),
    );
    // The reference API uses HTTP 500 for expired tokens. Do not retry mutations.
    if (response.statusCode == 500 ||
        response.statusCode == 401 ||
        response.statusCode == 302 ||
        response.statusCode == 303) {
      if (token == null) await sso.clearStudyToken();
      throw const SsoLoginRequired();
    }
    if (response.statusCode != 200 || response.data is! Map) {
      throw Exception('学习中心请求失败，请稍后重试');
    }
    final result = Map<String, dynamic>.from(response.data as Map);
    if (result['code'].toString() != '0') {
      if (result['code'].toString() == '401') {
        if (token == null) await sso.clearStudyToken();
        throw const SsoLoginRequired();
      }
      throw Exception(
        result['code'].toString() == '403'
            ? '刷新过快，请稍等 3 分钟后重试'
            : '${result['msg'] ?? '学习中心操作失败'}',
      );
    }
    return result;
  }

  Future<List<LearningSeat>> querySeats({
    required String date,
    required String begin,
    required String end,
    required String floor,
    String? token,
  }) async {
    validateLearningPeriod(date, begin, end);
    final result = await request('/spaceAppoint/app/queryStationStatusByTime', {
      'beginTime': '$date $begin',
      'endTime': '$date $end',
      'floorLike': floor,
      'parentId': 'null',
      'region': '1',
    }, token: token);
    return (result['dataList'] as List? ?? [])
        .map((e) => LearningSeat.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort(
        (a, b) =>
            (int.tryParse(a.name) ?? 0).compareTo(int.tryParse(b.name) ?? 0),
      );
  }

  Future<List<LearningAppointment>> appointments({
    int page = 1,
    String? token,
  }) async {
    final result = await request('/spaceAppoint/app/queryMyAppoint', {
      'currentPage': '$page',
      'pageSize': '30',
      'auditStatus': '',
    }, token: token);
    return (result['dataList'] as List? ?? [])
        .map(
          (e) =>
              LearningAppointment.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<LearningTimeSlot>> seatTimes(
    String id,
    String date, {
    String? token,
  }) async {
    final result = await request('/spaceAppoint/app/querySpaceAppointTime', {
      'spaceId': id,
      'date': date,
    }, token: token);
    return ((result['data'] as Map?)?['timeDiamondList'] as List? ?? [])
        .map(
          (e) => LearningTimeSlot.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<Map<String, dynamic>> reserve({
    required String spaceId,
    required String date,
    required String begin,
    required String end,
    String? token,
  }) {
    validateLearningPeriod(date, begin, end);
    if (spaceId.isEmpty) throw Exception('座位 ID 不能为空');
    return request('/spaceAppoint/app/addSpaceAppoint', {
      'spaceId': spaceId,
      'beginTime': begin,
      'endTime': end,
      'date': date,
    }, token: token);
  }

  Future<Map<String, dynamic>> cancel(String id, {String? token}) =>
      _action('spaceAppoint/app/revocationAppointApp', id, token);
  Future<Map<String, dynamic>> signIn(String id, {String? token}) =>
      _action('station/app/signIn', id, token);
  Future<Map<String, dynamic>> signOut(String id, {String? token}) =>
      _action('station/app/signOut', id, token);
  Future<Map<String, dynamic>> _action(String path, String id, String? token) {
    if (id.trim().isEmpty) throw Exception('预约 ID 不能为空');
    return request('/$path', {'id': id.trim()}, token: token);
  }
}
