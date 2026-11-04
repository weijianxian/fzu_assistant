import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/screen/toolbox/paper/paper_file_actions.dart';
import 'package:fzu_assistant/service/paper_download_service.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum _DownloadStage {
  preparing,
  ready,
  downloading,
  completed,
  cancelled,
  failed,
}

/// Content for the shared, scrollable app bottom sheet.
class PaperDownloadSheet extends HookWidget {
  const PaperDownloadSheet({
    super.key,
    required this.path,
    required this.name,
    required this.service,
    required this.access,
  });

  final String path;
  final String name;
  final PaperDownloadService service;
  final ValueListenable<FeatureAccess> access;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stage = useState(_DownloadStage.preparing);
    final progress = useState(const PaperDownloadProgress(received: 0));
    final downloaded = useState<PaperDownloadedFile?>(null);
    final failure = useState<PaperDownloadFailure?>(null);
    final actionError = useState<String?>(null);
    final actionBusy = useState(false);
    final revoked = useState(false);
    final invalidated = useRef(false);
    final alive = useRef(true);
    final sequence = useRef(0);
    final token = useRef<CancelToken?>(null);
    final shareKey = useMemoized(() => GlobalKey());

    bool usable() =>
        alive.value &&
        context.mounted &&
        !invalidated.value &&
        !revoked.value &&
        !service.isClosed &&
        access.value == FeatureAccess.allow;

    useEffect(() {
      alive.value = true;
      void checkAccess() {
        if (access.value == FeatureAccess.allow && !service.isClosed) return;
        if (invalidated.value) return;
        // A later allow must not revive an already invalidated sheet.
        invalidated.value = true;
        sequence.value++;
        token.value?.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && alive.value) {
            revoked.value = true;
            if (ModalRoute.of(context)?.isCurrent == true) {
              Navigator.of(context).pop();
            }
          }
        });
      }

      access.addListener(checkAccess);
      service.addListener(checkAccess);
      final initialToken = CancelToken();
      token.value = initialToken;
      final initialSequence = ++sequence.value;
      () async {
        try {
          await service.resolveUrl(path, cancelToken: initialToken);
          if (usable() && sequence.value == initialSequence) {
            stage.value = _DownloadStage.ready;
          }
        } catch (error) {
          if (usable() && sequence.value == initialSequence) {
            failure.value = _failure(error);
            stage.value = _DownloadStage.failed;
          }
        } finally {
          if (identical(token.value, initialToken)) token.value = null;
        }
      }();
      return () {
        alive.value = false;
        sequence.value++;
        token.value?.cancel();
        access.removeListener(checkAccess);
        service.removeListener(checkAccess);
      };
    }, [service, access, path]);

    Future<void> startDownload() async {
      if (!usable() ||
          stage.value == _DownloadStage.downloading ||
          actionBusy.value) {
        return;
      }
      final downloadToken = CancelToken();
      token.value = downloadToken;
      final currentSequence = ++sequence.value;
      stage.value = _DownloadStage.downloading;
      failure.value = null;
      actionError.value = null;
      progress.value = const PaperDownloadProgress(received: 0);
      try {
        final result = await service.download(
          path: path,
          name: name,
          cancelToken: downloadToken,
          onProgress: (next) {
            if (usable() && sequence.value == currentSequence) {
              progress.value = next;
            }
          },
        );
        if (!usable() || sequence.value != currentSequence) return;
        downloaded.value = result;
        stage.value = _DownloadStage.completed;
      } catch (error) {
        if (!usable() || sequence.value != currentSequence) return;
        failure.value = _failure(error);
        stage.value = failure.value == PaperDownloadFailure.cancelled
            ? _DownloadStage.cancelled
            : _DownloadStage.failed;
      } finally {
        if (identical(token.value, downloadToken)) token.value = null;
      }
    }

    Future<void> localAction(
      Future<bool> Function(PaperDownloadedFile file) action,
      String errorText,
    ) async {
      final result = downloaded.value;
      if (!usable() || actionBusy.value || result == null) return;
      actionBusy.value = true;
      actionError.value = null;
      try {
        if (!await result.file.exists() || !usable()) {
          if (usable()) {
            downloaded.value = null;
            failure.value = PaperDownloadFailure.incomplete;
            stage.value = _DownloadStage.failed;
          }
          return;
        }
        final success = await action(result);
        if (!success && usable()) actionError.value = errorText;
      } catch (_) {
        if (usable()) actionError.value = errorText;
      } finally {
        if (usable()) actionBusy.value = false;
      }
    }

    Future<void> remoteAction({required bool copy}) async {
      if (!usable() ||
          actionBusy.value ||
          stage.value == _DownloadStage.downloading) {
        return;
      }
      actionBusy.value = true;
      actionError.value = null;
      final actionToken = CancelToken();
      token.value = actionToken;
      try {
        final uri = await service.resolveUrl(path, cancelToken: actionToken);
        if (!usable()) return;
        if (copy) {
          await Clipboard.setData(ClipboardData(text: uri.toString()));
          if (context.mounted && usable()) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l10n.copied)));
          }
        } else {
          final opened = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!opened && usable()) actionError.value = l10n.papersOpenFailed;
        }
      } catch (_) {
        if (usable()) actionError.value = l10n.papersOpenFailed;
      } finally {
        if (identical(token.value, actionToken)) token.value = null;
        if (usable()) actionBusy.value = false;
      }
    }

    if (revoked.value ||
        invalidated.value ||
        service.isClosed ||
        access.value != FeatureAccess.allow) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.thirdPartyDisabled),
      );
    }

    final locale = Localizations.localeOf(context).toLanguageTag();
    String bytes(int value) {
      final units = [
        l10n.papersByteUnit,
        l10n.papersKibibyteUnit,
        l10n.papersMebibyteUnit,
        l10n.papersGibibyteUnit,
      ];
      var size = value.toDouble();
      var unit = 0;
      while (size >= 1024 && unit < units.length - 1) {
        size /= 1024;
        unit++;
      }
      return '${NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: unit == 0 ? 0 : 1).format(size)} ${units[unit]}';
    }

    final busy =
        stage.value == _DownloadStage.downloading ||
        stage.value == _DownloadStage.preparing;
    final status = switch (stage.value) {
      _DownloadStage.preparing => l10n.papersDownloadPreparing,
      _DownloadStage.ready => null,
      _DownloadStage.downloading => l10n.papersDownloading,
      _DownloadStage.completed => l10n.papersDownloadComplete,
      _DownloadStage.cancelled => l10n.papersDownloadCancelled,
      _DownloadStage.failed => _errorText(l10n, failure.value),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(l10n.papersDownloadDescription),
          if (status != null) ...[
            const SizedBox(height: 24),
            Text(
              status,
              style: TextStyle(
                color: stage.value == _DownloadStage.failed
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ],
          if (busy) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: stage.value == _DownloadStage.downloading
                  ? progress.value.fraction
                  : null,
            ),
          ],
          if (stage.value == _DownloadStage.downloading) ...[
            const SizedBox(height: 8),
            Text(
              progress.value.fraction == null
                  ? l10n.papersDownloadBytes(bytes(progress.value.received))
                  : l10n.papersDownloadProgress(
                      bytes(progress.value.received),
                      bytes(progress.value.total!),
                      NumberFormat.percentPattern(locale)
                          .format(progress.value.fraction!),
                    ),
            ),
          ],
          if (downloaded.value != null) ...[
            const SizedBox(height: 8),
            Text(bytes(downloaded.value!.bytes)),
          ],
          if (actionError.value != null) ...[
            const SizedBox(height: 12),
            Text(
              actionError.value!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (actionBusy.value) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 20),
          if (busy)
            OutlinedButton(
              onPressed: () {
                if (stage.value == _DownloadStage.preparing) {
                  Navigator.of(context).pop();
                } else {
                  token.value?.cancel();
                }
              },
              child: Text(l10n.learningCancel),
            )
          else if (downloaded.value != null) ...[
            FilledButton.icon(
              onPressed: actionBusy.value
                  ? null
                  : () => localAction(
                      (file) => openPaperFile(file.file.path),
                      l10n.papersLocalOpenFailed,
                    ),
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.papersOpenFile),
            ),
            if (!Platform.isLinux) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: shareKey,
                onPressed: actionBusy.value
                    ? null
                    : () => localAction((file) async {
                        if (!usable()) return false;
                        final box = shareKey.currentContext?.findRenderObject();
                        final size = MediaQuery.sizeOf(context);
                        final origin = box is RenderBox && box.hasSize
                            ? box.localToGlobal(Offset.zero) & box.size
                            : Rect.fromLTWH(
                                size.width / 2,
                                size.height / 2,
                                1,
                                1,
                              );
                        await SharePlus.instance.share(
                          ShareParams(
                            files: [XFile(file.file.path)],
                            title: file.name,
                            sharePositionOrigin: origin,
                          ),
                        );
                        return true;
                      }, l10n.papersShareFailed),
                icon: const Icon(Icons.share_outlined),
                label: Text(l10n.papersShareFile),
              ),
            ],
            if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: actionBusy.value
                    ? null
                    : () => localAction(
                        (file) => launchUrl(
                          Uri.directory(file.file.parent.path),
                          mode: LaunchMode.externalApplication,
                        ),
                        l10n.papersLocalOpenFailed,
                      ),
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(l10n.papersOpenFolder),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: actionBusy.value
                    ? null
                    : () => localAction((file) async {
                        await Clipboard.setData(
                          ClipboardData(text: file.file.path),
                        );
                        if (context.mounted && usable()) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(l10n.copied)));
                        }
                        return true;
                      }, l10n.papersLocalOpenFailed),
                icon: const Icon(Icons.copy_outlined),
                label: Text(l10n.papersCopyLocalPath),
              ),
            ],
          ] else
            FilledButton.icon(
              onPressed: actionBusy.value ? null : startDownload,
              icon: const Icon(Icons.download_outlined),
              label: Text(
                stage.value == _DownloadStage.ready
                    ? l10n.papersDownloadLocal
                    : l10n.retry,
              ),
            ),
          if (!busy) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: actionBusy.value
                      ? null
                      : () => remoteAction(copy: true),
                  child: Text(l10n.copyLink),
                ),
                TextButton(
                  onPressed: actionBusy.value
                      ? null
                      : () => remoteAction(copy: false),
                  child: Text(l10n.openInBrowser),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

PaperDownloadFailure _failure(Object error) => error is PaperDownloadException
    ? error.failure
    : PaperDownloadFailure.failed;

String _errorText(AppLocalizations l10n, PaperDownloadFailure? failure) =>
    switch (failure) {
      PaperDownloadFailure.accessDenied => l10n.thirdPartyDisabled,
      PaperDownloadFailure.cancelled => l10n.papersDownloadCancelled,
      PaperDownloadFailure.invalidFile => l10n.papersDownloadInvalidFile,
      PaperDownloadFailure.incomplete => l10n.papersDownloadIncomplete,
      PaperDownloadFailure.cleanupFailed => l10n.papersDownloadCleanupFailed,
      _ => l10n.papersDownloadFailed,
    };
