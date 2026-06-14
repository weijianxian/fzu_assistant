import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_mounted.dart';
import 'package:fzu_assistant/common/widget/tool_page_wrapper.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/evaluation.dart';
import 'package:fzu_assistant/screen/toolbox/evaluation/evaluation_captcha_dialog.dart';
import 'package:fzu_assistant/screen/toolbox/evaluation/evaluation_teacher_card.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';

class EvaluationPage extends HookWidget {
  const EvaluationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tabController = useTabController(initialLength: 2);
    final service = useMemoized(() => AcademicService());
    final oneKeyTrigger = useState(0);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.evaluation),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: '一键填写',
            onPressed: () => oneKeyTrigger.value++,
          ),
        ],
        bottom: TabBar(
          controller: tabController,
          tabs: [
            Tab(text: l10n.evalTabXqxk),
            Tab(text: l10n.evalTabScore),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          _EvaluationTab(
            type: 'xqxk',
            service: service,
            oneKeyTrigger: oneKeyTrigger,
          ),
          _EvaluationTab(
            type: 'score',
            service: service,
            oneKeyTrigger: oneKeyTrigger,
          ),
        ],
      ),
    );
  }
}

class _EvaluationTab extends HookWidget {
  final String type;
  final AcademicService service;
  final ValueNotifier<int> oneKeyTrigger;

  const _EvaluationTab({
    required this.type,
    required this.service,
    required this.oneKeyTrigger,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final teachers = useState<List<EvaluationTeacher>>([]);
    final loading = useState(true);
    final error = useState<String?>(null);
    final refreshTime = useState<DateTime?>(null);
    final mounted = useMounted();

    final scores = useState<List<String>>([]);
    final selectedComments = useState<List<int?>>([]);
    final customComments = useState<List<String>>([]);

    Future<void> load() async {
      loading.value = true;
      error.value = null;
      try {
        final data = await service.getEvaluationTeachers(type);
        if (!mounted.value) return;
        teachers.value = data;
        scores.value = List.filled(data.length, '');
        selectedComments.value = List.filled(data.length, null);
        customComments.value = List.filled(data.length, '');
        refreshTime.value = DateTime.now();
        error.value = null;
      } catch (e) {
        if (!mounted.value) return;
        error.value = e.toString();
      }
      if (mounted.value) loading.value = false;
    }

    useEffect(() {
      load();
      return null;
    }, []);

    // 一键填写
    useEffect(() {
      if (oneKeyTrigger.value == 0) return null;
      if (teachers.value.isEmpty) return null;
      final rng = Random();
      scores.value = List.filled(teachers.value.length, '100');
      selectedComments.value = List.generate(
        teachers.value.length,
        (_) => rng.nextInt(defaultComments.length),
      );
      customComments.value = List.filled(teachers.value.length, '');
      return null;
    }, [oneKeyTrigger.value]);

    void submitSingle(int i) {
      final commentIdx = selectedComments.value[i];
      final comment = commentIdx == defaultComments.length
          ? customComments.value[i]
          : defaultComments[commentIdx!];
      showEvaluationCaptchaDialog(context, service, [
        EvaluationSubmitItem(
          teacher: teachers.value[i],
          score: scores.value[i],
          comment: comment,
        ),
      ], load);
    }

    Future<void> submitAll() async {
      final toSubmit = <EvaluationSubmitItem>[];
      for (var i = 0; i < teachers.value.length; i++) {
        if (scores.value[i].isEmpty) continue;
        final commentIdx = selectedComments.value[i];
        if (commentIdx == null) continue;
        if (commentIdx == defaultComments.length &&
            customComments.value[i].isEmpty) {
          continue;
        }
        final comment = commentIdx == defaultComments.length
            ? customComments.value[i]
            : defaultComments[commentIdx];
        toSubmit.add(
          EvaluationSubmitItem(
            teacher: teachers.value[i],
            score: scores.value[i],
            comment: comment,
          ),
        );
      }

      if (toSubmit.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.evalNoFilled)));
        return;
      }

      showEvaluationCaptchaDialog(context, service, toSubmit, load);
    }

    return Column(
      children: [
        Expanded(
          child: ToolPageWrapper(
            onRefresh: load,
            loading: loading.value,
            error: error.value,
            refreshTime: refreshTime.value,
            hasData: teachers.value.isNotEmpty,
            emptyText: l10n.noEvaluationData,
            child: teachers.value.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.noEvaluationData,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(l10n.evalNotAvailable),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    itemCount: teachers.value.length,
                    itemBuilder: (context, i) => EvaluationTeacherCard(
                      teacher: teachers.value[i],
                      score: scores.value[i],
                      selectedComment: selectedComments.value[i],
                      customComment: customComments.value[i],
                      onScoreChanged: (v) {
                        final newList = List<String>.from(scores.value);
                        newList[i] = v;
                        scores.value = newList;
                      },
                      onCommentChanged: (idx) {
                        final newList = List<int?>.from(selectedComments.value);
                        newList[i] = idx;
                        selectedComments.value = newList;
                      },
                      onCustomCommentChanged: (v) {
                        final newList = List<String>.from(customComments.value);
                        newList[i] = v;
                        customComments.value = newList;
                      },
                      onSubmit: () => submitSingle(i),
                    ),
                  ),
          ),
        ),
        if (teachers.value.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: FilledButton.icon(
                onPressed: submitAll,
                icon: const Icon(Icons.send),
                label: Text(l10n.evalSubmitAll),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
