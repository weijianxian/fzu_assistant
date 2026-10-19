import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/model/learning_center.dart';

void main() {
  test('appointment history sorts newest first, including merged pages', () {
    LearningAppointment item(String id, String date, String begin) =>
        LearningAppointment.fromJson({
          'id': id,
          'date': date,
          'beginTime': begin,
        });
    final firstPage = [
      item('old', '2026-10-19', '22:00'),
      item('morning', '2026-10-20', '08:00'),
      item('afternoon', '2026-10-20', '14:00'),
      item('invalid', '', ''),
    ]..sort(LearningAppointment.compareNewestFirst);
    expect(firstPage.map((a) => a.id), [
      'afternoon',
      'morning',
      'old',
      'invalid',
    ]);
    final merged = [...firstPage, item('new', '2026-10-21', '08:00')]
      ..sort(LearningAppointment.compareNewestFirst);
    expect(merged.map((a) => a.id), [
      'new',
      'afternoon',
      'morning',
      'old',
      'invalid',
    ]);
  });
  test('Beijing dates and seven-day bounds ignore device timezone', () {
    final now = DateTime.utc(2026, 10, 19, 23);
    expect(learningDate(learningBeijingTime(now)), '2026-10-20');
    expect(learningBeijingTime(now).hour, 7);
    validateLearningPeriod('2026-10-20', '08:00', '09:00', now: now);
    validateLearningPeriod('2026-10-26', '22:00', '22:30', now: now);
    expect(
      () => validateLearningPeriod('2026-10-27', '08:00', '09:00', now: now),
      throwsException,
    );
    expect(
      parseLearningDateTime('2026-10-20 08:00:00'),
      DateTime.utc(2026, 10, 20),
    );
    expect(
      parseLearningDateTime('2026-10-20T00:00:00Z'),
      DateTime.utc(2026, 10, 20),
    );
  });
  test('periods allow half hours up to four hours within seven days', () {
    final now = DateTime.parse('2026-10-20T07:00:00+08:00');
    validateLearningPeriod('2026-10-20', '08:00', '12:00', now: now);
    for (final values in [
      ['2026-10-20', '08:00', '12:30'],
      ['2026-10-20', '09:00', '08:00'],
      ['2026-10-20', '08:01', '09:00'],
      ['2026-10-27', '08:00', '09:00'],
      ['2026-10-19', '08:00', '09:00'],
      ['2026-02-31', '08:00', '09:00'],
      ['2026-10-20', '07:30', '09:00'],
      ['2026-10-20', '22:00', '23:00'],
    ]) {
      expect(
        () => validateLearningPeriod(values[0], values[1], values[2], now: now),
        throwsException,
        reason: values.toString(),
      );
    }
  });
  test(
    'QR validation requires an on-site code with a current one-minute window',
    () {
      final now = DateTime.parse('2026-10-20T08:00:30+08:00');
      expect(
        validLearningQrCode(
          'seatSignInCode@2026-10-20 08:00:00@2026-10-20 08:01:00',
          now,
        ),
        isTrue,
      );
      for (final raw in [
        'invalid',
        'seatSignInCode@bad@date',
        'seatSignInCode@2026-10-20 08:00:00@2026-10-20 08:05:00',
        'seatSignInCode@2026-10-20 07:00:00@2026-10-20 07:01:00',
      ]) {
        expect(validLearningQrCode(raw, now), isFalse);
      }
    },
  );
  test('reservation state follows check-in window, sign, cancellation and completion', () {
    LearningAppointment item({int status = 2, bool sign = false}) =>
        LearningAppointment.fromJson({
          'id': 11,
          'date': '2026-10-20',
          'beginTime': '08:00',
          'endTime': '10:00',
          'auditStatus': status,
          'sign': sign,
        });
    expect(
      item().statusAt(DateTime.parse('2026-10-20T07:00:00+08:00')),
      LearningAppointmentStatus.upcoming,
    );
    expect(
      item().statusAt(DateTime.parse('2026-10-20T07:45:00+08:00')),
      LearningAppointmentStatus.pending,
    );
    expect(
      item().statusAt(DateTime.parse('2026-10-20T10:00:00+08:00')),
      LearningAppointmentStatus.missed,
    );
    expect(
      item(sign: true).statusAt(DateTime.parse('2026-10-20T09:00:00+08:00')),
      LearningAppointmentStatus.signedIn,
    );
    expect(
      item(status: 3).statusAt(DateTime.now()),
      LearningAppointmentStatus.cancelled,
    );
    expect(
      item(status: 4).statusAt(DateTime.now()),
      LearningAppointmentStatus.completed,
    );
  });
}
