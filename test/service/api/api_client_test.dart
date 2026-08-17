import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/api/api_client.dart';

void main() {
  test(
    'expireCookiesForDebug clears cookies but keeps the client usable',
    () async {
      final api = ApiClient.instance;
      final uri = Uri.parse('https://jwcjwxt2.fzu.edu.cn:81/');
      await api.cookieJar.saveFromResponse(uri, [Cookie('session', 'value')]);

      expect(await api.cookieJar.loadForRequest(uri), isNotEmpty);

      await api.expireCookiesForDebug();

      expect(await api.cookieJar.loadForRequest(uri), isEmpty);
    },
  );
}
