import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/toolbox/paper/papers_page.dart';
import 'package:fzu_assistant/service/api/paper_service.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

class _Service extends PaperService {
  _Service(AppSettings settings)
    : super(access: () => settings.papersAccess.value);
  int requests = 0;
  int downloads = 0;
  Completer<PaperDirectory>? pending;
  @override
  Future<PaperDirectory> list(String path) async {
    requests++;
    if (pending != null) return pending!.future;
    return PaperDirectory(
      path: path,
      entries: const [
        PaperEntry(name: '高等数学', isFolder: true),
        PaperEntry(name: '2025数学.pdf', isFolder: false),
        PaperEntry(name: '2024物理.pdf', isFolder: false),
      ],
    );
  }

  @override
  Future<Uri> download(String filepath) async {
    downloads++;
    return Uri.parse('https://papers.example.org/exam.pdf');
  }
}

Widget _app(
  AppSettings settings,
  _Service service, {
  void Function(RouteSettings)? onRoute,
}) => AppSettingsProvider(
  settings: settings,
  child: MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PapersPage(service: service),
    onGenerateRoute: (route) {
      onRoute?.call(route);
      return MaterialPageRoute<void>(builder: (_) => const Scaffold());
    },
  ),
);

void main() {
  testWidgets('tip and hidden direct routes never initialize a paper query', (
    tester,
  ) async {
    final settings = AppSettings();
    final service = _Service(settings);
    await tester.pumpWidget(_app(settings, service));
    await tester.pumpAndSettle();
    expect(service.requests, 0);
    expect(find.text('第三方服务'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    settings.papersAccess.value = FeatureAccess.hide;
    await tester.pumpAndSettle();
    expect(service.requests, 0);
    expect(find.text('历年卷入口已隐藏'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    settings.dispose();
    service.close();
  });

  testWidgets(
    'allow initializes lazily and revoked in-flight results never appear',
    (tester) async {
      final settings = AppSettings();
      final service = _Service(settings)..pending = Completer<PaperDirectory>();
      await tester.pumpWidget(_app(settings, service));
      await tester.pumpAndSettle();
      settings.papersAccess.value = FeatureAccess.allow;
      await tester.pump();
      expect(service.requests, 1);
      settings.papersAccess.value = FeatureAccess.tip;
      await tester.pumpAndSettle();
      service.pending!.complete(
        const PaperDirectory(
          path: '/',
          entries: [PaperEntry(name: '撤销后旧响应.pdf', isFolder: false)],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('撤销后旧响应.pdf'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
      service.close();
    },
  );

  testWidgets('revoking consent clears an already open download dialog', (
    tester,
  ) async {
    final settings = AppSettings()..papersAccess.value = FeatureAccess.allow;
    final service = _Service(settings);
    await tester.pumpWidget(_app(settings, service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025数学.pdf'));
    await tester.pumpAndSettle();
    expect(service.downloads, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
    settings.papersAccess.value = FeatureAccess.hide;
    await tester.pumpAndSettle();
    expect(find.text('2025数学.pdf'), findsNothing);
    expect(find.text('复制链接'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    settings.dispose();
    service.close();
  });

  for (final size in [const Size(360, 740), const Size(1000, 600)]) {
    testWidgets(
      'allowed directory search is local and folder navigation is named at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = AppSettings()
          ..papersAccess.value = FeatureAccess.allow;
        final service = _Service(settings);
        RouteSettings? navigated;
        await tester.pumpWidget(
          _app(settings, service, onRoute: (route) => navigated = route),
        );
        await tester.pumpAndSettle();
        expect(service.requests, 1);
        expect(find.text('2024物理.pdf'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '数学');
        await tester.pumpAndSettle();
        expect(service.requests, 1);
        expect(find.text('2024物理.pdf'), findsNothing);
        expect(find.text('2025数学.pdf'), findsOneWidget);
        await tester.tap(find.text('高等数学'));
        await tester.pumpAndSettle();
        expect(navigated?.name, AppRoutes.papers);
        expect((navigated?.arguments as PapersArgs).path, '/高等数学');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        settings.dispose();
        service.close();
      },
    );
  }
}
