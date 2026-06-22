import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widget/update_dialog.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
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
      final resp = await Dio().get<List<dynamic>>(
        'https://api.github.com/repos/weijianxian/fzu_assistant/contributors',
      );
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
        respectPermanentlySkipped: silent,
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
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.about)),
      body: ListView(
        children: [
          const SizedBox(height: 32),
          Center(
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
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          const SizedBox(height: 24),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocalizations.of(context)!.appDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
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
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
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
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              AppLocalizations.of(context)!.contributors,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _contributors.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : Column(
                    children: _contributors
                        .map(
                          (c) => ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundImage: NetworkImage(c.avatar),
                            ),
                            title: Text(c.name),
                            subtitle: Text(
                              AppLocalizations.of(
                                context,
                              )!.commitCount(c.contributions),
                            ),
                            onTap: () => launchUrl(
                              Uri.parse('https://github.com/${c.name}'),
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                        )
                        .toList(),
                  ),
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
