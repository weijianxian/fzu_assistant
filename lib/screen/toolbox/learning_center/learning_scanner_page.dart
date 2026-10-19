import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/learning_center.dart';
import 'package:fzu_assistant/screen/toolbox/learning_center/learning_center_widgets.dart';
import 'package:fzu_assistant/service/api/learning_center_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class LearningScannerPage extends HookWidget {
  const LearningScannerPage({
    super.key,
    required this.appointmentId,
    this.token,
  });
  final String appointmentId;
  final String? token;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final busy = useState(false);
    final paused = useState(false);
    final supported =
        kIsWeb ||
        [
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        ].contains(defaultTargetPlatform);
    final controller = useMemoized(
      () => !supported
          ? null
          : MobileScannerController(
              formats: const [BarcodeFormat.qrCode],
              detectionSpeed: DetectionSpeed.normal,
            ),
      [supported],
    );
    useEffect(
      () => () {
        controller?.dispose();
      },
      [controller],
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.learningScanSignIn)),
      body: ToolPageWrapper(
        loading: false,
        emptyText: l10n.noData,
        onRefresh: () async {},
        slivers: [
          SliverFillRemaining(
            child: !supported
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l10n.learningScannerUnsupported),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: MobileScanner(
                          controller: controller,
                          errorBuilder: (context, error) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(l10n.learningCameraError),
                            ),
                          ),
                          onDetect: (capture) async {
                            if (busy.value || paused.value) return;
                            final raw = capture.barcodes
                                .map((b) => b.rawValue)
                                .whereType<String>()
                                .firstOrNull;
                            if (raw == null) return;
                            paused.value = true;
                            if (!validLearningQrCode(raw, DateTime.now())) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.learningInvalidQr)),
                              );
                              return;
                            }
                            busy.value = true;
                            try {
                              await LearningCenterService.instance.signIn(
                                appointmentId,
                                token: token,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.learningActionSucceeded),
                                  ),
                                );
                                Navigator.of(context).pop(true);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                await showLearningError(context, e);
                              }
                            } finally {
                              if (context.mounted) busy.value = false;
                            }
                          },
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(l10n.learningScanHint),
                              if (busy.value) const LinearProgressIndicator(),
                              if (paused.value && !busy.value)
                                TextButton(
                                  onPressed: () {
                                    paused.value = false;
                                  },
                                  child: Text(l10n.retry),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
