import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/utility_payment.dart';

void main() {
  test(
    'CCB campus links preserve bank routing parameters and encrypted payloads',
    () {
      final payloads = <String>{};
      for (final campus in UtilityCampus.values) {
        final uri = campus.paymentUri;
        expect(uri.scheme, 'ccbapp');
        expect(uri.host, 'ccblink');
        expect(uri.queryParameters['funcid'], '01909001');
        expect(uri.queryParameters['openflag'], '1');
        expect(uri.queryParameters['CCBget'], '1');
        final payload = uri.queryParameters['ccbLCSParam']!;
        expect(payload, matches(RegExp(r'^[0-9A-F]+$')));
        expect(payload.length.isEven, isTrue);
        expect(payloads.add(payload), isTrue);
        expect(
          uri.queryParameters['THIRD_SYS_ID'],
          campus == UtilityCampus.qishan ? 'BI0001' : '999998',
        );
        expect(
          uri.queryParameters['link_id'],
          {UtilityCampus.qishan, UtilityCampus.yishan}.contains(campus)
              ? '8c39ab33bca94639b760dc0a160dc1aa'
              : 'e8211bf013c04e9d83aa95d734f32f32',
        );
      }
    },
  );
  test('installation links use the official store and CCB download page', () {
    expect(
      UtilityPaymentLinks.installationUri(ios: true).toString(),
      'https://apps.apple.com/cn/app/id391965015',
    );
    expect(
      UtilityPaymentLinks.installationUri(ios: false).toString(),
      'https://m2.ccb.com/cn/mobilev3/home/include/download.html',
    );
  });
}
