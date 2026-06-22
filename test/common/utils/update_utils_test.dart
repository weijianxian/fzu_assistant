import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/utils/update_utils.dart';
import 'package:fzu_assistant/model/github_release.dart';

void main() {
  group('UpdateUtils.compareVersions', () {
    test('compares semantic versions', () {
      expect(UpdateUtils.compareVersions('1.2.4', '1.2.3'), greaterThan(0));
      expect(UpdateUtils.compareVersions('1.2.3', '1.3.0'), lessThan(0));
      expect(UpdateUtils.compareVersions('1.2', '1.2.0'), 0);
    });

    test('ignores v prefix and build metadata', () {
      expect(UpdateUtils.compareVersions('v1.2.3+68', '1.2.3'), 0);
      expect(
        UpdateUtils.compareVersions('1.2.3-beta', '1.2.2'),
        greaterThan(0),
      );
    });
  });

  group('UpdateUtils.pickAndroidAsset', () {
    test('picks the first matching supported abi asset', () {
      final assets = [
        _asset('fzu_assistant-x86_64.apk'),
        _asset('fzu_assistant-arm64-v8a.apk'),
        _asset('fzu_assistant-universal.apk'),
      ];

      expect(
        UpdateUtils.pickAndroidAsset(assets, ['arm64-v8a'])?.name,
        'fzu_assistant-arm64-v8a.apk',
      );
    });

    test('uses abi aliases', () {
      final assets = [
        _asset('fzu_assistant-aarch64.apk'),
        _asset('fzu_assistant-universal.apk'),
      ];

      expect(
        UpdateUtils.pickAndroidAsset(assets, ['arm64-v8a'])?.name,
        'fzu_assistant-aarch64.apk',
      );
    });

    test('does not match x86 inside x86_64', () {
      final assets = [
        _asset('fzu_assistant-x86_64.apk'),
        _asset('fzu_assistant-x86.apk'),
      ];

      expect(
        UpdateUtils.pickAndroidAsset(assets, ['x86'])?.name,
        'fzu_assistant-x86.apk',
      );
    });

    test('falls back to universal or single apk', () {
      expect(
        UpdateUtils.pickAndroidAsset(
          [
            _asset('fzu_assistant-arm64-v8a.apk'),
            _asset('fzu_assistant-universal.apk'),
          ],
          ['mips'],
        )?.name,
        'fzu_assistant-universal.apk',
      );

      expect(
        UpdateUtils.pickAndroidAsset([_asset('fzu_assistant.apk')], [])?.name,
        'fzu_assistant.apk',
      );
    });

    test('ignores non apk and empty download url assets', () {
      expect(
        UpdateUtils.pickAndroidAsset(
          [
            _asset('fzu_assistant-arm64-v8a.zip'),
            _asset('fzu_assistant-arm64-v8a.apk', downloadUrl: ''),
          ],
          ['arm64-v8a'],
        ),
        isNull,
      );
    });
  });

  group('UpdateUtils.safeFileName', () {
    test('replaces filename characters invalid on Windows', () {
      expect(
        UpdateUtils.safeFileName(r'fzu/assistant:update*?.apk'),
        'fzu_assistant_update__.apk',
      );
    });
  });
}

GitHubReleaseAsset _asset(
  String name, {
  String downloadUrl = 'https://example.com/app.apk',
}) {
  return GitHubReleaseAsset(
    name: name,
    downloadUrl: downloadUrl,
    size: 1,
    contentType: 'application/vnd.android.package-archive',
  );
}
