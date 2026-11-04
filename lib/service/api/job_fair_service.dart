import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fzu_assistant/model/job_fair.dart';
import 'package:html/parser.dart' as html;

enum JobFairFailure { network, response, unavailable }

class JobFairException implements Exception {
  const JobFairException(this.failure);
  final JobFairFailure failure;

  @override
  String toString() => switch (failure) {
    JobFairFailure.network => '招聘活动请求失败，请检查网络后重试',
    JobFairFailure.response => '招聘活动响应格式无效，请稍后重试',
    JobFairFailure.unavailable => '学校招聘活动服务暂不可用，请稍后重试',
  };
}

/// Direct public university API, with its own client and no account state.
class JobFairService {
  JobFairService({HttpClientAdapter? httpClientAdapter})
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          responseType: ResponseType.plain,
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          headers: {'Accept': Headers.jsonContentType},
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      ) {
    if (httpClientAdapter != null) _dio.httpClientAdapter = httpClientAdapter;
  }

  static const endpoint =
      'http://fjrclh.fzu.edu.cn/CmsInterface/getDateZPHKeynoteList_month';

  final Dio _dio;

  Future<JobFairMonthData> getMonth(JobFairMonth month) async {
    try {
      final response = await _dio.post<String>(
        endpoint,
        data: {'dateday': month.apiValue},
      );
      final raw = response.data?.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
      if (raw == null || raw.isEmpty) {
        throw const JobFairException(JobFairFailure.response);
      }
      final Object? body = jsonDecode(raw);
      if (body is! Map<String, dynamic>) {
        throw const JobFairException(JobFairFailure.response);
      }
      if (body['success'] != true) {
        throw const JobFairException(JobFairFailure.unavailable);
      }
      final rows = body['zhaopinhui_keynoteList'];
      if (rows is! List || rows.length > 10000) {
        throw const JobFairException(JobFairFailure.response);
      }
      final events = <JobFair>[];
      final seen = <(JobFairType, String)>{};
      var skipped = 0;
      for (final row in rows) {
        try {
          if (row is! Map<String, dynamic>) {
            throw const FormatException('招聘活动记录格式无效');
          }
          final event = JobFair.fromJson({
            ...row,
            'title': _text(row['title']),
            'place': _text(row['place']),
          });
          if (!month.contains(event.startsAt)) continue;
          if (seen.add((event.type, event.id))) events.add(event);
        } on FormatException {
          skipped++;
        }
      }
      // An unrelated month's valid row must not hide broken records for this one.
      if (events.isEmpty && skipped > 0) {
        throw const JobFairException(JobFairFailure.response);
      }
      return JobFairMonthData(
        month: month,
        events: events,
        skippedCount: skipped,
      );
    } on DioException {
      throw const JobFairException(JobFairFailure.network);
    } on FormatException {
      throw const JobFairException(JobFairFailure.response);
    }
  }

  static String _text(Object? value) {
    if (value == null) return '';
    if (value is! String) throw const FormatException('招聘活动文字格式无效');
    // These source fields are text. Decode entities without stripping literal
    // angle-bracketed names such as "<研发专场>" as if they were HTML elements.
    final escaped = value.replaceAll('<', '&lt;').replaceAll('>', '&gt;');
    return (html.parseFragment(escaped).text ?? '').trim();
  }

  void close() => _dio.close(force: true);
}
