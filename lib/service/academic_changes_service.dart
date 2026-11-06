import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/model/academic_change.dart';
import 'package:fzu_assistant/model/exam_room.dart';
import 'package:fzu_assistant/model/mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AcademicObservation {
  const AcademicObservation(this.account, this.generation, this.sequence);
  final String account;
  final int generation, sequence;
}

/// Local query comparisons only. A first successful observation establishes a
/// baseline; no polling, remote push registration or credentials are involved.
class AcademicChangesService extends ValueNotifier<List<AcademicChange>> {
  AcademicChangesService({DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const []);
  static final instance = AcademicChangesService();
  static const storageKey = SpKeys.academicChanges;
  final DateTime Function() _now;
  Future<void>? _tail;
  String _account = '';
  int _generation = 0, _sequence = 0;
  final _committed = <String, int>{};

  Future<T> _serialize<T>(Future<T> Function() action) async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    try {
      if (previous != null) await previous;
      return await action();
    } finally {
      if (identical(_tail, done.future)) _tail = null;
      done.complete();
    }
  }

  AcademicObservation begin(String account) {
    if (_account != account) {
      _account = account;
      _generation++;
      _committed.clear();
      value = const [];
    }
    return AcademicObservation(account, _generation, ++_sequence);
  }

  bool _current(AcademicObservation token) =>
      token.account.isNotEmpty &&
      token.account == _account &&
      token.generation == _generation;

  bool accepts(AcademicObservation token, String scope) =>
      _current(token) && token.sequence >= (_committed[scope] ?? 0);

  Future<Map<String, dynamic>> _read(String account) async {
    final raw = (await SharedPreferences.getInstance()).getString(storageKey);
    if (raw == null) return {'account': account};
    final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return data['account'] == account ? data : {'account': account};
  }

  List<AcademicChange> _history(Map<String, dynamic> data) =>
      (data['history'] as List? ?? [])
          .map(
            (row) =>
                AcademicChange.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
  Future<void> _write(Map<String, dynamic> data) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      storageKey,
      jsonEncode(data),
    );
    if (!saved) throw StateError('无法保存学业变化记录');
  }

  Future<void> load(String account) {
    final token = begin(account);
    return _serialize(() async {
      if (!_current(token)) return;
      final data = await _read(account);
      if (_current(token)) value = List.unmodifiable(_history(data));
    });
  }

  Future<void> clear() {
    _generation++;
    _account = '';
    _committed.clear();
    value = const [];
    return _serialize(() async {
      await (await SharedPreferences.getInstance()).remove(storageKey);
    });
  }

  Future<void> markRead({String? id}) {
    final token = AcademicObservation(_account, _generation, _sequence);
    return _serialize(() async {
      if (!_current(token)) return;
      final data = await _read(token.account);
      if (!_current(token)) return;
      final history = _history(data)
          .map((item) => id == null || item.id == id ? item.markRead() : item)
          .toList();
      data['history'] = history.map((e) => e.toJson()).toList();
      await _write(data);
      if (_current(token)) value = List.unmodifiable(history);
    });
  }

  static bool _hasScore(String value) =>
      value.trim().isNotEmpty &&
      !const {
        '成绩尚未录入',
        '成绩只录一遍',
        '尚未录入',
        '未录入',
        '未出分',
        '--',
        '—',
      }.contains(value.trim());

  Future<void> observeMarks(AcademicObservation token, List<Mark> marks) {
    final grouped = <String, Map<String, String>>{};
    for (final mark in marks) {
      final key = jsonEncode([
        mark.semester,
        mark.name,
        mark.teacher,
        mark.type,
        mark.examType,
        mark.electiveType,
      ]);
      final score = mark.score.trim();
      final previous = grouped[key];
      // Identical duplicate rows are harmless; conflicting rows are unknown.
      final conflicting =
          previous != null &&
          (previous['value'] != score || previous['unknown'] == 'true');
      grouped[key] = {
        'course': mark.name,
        'term': mark.semester,
        'value': conflicting ? '' : score,
        if (conflicting) 'unknown': 'true',
      };
    }
    return _observe(token, 'marks', grouped, exams: false);
  }

  Future<void> observeExams(
    AcademicObservation token,
    String term,
    List<ExamRoomInfo> exams,
  ) {
    final grouped = <String, Map<String, String>>{};
    for (final exam in exams) {
      final key = jsonEncode([exam.courseName, exam.teacher, exam.credit]);
      final parsed = exam.startTime != null && exam.endTime != null;
      final raw = exam.rawExamTime.replaceAll(RegExp(r'\s+'), ' ').trim();
      final next = <String, String>{
        'course': exam.courseName,
        'term': term,
        'value': parsed
            ? '${exam.date} ${exam.time} ${exam.location}'.trim()
            : '',
        if (!parsed && raw.isNotEmpty) 'unknown': 'true',
      };
      final existing = grouped[key];
      if (existing != null &&
          (existing['value'] != next['value'] ||
              existing['unknown'] == 'true')) {
        next['unknown'] = 'true';
      }
      grouped[key] = next;
    }
    return _observe(token, 'exams:$term', grouped, exams: true);
  }

  Future<void> _observe(
    AcademicObservation token,
    String scope,
    Map<String, Map<String, String>> current, {
    required bool exams,
  }) => _serialize(() async {
    if (!_current(token) || token.sequence < (_committed[scope] ?? 0)) return;
    final data = await _read(token.account);
    if (!_current(token)) return;
    final previous = data[scope] as Map?;
    if (!exams && previous != null) {
      for (final entry in previous.entries) {
        current.putIfAbsent(
          entry.key as String,
          () => Map<String, String>.from(entry.value as Map),
        );
      }
    }
    final changes = <AcademicChange>[];
    for (final key in {
      ...current.keys,
      if (exams && previous != null) ...previous.keys.cast<String>(),
    }) {
      final old = previous?[key] as Map?;
      final next = current[key];
      if (next?['unknown'] == 'true') {
        if (old != null) current[key] = Map<String, String>.from(old);
        continue;
      }
      final before = old?['value'] as String? ?? '';
      final after = next?['value'] ?? '';
      if (!exams && _hasScore(before) && !_hasScore(after)) {
        current[key] = Map<String, String>.from(old!);
        continue;
      }
      if (previous == null || before == after) continue;
      AcademicChangeType type;
      if (exams) {
        type = before.isEmpty
            ? AcademicChangeType.examAdded
            : after.isEmpty
            ? AcademicChangeType.examRemoved
            : AcademicChangeType.examChanged;
      } else {
        if (!_hasScore(after)) continue;
        type = _hasScore(before)
            ? AcademicChangeType.gradeChanged
            : AcademicChangeType.gradeAdded;
      }
      final at = _now().toUtc();
      changes.add(
        AcademicChange(
          id: sha256
              .convert(
                utf8.encode(
                  jsonEncode([
                    scope,
                    key,
                    before,
                    after,
                    at.microsecondsSinceEpoch,
                    token.sequence,
                  ]),
                ),
              )
              .toString(),
          type: type,
          course: (next?['course'] ?? old?['course']) as String,
          term: (next?['term'] ?? old?['term']) as String,
          before: before,
          after: after,
          detectedAt: at,
        ),
      );
    }
    changes.sort((a, b) => a.course.compareTo(b.course));
    final history = [...changes, ..._history(data)].take(100).toList();
    data[scope] = current;
    data['history'] = history.map((e) => e.toJson()).toList();
    if (!_current(token)) return;
    await _write(data);
    if (_current(token)) {
      _committed[scope] = token.sequence;
      value = List.unmodifiable(history);
    }
  });
}
