import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/common/utils/github_proxy.dart';
import 'package:fzu_assistant/common/utils/update_utils.dart';
import 'package:fzu_assistant/model/github_release.dart';

enum VersionCompareResult { outdated, upToDate, skipped, permanentlySkipped }

enum InstallApkResult { started, permissionRequired, failed }

class UpdateCheckResult {
  final VersionCompareResult status;
  final GitHubRelease? release;

  const UpdateCheckResult(this.status, [this.release]);
}

class UpdateService {
  static const _repo = 'weijianxian/fzu_assistant';
  static const _releasesUrl =
      'https://api.github.com/repos/$_repo/releases/latest';
  static const _platform = MethodChannel('com.weijx.fzu_assistant/update');

  final Dio _dio;

  UpdateService({Dio? dio}) : _dio = dio ?? Dio();

  Future<GitHubRelease?> fetchLatestRelease() async {
    try {
      final releasesUrl = await GitHubProxy.proxiedUrl(_releasesUrl);
      final resp = await _dio.get<Map<String, dynamic>>(
        releasesUrl,
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );
      if (resp.data == null) return null;
      return GitHubRelease.fromJson(resp.data!);
    } catch (_) {
      return null;
    }
  }

  Future<UpdateCheckResult> checkForUpdate({
    bool respectPermanentlySkipped = true,
  }) async {
    if (respectPermanentlySkipped && await isPermanentlySkipped()) {
      return const UpdateCheckResult(VersionCompareResult.permanentlySkipped);
    }

    final release = await fetchLatestRelease();
    if (release == null) {
      return const UpdateCheckResult(VersionCompareResult.upToDate);
    }

    try {
      final info = await PackageInfo.fromPlatform();
      final cmp = UpdateUtils.compareVersions(release.version, info.version);
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

  Future<bool> isPermanentlySkipped() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(SpKeys.skipUpdatesPermanently) ?? false;
  }

  Future<void> skipUpdatesPermanently() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SpKeys.skipUpdatesPermanently, true);
  }

  Future<void> clearPermanentSkip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SpKeys.skipUpdatesPermanently);
  }

  Future<List<String>> getSupportedAbis() async {
    if (!Platform.isAndroid) return const [];

    try {
      final abis = await _platform.invokeListMethod<String>('getSupportedAbis');
      return abis ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<GitHubReleaseAsset?> findAndroidAsset(GitHubRelease release) async {
    final abis = await getSupportedAbis();
    return UpdateUtils.pickAndroidAsset(release.assets, abis);
  }

  static GitHubReleaseAsset? pickAndroidAsset(
    List<GitHubReleaseAsset> assets,
    List<String> supportedAbis,
  ) {
    return UpdateUtils.pickAndroidAsset(assets, supportedAbis);
  }

  Future<bool> canInstallPackages() async {
    if (!Platform.isAndroid) return true;

    try {
      return await _platform.invokeMethod<bool>('canInstallPackages') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openInstallSettings() async {
    if (!Platform.isAndroid) return;
    await _platform.invokeMethod<void>('openInstallSettings');
  }

  Future<String> downloadReleaseAsset(
    GitHubReleaseAsset asset, {
    ProgressCallback? onReceiveProgress,
  }) async {
    if (asset.downloadUrl.isEmpty) {
      throw StateError('Release asset has no download URL.');
    }

    final dir = await getTemporaryDirectory();
    final fileName = UpdateUtils.safeFileName(
      asset.name.isEmpty ? 'fzu_assistant_update.apk' : asset.name,
    );
    final targetPath = '${dir.path}${Platform.pathSeparator}$fileName';
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    final downloadUrl = await GitHubProxy.proxiedUrl(asset.downloadUrl);
    await _dio.download(
      downloadUrl,
      targetPath,
      options: Options(
        followRedirects: true,
        responseType: ResponseType.bytes,
        headers: {'Accept': 'application/octet-stream'},
      ),
      onReceiveProgress: onReceiveProgress,
    );

    return targetPath;
  }

  Future<InstallApkResult> installApk(String apkPath) async {
    if (!Platform.isAndroid) return InstallApkResult.failed;

    try {
      final result = await _platform.invokeMethod<String>('installApk', {
        'path': apkPath,
      });
      switch (result) {
        case 'started':
          return InstallApkResult.started;
        case 'permissionRequired':
          return InstallApkResult.permissionRequired;
        default:
          return InstallApkResult.failed;
      }
    } catch (_) {
      return InstallApkResult.failed;
    }
  }
}
