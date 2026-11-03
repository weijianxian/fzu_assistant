import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/utility_payment.dart';
import 'package:fzu_assistant/screen/toolbox/utility_payment/utility_payment_page.dart';

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  testWidgets(
    'desktop platforms show mobile guidance without unusable campus actions',
    (tester) async {
      await tester.pumpWidget(_app(const UtilityPaymentPage()));
      expect(find.textContaining('需要手机上的中国建设银行'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    }),
  );

  testWidgets(
    'failed mobile launch offers a copyable campus link and official app download',
    (tester) async {
      String? clipboard;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final opened = <Uri>[];
      await tester.pumpWidget(
        _app(
          UtilityPaymentPage(
            launcher: (uri) async {
              opened.add(uri);
              return uri.scheme == 'https';
            },
          ),
        ),
      );
      await tester.tap(find.text('旗山校区'));
      // The selected campus keeps an animated progress indicator while the
      // failure dialog awaits user action.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(opened, [UtilityCampus.qishan.paymentUri]);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '复制缴费链接'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(clipboard, UtilityCampus.qishan.paymentUri.toString());
      await tester.tap(find.widgetWithText(FilledButton, '下载建行 App'));
      await tester.pumpAndSettle();
      expect(opened.last, UtilityPaymentLinks.installationUri(ios: false));
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
