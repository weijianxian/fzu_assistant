import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_mounted.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/evaluation.dart';
import 'package:fzu_assistant/service/api/academic_service.dart';

class EvaluationSubmitItem {
  final EvaluationTeacher teacher;
  final String score;
  final String comment;

  const EvaluationSubmitItem({
    required this.teacher,
    required this.score,
    required this.comment,
  });
}

void showEvaluationCaptchaDialog(
  BuildContext context,
  AcademicService service,
  List<EvaluationSubmitItem> items,
  VoidCallback onSuccess,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _CaptchaDialogContent(
      service: service,
      items: items,
      onSuccess: onSuccess,
    ),
  );
}

class _CaptchaDialogContent extends HookWidget {
  final AcademicService service;
  final List<EvaluationSubmitItem> items;
  final VoidCallback onSuccess;

  const _CaptchaDialogContent({
    required this.service,
    required this.items,
    required this.onSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final captchaImage = useState<Uint8List?>(null);
    final captchaInput = useState('');
    final submitting = useState(false);
    final submitError = useState<String?>(null);
    final currentIndex = useState(0);
    final showSuccess = useState(false);
    final mounted = useMounted();

    Future<void> refreshCaptcha() async {
      try {
        captchaImage.value = await service.getEvaluationCaptcha();
      } catch (_) {}
    }

    useEffect(() {
      refreshCaptcha();
      return null;
    }, []);

    Future<void> doSubmit() async {
      if (captchaInput.value.isEmpty) {
        submitError.value = l10n.evalCaptchaRequired;
        return;
      }
      submitting.value = true;
      submitError.value = null;

      try {
        for (var i = 0; i < items.length; i++) {
          currentIndex.value = i + 1;

          final ok = await service.submitEvaluation(
            items[i].teacher.params,
            items[i].score,
            items[i].comment,
            captchaInput.value,
          );

          if (!ok) {
            if (!mounted.value) return;
            submitError.value = l10n.evalCaptchaError;
            captchaInput.value = '';
            currentIndex.value = 0;
            await refreshCaptcha();
            submitting.value = false;
            return;
          }

          if (i < items.length - 1) {
            await Future.delayed(const Duration(milliseconds: 500));
            if (!mounted.value) return;
          }
        }

        if (!mounted.value || !context.mounted) return;
        showSuccess.value = true;
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted.value || !context.mounted) return;
        Navigator.of(context).pop();
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.evalSuccess)));
        onSuccess();
      } catch (e) {
        if (!mounted.value) return;
        submitError.value = l10n.evalSubmitFailed(e.toString());
      }
      if (mounted.value) {
        submitting.value = false;
        currentIndex.value = 0;
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 拖拽条
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 标题
          if (!submitting.value)
            Text(
              items.length == 1
                  ? '${items[0].teacher.courseName} · ${items[0].teacher.teacherName}'
                  : '${items.length} 位教师',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Text(
              l10n.evalFillCaptcha,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 16),

          // 验证码区域（提交时隐藏）
          if (!submitting.value) ...[
            if (captchaImage.value != null)
              GestureDetector(
                onTap: refreshCaptcha,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(captchaImage.value!, fit: BoxFit.contain),
                ),
              ),
            Center(
              child: TextButton.icon(
                onPressed: refreshCaptcha,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(l10n.evalRefreshCaptcha),
              ),
            ),
            TextField(
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, letterSpacing: 8),
              decoration: InputDecoration(
                hintText: l10n.captcha,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (v) => captchaInput.value = v,
              onSubmitted: (_) => doSubmit(),
            ),
          ],

          // 提交动画区域
          if (submitting.value && !showSuccess.value) ...[
            // 当前提交的卡片（带左滑动画）
            _AnimatedTeacherCard(
              key: ValueKey(currentIndex.value),
              teacher: items[currentIndex.value - 1].teacher,
              score: items[currentIndex.value - 1].score,
            ),
            const SizedBox(height: 12),
            // 进度条
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: currentIndex.value / items.length,
                      minHeight: 8,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${currentIndex.value}/${items.length}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          // 成功动画
          if (showSuccess.value) ...[
            const SizedBox(height: 32),
            const SuccessCheckmark(),
            const SizedBox(height: 16),
            Text(
              l10n.evalSuccess,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),
          ],

          // 错误提示
          if (submitError.value != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                submitError.value!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ),
          const SizedBox(height: 16),

          // 提交按钮
          FilledButton(
            onPressed: submitting.value ? null : doSubmit,
            child: submitting.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.evalSubmit),
          ),
        ],
      ),
    );
  }
}

/// 带左滑进入动画的教师卡片
class _AnimatedTeacherCard extends StatefulWidget {
  final EvaluationTeacher teacher;
  final String score;

  const _AnimatedTeacherCard({
    super.key,
    required this.teacher,
    required this.score,
  });

  @override
  State<_AnimatedTeacherCard> createState() => _AnimatedTeacherCardState();
}

class _AnimatedTeacherCardState extends State<_AnimatedTeacherCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SlideTransition(
      position: _slideAnimation,
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  widget.teacher.teacherName.isNotEmpty
                      ? widget.teacher.teacherName[0]
                      : '?',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.teacher.courseName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.teacher.teacherName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.score,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
