import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/common/utils/github_proxy.dart';
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

  static const _abiAliases = <String, List<String>>{
    'arm64-v8a': ['arm64-v8a', 'arm64', 'aarch64'],
    'armeabi-v7a': ['armeabi-v7a', 'armeabi', 'armv7', 'arm32'],
    'x86_64': ['x86_64', 'x64', 'amd64'],
    'x86': ['x86', 'i686'],
  };

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
    return pickAndroidAsset(release.assets, abis);
  }

  static GitHubReleaseAsset? pickAndroidAsset(
    List<GitHubReleaseAsset> assets,
    List<String> supportedAbis,
  ) {
    final apkAssets = assets
        .where(
          (asset) =>
              asset.downloadUrl.isNotEmpty &&
              asset.name.toLowerCase().endsWith('.apk'),
        )
        .toList(growable: false);
    if (apkAssets.isEmpty) return null;

    for (final abi in supportedAbis.map((abi) => abi.toLowerCase())) {
      final aliases = _abiAliases[abi] ?? [abi];
      for (final asset in apkAssets) {
        if (_containsAnyToken(asset.name, aliases)) {
          return asset;
        }
      }
    }

    const universalAliases = ['universal', 'all', 'noarch', 'multi'];
    for (final asset in apkAssets) {
      if (_containsAnyToken(asset.name, universalAliases)) {
        return asset;
      }
    }

    return apkAssets.length == 1 ? apkAssets.single : null;
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
    final fileName = _safeFileName(
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

  static bool _containsAnyToken(String value, List<String> tokens) {
    final lowerValue = value.toLowerCase();
    return tokens.any((token) => _containsToken(lowerValue, token));
  }

  static bool _containsToken(String value, String token) {
    final escaped = RegExp.escape(token.toLowerCase());
    return RegExp('(^|[^a-z0-9])$escaped([^a-z0-9]|\$)').hasMatch(value);
  }

  static String _safeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}
