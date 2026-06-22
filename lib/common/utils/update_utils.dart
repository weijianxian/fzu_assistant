import 'package:fzu_assistant/model/github_release.dart';

class UpdateUtils {
  static const _abiAliases = <String, List<String>>{
    'arm64-v8a': ['arm64-v8a', 'arm64', 'aarch64'],
    'armeabi-v7a': ['armeabi-v7a', 'armeabi', 'armv7', 'arm32'],
    'x86_64': ['x86_64', 'x64', 'amd64'],
    'x86': ['x86', 'i686'],
  };

  static const _universalAliases = ['universal', 'all', 'noarch', 'multi'];

  UpdateUtils._();

  /// Returns negative if [a] < [b], 0 if equal, positive if [a] > [b].
  static int compareVersions(String a, String b) {
    final aParts = _versionParts(a);
    final bParts = _versionParts(b);
    for (var i = 0; i < 3; i++) {
      final ai = i < aParts.length ? aParts[i] : 0;
      final bi = i < bParts.length ? bParts[i] : 0;
      if (ai != bi) return ai - bi;
    }
    return 0;
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

    for (final asset in apkAssets) {
      if (_containsAnyToken(asset.name, _universalAliases)) {
        return asset;
      }
    }

    return apkAssets.length == 1 ? apkAssets.single : null;
  }

  static String safeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  static List<int> _versionParts(String version) {
    final clean = version
        .trim()
        .replaceFirst(RegExp(r'^v', caseSensitive: false), '')
        .split(RegExp(r'[-+]'))
        .first;
    return clean.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  }

  static bool _containsAnyToken(String value, List<String> tokens) {
    final lowerValue = value.toLowerCase();
    return tokens.any((token) => _containsToken(lowerValue, token));
  }

  static bool _containsToken(String value, String token) {
    final escaped = RegExp.escape(token.toLowerCase());
    return RegExp('(^|[^a-z0-9_])$escaped([^a-z0-9_]|\$)').hasMatch(value);
  }
}
