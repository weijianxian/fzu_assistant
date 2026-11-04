import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/screen/toolbox/paper/paper_download_sheet.dart';
import 'package:fzu_assistant/service/api/paper_service.dart';
import 'package:fzu_assistant/service/paper_download_service.dart';

class _Downloader extends PaperDownloadService {
  _Downloader(ValueNotifier<FeatureAccess> access)
    : this._(access, PaperService(access: () => access.value));

  _Downloader._(ValueNotifier<FeatureAccess> access, this.api)
    : super(access: access, api: api);

  final PaperService api;
  int started = 0;
  int resolved = 0;
  CancelToken? token;
  ValueChanged<PaperDownloadProgress>? progress;
  Completer<PaperDownloadedFile>? pending;

  @override
  Future<Uri> resolveUrl(String path, {CancelToken? cancelToken}) async {
    resolved++;
    return Uri.parse('https://papers.example.org/dynamic.pdf');
  }

  @override
  Future<PaperDownloadedFile> download({
    required String path,
    required String name,
    CancelToken? cancelToken,
    ValueChanged<PaperDownloadProgress>? onProgress,
  }) {
    started++;
    token = cancelToken;
    progress = onProgress;
    final result = Completer<PaperDownloadedFile>();
    pending = result;
    cancelToken?.whenCancel.then((_) {
      if (!result.isCompleted) {
        result.completeError(
          const PaperDownloadException(PaperDownloadFailure.cancelled),
        );
      }
    });
    return result.future;
  }

  @override
  void close() {
    if (isClosed) return;
    super.close();
    api.close();
  }
}

Widget _host(ValueNotifier<FeatureAccess> access, _Downloader service) =>
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppBottomSheet<void>(
              context: context,
              builder: (_) => PaperDownloadSheet(
                path: '/数学/数学试卷.pdf',
                name: '数学试卷.pdf',
                service: service,
                access: access,
              ),
            ),
            child: const Text('show sheet'),
          ),
        ),
      ),
    );

void main() {
  late ValueNotifier<FeatureAccess> access;
  late _Downloader service;

  setUp(() {
    access = ValueNotifier(FeatureAccess.allow);
    service = _Downloader(access);
  });

  tearDown(() {
    service.close();
    access.dispose();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(_host(access, service));
    await tester.tap(find.text('show sheet'));
    await tester.pumpAndSettle();
  }

  testWidgets('download progress is indeterminate until a real total arrives', (
    tester,
  ) async {
    await open(tester);
    expect(service.resolved, 1);
    await tester.tap(find.text('下载到本地'));
    await tester.pump();
    expect(service.started, 1);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
    service.progress!(const PaperDownloadProgress(received: 2048));
    await tester.pump();
    expect(find.text('已下载 2.0 KiB'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    service.progress!(const PaperDownloadProgress(received: 2048, total: 4096));
    await tester.pump();
    expect(find.text('2.0 KiB / 4.0 KiB · 50%'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.5,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(service.token!.isCancelled, isTrue);
    expect(find.text('下载已取消'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('在浏览器中打开'), findsOneWidget);
  });

  testWidgets(
    'failed download offers retry and a successful retry exposes local actions',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('下载到本地'));
      await tester.pump();
      service.pending!.completeError(
        const PaperDownloadException(PaperDownloadFailure.incomplete),
      );
      await tester.pumpAndSettle();
      expect(find.text('文件不完整，请重新下载'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(service.started, 2);
      service.pending!.complete(
        PaperDownloadedFile(
          file: File('${Directory.systemTemp.path}/paper-test.pdf'),
          name: '数学试卷.pdf',
          bytes: 4096,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('下载完成'), findsOneWidget);
      expect(find.text('打开文件'), findsOneWidget);
      expect(
        find.text('分享文件'),
        Platform.isLinux ? findsNothing : findsOneWidget,
      );
      expect(find.text('复制链接'), findsOneWidget);
      expect(find.text('在浏览器中打开'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closing the sheet cancels its in-flight download', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('下载到本地'));
    await tester.pump();
    final oldToken = service.token!;
    final context = tester.element(find.byType(PaperDownloadSheet));
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(oldToken.isCancelled, isTrue);
    expect(find.byType(PaperDownloadSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing the owner closes the sheet and cancels its download', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('下载到本地'));
    await tester.pump();
    final oldToken = service.token!;
    service.close();
    await tester.pumpAndSettle();
    expect(oldToken.isCancelled, isTrue);
    expect(find.byType(PaperDownloadSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'revocation closes the sheet and reallow does not restore its content',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('下载到本地'));
      await tester.pump();
      final oldToken = service.token!;
      access.value = FeatureAccess.hide;
      access.value = FeatureAccess.allow;
      await tester.pumpAndSettle();
      expect(oldToken.isCancelled, isTrue);
      expect(find.byType(PaperDownloadSheet), findsNothing);
      expect(find.text('数学试卷.pdf'), findsNothing);
      expect(find.text('打开文件'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(360, 740), const Size(1000, 600)]) {
    testWidgets('download sheet fits supported orientations at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester);
      expect(find.text('下载到本地'), findsOneWidget);
      expect(find.text('在浏览器中打开'), findsOneWidget);
      expect(find.byType(OverflowBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
