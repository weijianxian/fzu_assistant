import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widget/half_screen_sheet.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/github_release.dart';
import 'package:fzu_assistant/service/update_service.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showUpdateSheet(
  BuildContext context, {
  required GitHubRelease release,
  required VoidCallback onSkip,
  required VoidCallback onSkipForever,
}) {
  return showHalfScreenSheet(
    context,
    builder: (controller) => _UpdateSheetContent(
      controller: controller,
      release: release,
      onSkip: onSkip,
      onSkipForever: onSkipForever,
    ),
  );
}

class _UpdateSheetContent extends StatefulWidget {
  final ScrollController controller;
  final GitHubRelease release;
  final VoidCallback onSkip;
  final VoidCallback onSkipForever;

  const _UpdateSheetContent({
    required this.controller,
    required this.release,
    required this.onSkip,
    required this.onSkipForever,
  });

  @override
  State<_UpdateSheetContent> createState() => _UpdateSheetContentState();
}

class _UpdateSheetContentState extends State<_UpdateSheetContent> {
  final _updateService = UpdateService();
  bool _isDownloading = false;
  bool _openingInstaller = false;
  double? _downloadProgress;

  Future<void> _handleDownload() async {
    if (!Platform.isAndroid) {
      await _openReleasePage();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final canInstall = await _updateService.canInstallPackages();
      if (!mounted) return;
      if (!canInstall) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.updateInstallPermissionRequired)),
        );
        await _updateService.openInstallSettings();
        return;
      }

      final asset = await _updateService.findAndroidAsset(widget.release);
      if (!mounted) return;
      if (asset == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.updateNoCompatiblePackage)),
        );
        await _openReleasePage();
        return;
      }

      setState(() {
        _isDownloading = true;
        _openingInstaller = false;
        _downloadProgress = null;
      });

      final apkPath = await _updateService.downloadReleaseAsset(
        asset,
        onReceiveProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() {
            _downloadProgress = (received / total).clamp(0.0, 1.0).toDouble();
          });
        },
      );
      if (!mounted) return;

      setState(() {
        _openingInstaller = true;
        _downloadProgress = 1;
      });

      final installResult = await _updateService.installApk(apkPath);
      if (!mounted) return;

      switch (installResult) {
        case InstallApkResult.started:
          Navigator.of(context).pop();
          return;
        case InstallApkResult.permissionRequired:
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.updateInstallPermissionRequired)),
          );
          break;
        case InstallApkResult.failed:
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.updateInstallFailed)),
          );
          break;
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.updateDownloadFailed)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _openingInstaller = false;
          _downloadProgress = null;
        });
      }
    }
  }

  Future<void> _openReleasePage() async {
    await launchUrl(
      Uri.parse(widget.release.htmlUrl),
      mode: LaunchMode.externalApplication,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openMarkdownLink(String? href) async {
    if (href == null || href.isEmpty) return;

    final uri = Uri.tryParse(href);
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = _downloadProgress;

    return ListView(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Row(
          children: [
            Icon(Icons.system_update, color: colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.newVersionAvailable,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'v${widget.release.version}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          l10n.releaseNotes,
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: MarkdownBody(
            data: widget.release.body.isEmpty ? '-' : widget.release.body,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                .copyWith(
                  p: textTheme.bodyMedium?.copyWith(height: 1.6),
                  h1: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  h2: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  h3: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  code: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: colorScheme.outlineVariant,
                        width: 4,
                      ),
                    ),
                  ),
                ),
            onTapLink: (text, href, title) => _openMarkdownLink(href),
          ),
        ),
        if (_isDownloading) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(value: progress),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isDownloading ? null : _handleDownload,
          child: _isDownloading
              ? _DownloadButtonProgress(
                  progress: progress,
                  openingInstaller: _openingInstaller,
                )
              : Text(
                  Platform.isAndroid ? l10n.installUpdate : l10n.downloadUpdate,
                ),
        ),
        const SizedBox(height: 8),
        OverflowBar(
          alignment: MainAxisAlignment.end,
          overflowAlignment: OverflowBarAlignment.end,
          spacing: 4,
          overflowSpacing: 4,
          children: [
            TextButton(
              onPressed: _isDownloading
                  ? null
                  : () {
                      widget.onSkip();
                      Navigator.of(context).pop();
                    },
              child: Text(l10n.skipThisVersion),
            ),
            TextButton(
              onPressed: _isDownloading
                  ? null
                  : () {
                      widget.onSkipForever();
                      Navigator.of(context).pop();
                    },
              child: Text(l10n.skipUpdatesPermanently),
            ),
            TextButton.icon(
              onPressed: _isDownloading ? null : _openReleasePage,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l10n.openInBrowser),
            ),
          ],
        ),
      ],
    );
  }
}

class _DownloadButtonProgress extends StatelessWidget {
  final double? progress;
  final bool openingInstaller;

  const _DownloadButtonProgress({
    required this.progress,
    required this.openingInstaller,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progressLabel = openingInstaller
        ? l10n.updateOpeningInstaller
        : progress == null
        ? ''
        : '${(progress! * 100).round()}%';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        if (progressLabel.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(child: Text(progressLabel, overflow: TextOverflow.ellipsis)),
        ],
      ],
    );
  }
}
