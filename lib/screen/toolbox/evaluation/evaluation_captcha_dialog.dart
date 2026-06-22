import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_mounted.dart';
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
    final captchaImage = useState<Uint8List?>(null);
    final captchaInput = useState('');
    final submitting = useState(false);
    final submitError = useState<String?>(null);
    final currentIndex = useState(0);
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
            // 验证码错误，停止提交
            if (!mounted.value) return;
            submitError.value = l10n.evalCaptchaError;
            captchaInput.value = '';
            currentIndex.value = 0;
            await refreshCaptcha();
            submitting.value = false;
            return;
          }

          // 提交间隔，避免服务端处理不过来
          if (i < items.length - 1) {
            await Future.delayed(const Duration(milliseconds: 500));
            if (!mounted.value) return;
          }
        }

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
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (items.length == 1)
            Text(
              '${items[0].teacher.courseName} · ${items[0].teacher.teacherName}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            )
          else
            Text(
              '${items.length} 位教师',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 16),
          Text(
            l10n.evalFillCaptcha,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (captchaImage.value != null)
            GestureDetector(
              onTap: refreshCaptcha,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(captchaImage.value!, fit: BoxFit.contain),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: refreshCaptcha,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l10n.evalRefreshCaptcha),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: l10n.captcha,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (v) => captchaInput.value = v,
            onSubmitted: (_) => doSubmit(),
          ),
          if (submitError.value != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                submitError.value!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ),
          if (submitting.value && items.length > 1) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: currentIndex.value / items.length,
                      minHeight: 8,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${currentIndex.value}/${items.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
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
