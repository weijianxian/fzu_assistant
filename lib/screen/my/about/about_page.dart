import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/screen/my/about/widgets/update_dialog.dart';
import 'package:fzu_assistant/common/utils/github_proxy.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';
  String _buildNumber = '';
  List<_Contributor> _contributors = [];
  bool _isChecking = false;
  int _iconTapCount = 0;

  final _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    _loadInfo();
    _loadContributors();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate(silent: true);
    });
  }

  Future<void> _loadInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  Future<void> _loadContributors() async {
    try {
      final contributorsUrl = await GitHubProxy.proxiedUrl(
        'https://api.github.com/repos/weijianxian/fzu_assistant/contributors',
      );
      final resp = await Dio().get<List<dynamic>>(contributorsUrl);
      setState(() {
        _contributors = (resp.data ?? [])
            .map(
              (e) => _Contributor(
                name: e['login'] ?? '',
                avatar: e['avatar_url'] ?? '',
                contributions: e['contributions'] ?? 0,
              ),
            )
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _checkForUpdate({bool silent = false}) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      final result = await _updateService.checkForUpdate(
        respectSkippedUpdates: silent,
      );
      if (!mounted) return;

      switch (result.status) {
        case VersionCompareResult.outdated:
          showUpdateSheet(
            context,
            release: result.release!,
            onSkip: () => _updateService.skipVersion(result.release!.version),
            onSkipForever: _updateService.skipUpdatesPermanently,
          );
          break;
        case VersionCompareResult.upToDate:
          if (!silent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.alreadyLatest),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          break;
        case VersionCompareResult.skipped:
          // User already skipped this version, do nothing
          break;
        case VersionCompareResult.permanentlySkipped:
          break;
      }
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.updateCheckFailed),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.about)),
      body: AppListView(
        children: [
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onTap: () {
                _iconTapCount++;
                if (_iconTapCount == 7) {
                  _iconTapCount = 0;
                  context.pushNamed(AppRoutes.dev);
                }
              },
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.school,
                  size: 40,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'FZU Assistant',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (_version.isNotEmpty)
            Center(
              child: Text(
                'v$_version ($_buildNumber)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 24),
          AppInfoCard(
            title: Text(AppLocalizations.of(context)!.appDescription),
          ),
          AppSection.list(
            children: [
              ListTile(
                leading: const Icon(Icons.code),
                title: Text(AppLocalizations.of(context)!.openSourceUrl),
                subtitle: const Text('github.com/weijianxian/fzu_assistant'),
                trailing: const Icon(Icons.open_in_new, size: 20),
                onTap: () => launchUrl(
                  Uri.parse('https://github.com/weijianxian/fzu_assistant'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.system_update),
                title: Text(AppLocalizations.of(context)!.checkForUpdates),
                trailing: _isChecking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _isChecking ? null : () => _checkForUpdate(),
              ),
            ],
          ),
          AppSection.list(
            title: AppLocalizations.of(context)!.contributors,
            children: [
              if (_contributors.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                for (final c in _contributors)
                  ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(c.avatar),
                    ),
                    title: Text(c.name),
                    subtitle: Text(
                      AppLocalizations.of(context)!
                          .commitCount(c.contributions),
                    ),
                    onTap: () => launchUrl(
                      Uri.parse('https://github.com/${c.name}'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Contributor {
  final String name;
  final String avatar;
  final int contributions;

  const _Contributor({
    required this.name,
    required this.avatar,
    required this.contributions,
  });
}
