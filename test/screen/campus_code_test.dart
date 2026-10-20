import 'dart:async';
import 'dart:convert';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/campus_code.dart';
import 'package:fzu_assistant/screen/guest/sso_login_page.dart';
import 'package:fzu_assistant/screen/campus_code/campus_code_page.dart';
import 'package:fzu_assistant/service/api/campus_code_service.dart';
import 'package:fzu_assistant/service/api/sso_service.dart';

class _Service extends CampusCodeService {
  int sessions = 0;
  int payments = 0;
  bool denyPayments = false;
  Completer<CampusPayCode>? pending;
  Completer<({String token, CampusUser user})>? pendingSession;
  @override
  Future<({String token, CampusUser user})> loadSession() async {
    sessions++;
    if (pendingSession != null) return pendingSession!.future;
    return (
      token: 'fake',
      user: const CampusUser(name: '测试用户', account: '123456789'),
    );
  }

  @override
  Future<CampusPayCode> getPayCode(String token) async {
    payments++;
    if (denyPayments) throw Exception('未开通离线支付权限');
    if (pending != null) return pending!.future;
    return code();
  }

  CampusPayCode code() => CampusPayCode(
    bytes: Uint8List.fromList([49, 50, 51, 0, 128, 255]),
    createdAt: DateTime.now(),
  );
}

Widget app(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  testWidgets('unauthenticated session checks never show a white code card', (
    tester,
  ) async {
    final service = _Service()
      ..pendingSession = Completer<({String token, CampusUser user})>();
    await tester.pumpWidget(app(CampusCodePage(service: service)));
    await tester.pump();
    expect(find.byType(Card), findsNothing);
    expect(find.byType(BarcodeWidget), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    service.pendingSession!.completeError(SsoLoginRequired());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, '统一身份认证登录'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
    service.dio.close(force: true);
  });
  testWidgets('SSO session changes remove a mounted QR immediately', (
    tester,
  ) async {
    final service = _Service();
    await tester.pumpWidget(app(CampusCodePage(service: service)));
    await tester.pumpAndSettle();
    expect(find.byType(BarcodeWidget), findsOneWidget);
    service.sso.sessionRevision.value++;
    await tester.pumpAndSettle();
    expect(find.byType(BarcodeWidget), findsNothing);
    expect(find.widgetWithText(FilledButton, '统一身份认证登录'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    service.dio.close(force: true);
  });
  testWidgets(
    'floating refresh keeps the current QR in place until replacement arrives',
    (tester) async {
      final service = _Service();
      await tester.pumpWidget(app(CampusCodePage(service: service)));
      await tester.pumpAndSettle();
      final qr = find.byType(BarcodeWidget);
      final before = tester.getRect(qr);
      final oldBytes = tester.widget<BarcodeWidget>(qr).data;
      service.pending = Completer<CampusPayCode>();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(tester.getRect(qr), before);
      expect(tester.widget<BarcodeWidget>(qr).data, oldBytes);
      expect(
        find.descendant(
          of: find.byType(FloatingActionButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      final next = CampusPayCode(
        bytes: Uint8List.fromList([1, 2, 3]),
        createdAt: DateTime.now(),
      );
      service.pending!.complete(next);
      await tester.pumpAndSettle();
      expect(tester.getRect(qr), before);
      expect(tester.widget<BarcodeWidget>(qr).data, next.bytes);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      service.dio.close(force: true);
    },
  );
  testWidgets(
    'only the selected main tab refreshes codes and raises brightness',
    (tester) async {
      final service = _Service();
      final active = ValueNotifier(false);
      final brightnessCalls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('github.com/aaassseee/screen_brightness'),
        (call) async {
          brightnessCalls.add(call.method);
          return null;
        },
      );
      await tester.pumpWidget(
        app(
          ValueListenableBuilder<bool>(
            valueListenable: active,
            builder: (_, value, _) =>
                CampusCodePage(service: service, isActive: value),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 60));
      expect(service.sessions, 0);
      active.value = true;
      await tester.pumpAndSettle();
      expect(service.payments, 1);
      expect(brightnessCalls.last, 'setApplicationScreenBrightness');
      await tester.pump(const Duration(seconds: 50));
      await tester.pumpAndSettle();
      expect(service.payments, 2);
      active.value = false;
      await tester.pumpAndSettle();
      expect(brightnessCalls.last, 'resetApplicationScreenBrightness');
      await tester.pump(const Duration(seconds: 60));
      expect(service.payments, 2);
      active.value = true;
      await tester.pumpAndSettle();
      expect(service.payments, 3);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(brightnessCalls.last, 'resetApplicationScreenBrightness');
      active.dispose();
      service.dio.close(force: true);
    },
  );
  testWidgets(
    'SSO password uses the shared login field with a working visibility toggle',
    (tester) async {
      // Loading saved academic account must not access a platform channel in test.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (_) async => null,
      );
      await tester.pumpWidget(app(const SsoLoginPage()));
      await tester.pump();
      final field = find.widgetWithText(TextField, '密码');
      expect(tester.widget<TextField>(field).obscureText, isTrue);
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();
      expect(tester.widget<TextField>(field).obscureText, isFalse);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'byte payment QR and library QR/Code128 render in narrow and landscape layouts',
    (tester) async {
      final service = _Service();
      await tester.pumpWidget(app(CampusCodePage(service: service)));
      await tester.pumpAndSettle();
      var codes = tester
          .widgetList<BarcodeWidget>(find.byType(BarcodeWidget))
          .toList();
      expect(codes.single.isBytes, isTrue);
      expect(codes.single.data, [49, 50, 51, 0, 128, 255]);
      expect(
        find.descendant(
          of: find.byType(PageView),
          matching: find.text('上下滑动切换消费码和入馆码'),
        ),
        findsOneWidget,
      );
      await tester.drag(find.byType(PageView), const Offset(0, -650));
      await tester.pumpAndSettle();
      codes = tester
          .widgetList<BarcodeWidget>(find.byType(BarcodeWidget))
          .toList();
      expect(codes, hasLength(2));
      expect(find.text('上下滑动切换消费码和入馆码'), findsNothing);
      expect(codes.every((c) => ascii.decode(c.data) == '123456789'), isTrue);
      expect(service.payments, 1);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(800, 360);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      service.dio.close(force: true);
    },
  );
  testWidgets(
    'payment failure allows switching to library and hiding cancels a late payment result',
    (tester) async {
      final service = _Service()..denyPayments = true;
      final active = ValueNotifier(true);
      await tester.pumpWidget(
        app(
          ValueListenableBuilder<bool>(
            valueListenable: active,
            builder: (_, value, _) => TickerMode(
              enabled: value,
              child: CampusCodePage(service: service),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('未开通离线支付权限'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(find.byType(BarcodeWidget), findsNWidgets(2));
      service.denyPayments = false;
      service.pending = Completer<CampusPayCode>();
      await tester.drag(find.byType(PageView), const Offset(0, 650));
      await tester.pump();
      await tester.pump();
      active.value = false;
      await tester.pump();
      service.pending!.complete(service.code());
      await tester.pump();
      expect(find.byType(BarcodeWidget), findsNothing);
      final sessions = service.sessions;
      await tester.pump(const Duration(seconds: 60));
      expect(service.sessions, sessions);
      await tester.pumpWidget(const SizedBox());
      active.dispose();
      service.dio.close(force: true);
      expect(tester.takeException(), isNull);
    },
  );
}
