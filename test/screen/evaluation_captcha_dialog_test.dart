import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/evaluation.dart';
import 'package:fzu_assistant/screen/toolbox/evaluation/evaluation_captcha_dialog.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';

const _items = [
  EvaluationSubmitItem(
    teacher: EvaluationTeacher(
      courseName: 'Course A',
      teacherName: 'Teacher A',
      params: {'teacher': 'a'},
    ),
    score: '90',
    comment: 'Comment A',
  ),
  EvaluationSubmitItem(
    teacher: EvaluationTeacher(
      courseName: 'Course B',
      teacherName: 'Teacher B',
      params: {'teacher': 'b'},
    ),
    score: '95',
    comment: 'Comment B',
  ),
];

class _EvaluationService extends AcademicService {
  final submissions = <Completer<bool>>[];
  final submittedTeachers = <String>[];
  final retryCaptcha = Completer<Uint8List>();
  int captchaRequests = 0;

  @override
  Future<Uint8List> getEvaluationCaptcha() async {
    if (++captchaRequests == 1) throw StateError('No cached captcha');
    return retryCaptcha.future;
  }

  @override
  Future<bool> submitEvaluation(
    Map<String, String> teacherParams,
    String score,
    String comment,
    String captcha,
  ) {
    submittedTeachers.add(teacherParams['teacher']!);
    final submission = Completer<bool>();
    submissions.add(submission);
    return submission.future;
  }
}

Future<void> _openDialog(
  WidgetTester tester,
  _EvaluationService service, {
  bool landscape = false,
  VoidCallback? onSuccess,
}) async {
  tester.view.physicalSize = landscape
      ? const Size(960, 540)
      : const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showEvaluationCaptchaDialog(
              context,
              service,
              _items,
              onSuccess ?? () {},
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '1234');
}

void main() {
  testWidgets('queued input and button callbacks submit only once', (
    tester,
  ) async {
    final service = _EvaluationService();
    await _openDialog(tester, service);
    final submit = tester
        .widget<FilledButton>(find.byType(FilledButton))
        .onPressed!;
    final onSubmitted = tester
        .widget<TextField>(find.byType(TextField))
        .onSubmitted!;

    submit();
    onSubmitted('1234');
    submit();
    await tester.pump();

    expect(service.submittedTeachers, ['a']);
    service.submissions.single.complete(false);
    await tester.pump();
    service.retryCaptcha.completeError(StateError('Captcha unavailable'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rejected submission keeps a valid item while captcha refreshes',
    (tester) async {
      final service = _EvaluationService();
      await _openDialog(tester, service);
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!();
      await tester.pump();
      service.submissions.single.complete(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(service.captchaRequests, 2);
      expect(find.text('Teacher A'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);

      service.retryCaptcha.completeError(StateError('Captcha unavailable'));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closing during submission stops the remaining batch', (
    tester,
  ) async {
    final service = _EvaluationService();
    var successes = 0;
    await _openDialog(
      tester,
      service,
      landscape: true,
      onSuccess: () => successes++,
    );
    tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    service.submissions.single.complete(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(service.submittedTeachers, ['a']);
    expect(successes, 0);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing during captcha refresh ignores its late result', (
    tester,
  ) async {
    final service = _EvaluationService();
    await _openDialog(tester, service, landscape: true);
    tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!();
    await tester.pump();
    service.submissions.single.complete(false);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    service.retryCaptcha.completeError(StateError('Captcha unavailable'));
    await tester.pump();

    expect(service.submittedTeachers, ['a']);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
