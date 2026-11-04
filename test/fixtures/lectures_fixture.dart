import 'dart:typed_data';

import 'package:charset/charset.dart';
import 'package:dio/dio.dart';

/// Local-only fixture for exercising the real ApiClient/HtmlHelper request path.
class LecturesFixtureAdapter implements HttpClientAdapter {
  static const registeredHtml = '''
    <table id="ContentPlaceHolder1_DataList_xxk">
      <tr><td colspan="7">&nbsp;</td></tr>
      <tr><td colspan="7">已报名讲座</td></tr>
      <tr><td>类别</td><td>期数</td><td>题目</td><td>主讲人</td>
        <td>时间</td><td>地点</td><td>听取讲座情况</td></tr>
      <tr style="background:white">
        <td>科技</td><td>36</td><td>人工智能与校园生活</td><td>李老师</td>
        <td>2026-11-05&nbsp;&nbsp;19：30</td>
        <td>旗山校区图书馆报告厅</td><td>已听取</td>
      </tr>
    </table>
  ''';

  String lecturesHtml = registeredHtml;
  bool encodeGbk = false;
  bool failLectureRequests = false;
  Future<ResponseBody>? nextLectureResponse;
  final requests = <RequestOptions>[];

  List<RequestOptions> get lectureRequests => requests
      .where((request) => request.uri.path.endsWith('/jxjt_cszt.aspx'))
      .toList();

  ResponseBody htmlResponse(String body) => encodeGbk
      ? ResponseBody.fromBytes(
          gbk.encode(body),
          200,
          headers: {
            Headers.contentTypeHeader: ['text/html; charset=gbk'],
          },
        )
      : ResponseBody.fromString(
          body,
          200,
          headers: {
            Headers.contentTypeHeader: ['text/html; charset=utf-8'],
          },
        );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.uri.path;
    ResponseBody redirect(String location) => ResponseBody.fromString(
      '',
      302,
      headers: {
        'location': [location],
        'set-cookie': ['ASP.NET_SessionId=lecture-fixture; Path=/; HttpOnly'],
      },
    );

    if (path.endsWith('/logincheck.asp')) {
      return redirect(
        '/loginchk_xs.aspx?token=fixture-token&id=fixture-id&num=fixture-num',
      );
    }
    if (path.endsWith('/SSOLogin')) {
      return ResponseBody.fromString(
        '{"code":200}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (path.endsWith('/loginchk_xs.aspx')) {
      return redirect('/index.aspx?id=LECTURE-IDENTIFIER');
    }
    if (path.endsWith('/StudentInformation.aspx')) {
      return htmlResponse(
        '<span id="ContentPlaceHolder1_LB_xh">20230001</span>',
      );
    }
    if (path.endsWith('/jxjt_cszt.aspx')) {
      if (failLectureRequests) {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'Fixture connection failure',
        );
      }
      final pending = nextLectureResponse;
      if (pending != null) {
        nextLectureResponse = null;
        return pending;
      }
      return htmlResponse(lecturesHtml);
    }
    throw StateError('Unexpected fixture request: ${options.uri}');
  }

  @override
  void close({bool force = false}) {}
}
