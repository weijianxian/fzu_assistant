import 'dart:convert';
import 'package:charset/charset.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/evaluation_required_exception.dart';
import 'package:fzu_assistant/service/api/session_expired_exception.dart';

/// 共享的 HTML 页面抓取方法，封装 GET/POST → decode → parse。
/// 内含评议检测逻辑，与 jwch 库 GetWithIdentifier / PostWithIdentifier 一致。
abstract final class HtmlHelper {
  static Dio get _dio => ApiClient.instance.dio;

  static const _prefix = 'https://jwcjwxt2.fzu.edu.cn:81';

  static Future<Document> fetchHtml(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final resp = await _dio.get<List<int>>(
      url,
      queryParameters: queryParameters,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = await _followIfNeeded(resp, queryParameters: queryParameters);
    return _parse(bytes);
  }

  static Future<Document> postHtml(
    String url, {
    required Map<String, dynamic> data,
    Map<String, dynamic>? queryParameters,
  }) async {
    final resp = await _dio.post<List<int>>(
      url,
      queryParameters: queryParameters,
      data: data,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = await _followIfNeeded(resp, queryParameters: queryParameters);
    return _parse(bytes);
  }

  /// GBK 编码页面专用（如校历）。
  static Future<(Document, String)> fetchHtmlGbk(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final resp = await _dio.get<List<int>>(
      url,
      queryParameters: queryParameters,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = await _followIfNeeded(resp, queryParameters: queryParameters);
    final html = gbk.decode(bytes, allowMalformed: true);
    _checkNologin(html);
    _checkEvaluation(html);
    return (html_parser.parse(html), html);
  }

  static Future<(Document, String)> postHtmlGbk(
    String url, {
    required Map<String, dynamic> data,
    Map<String, dynamic>? queryParameters,
  }) async {
    final resp = await _dio.post<List<int>>(
      url,
      queryParameters: queryParameters,
      data: data,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = await _followIfNeeded(resp, queryParameters: queryParameters);
    final html = gbk.decode(bytes, allowMalformed: true);
    _checkNologin(html);
    _checkEvaluation(html);
    return (html_parser.parse(html), html);
  }

  /// 处理 302 重定向：手动跟随并检测评议页面（与 jwch 逻辑一致）。
  static Future<List<int>> _followIfNeeded(
    Response<List<int>> resp, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (resp.statusCode == 302) {
      final location = resp.headers.value('Location');
      if (location != null) {
        final redirectUrl = '$_prefix$location';
        final redirectResp = await _dio.get<List<int>>(
          redirectUrl,
          queryParameters: queryParameters,
          options: Options(responseType: ResponseType.bytes),
        );
        return redirectResp.data ?? [];
      }
    }
    return resp.data ?? [];
  }

  static Document _parse(List<int> bytes) {
    final html = utf8.decode(bytes, allowMalformed: true);
    _checkNologin(html);
    _checkEvaluation(html);
    return html_parser.parse(html);
  }

  static void _checkNologin(String html) {
    if (html.contains('"nologin"') || html.contains('nologin')) {
      throw const SessionExpiredException();
    }
  }

  /// 检测是否被重定向到评议页面（与 jwch 库逻辑一致）。
  static void _checkEvaluation(String html) {
    if (html.contains('请先对任课教师和教材进行测评')) {
      throw const EvaluationRequiredException();
    }
  }
}
