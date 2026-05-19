import 'dart:convert';
import 'package:charset/charset.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:fzu_assistant/service/api/api_client.dart';

/// 共享的 HTML 页面抓取方法，封装 GET/POST → utf8.decode → parse。
abstract final class HtmlHelper {
  static Dio get _dio => ApiClient.instance.dio;

  static Future<Document> fetchHtml(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final resp = await _dio.get<List<int>>(
      url,
      queryParameters: queryParameters,
      options: Options(responseType: ResponseType.bytes),
    );
    return _parse(resp.data!);
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
    return _parse(resp.data!);
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
    final html = gbk.decode(resp.data!, allowMalformed: true);
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
    final html = gbk.decode(resp.data!, allowMalformed: true);
    return (html_parser.parse(html), html);
  }

  static Document _parse(List<int> bytes) {
    final html = utf8.decode(bytes, allowMalformed: true);
    return html_parser.parse(html);
  }
}
