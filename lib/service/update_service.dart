import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/model/github_release.dart';

enum VersionCompareResult { outdated, upToDate, skipped }

class UpdateCheckResult {
  final VersionCompareResult status;
  final GitHubRelease? release;

  const UpdateCheckResult(this.status, [this.release]);
}

class UpdateService {
  static const _repo = 'weijianxian/fzu_assistant';
  static const _releasesUrl =
      'https://api.github.com/repos/$_repo/releases/latest';

  Future<GitHubRelease?> fetchLatestRelease() async {
    try {
      final resp = await Dio().get<Map<String, dynamic>>(
        _releasesUrl,
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );
      if (resp.data == null) return null;
      return GitHubRelease.fromJson(resp.data!);
    } catch (_) {
      return null;
    }
  }

  Future<UpdateCheckResult> checkForUpdate() async {
    final release = await fetchLatestRelease();
    if (release == null) {
      return const UpdateCheckResult(VersionCompareResult.upToDate);
    }

    try {
      final info = await PackageInfo.fromPlatform();
      final cmp = _compareVersions(release.version, info.version);
      if (cmp <= 0) {
        return const UpdateCheckResult(VersionCompareResult.upToDate);
      }

      final prefs = await SharedPreferences.getInstance();
      final skipped = prefs.getString(SpKeys.skipUpdateVersion);
      if (skipped == release.version) {
        return UpdateCheckResult(VersionCompareResult.skipped, release);
      }

      return UpdateCheckResult(VersionCompareResult.outdated, release);
    } catch (_) {
      return const UpdateCheckResult(VersionCompareResult.upToDate);
    }
  }

  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SpKeys.skipUpdateVersion, version);
  }

  Future<void> clearSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SpKeys.skipUpdateVersion);
  }

  /// Returns negative if a < b, 0 if equal, positive if a > b.
  static int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final bParts = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final ai = i < aParts.length ? aParts[i] : 0;
      final bi = i < bParts.length ? bParts[i] : 0;
      if (ai != bi) return ai - bi;
    }
    return 0;
  }
}
