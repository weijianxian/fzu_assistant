import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/utils/github_proxy.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GitHubProxy.normalizeBaseUrl', () {
    test('uses default when empty', () {
      expect(GitHubProxy.normalizeBaseUrl(''), GitHubProxy.defaultBaseUrl);
      expect(GitHubProxy.normalizeBaseUrl('  '), GitHubProxy.defaultBaseUrl);
    });

    test('adds https scheme and trailing slash', () {
      expect(
        GitHubProxy.normalizeBaseUrl('gh-proxy.org'),
        'https://gh-proxy.org/',
      );
      expect(
        GitHubProxy.normalizeBaseUrl('https://proxy.example/path'),
        'https://proxy.example/path/',
      );
    });

    test('preserves existing scheme', () {
      expect(
        GitHubProxy.normalizeBaseUrl('http://localhost:8080/'),
        'http://localhost:8080/',
      );
    });
  });

  group('GitHubProxy.shouldProxyUrl', () {
    test('proxies GitHub and GitHubusercontent http urls', () {
      expect(
        GitHubProxy.shouldProxyUrl(
          'https://github.com/weijianxian/fzu_assistant/releases',
        ),
        isTrue,
      );
      expect(
        GitHubProxy.shouldProxyUrl(
          'https://objects.githubusercontent.com/github-production-release-asset',
        ),
        isTrue,
      );
    });

    test('does not proxy GitHub API urls', () {
      expect(
        GitHubProxy.shouldProxyUrl(
          'https://api.github.com/repos/weijianxian/fzu_assistant/contributors',
        ),
        isFalse,
      );
    });

    test('does not proxy non http GitHub or non GitHub urls', () {
      expect(GitHubProxy.shouldProxyUrl('ftp://github.com/repo/file'), isFalse);
      expect(GitHubProxy.shouldProxyUrl('https://example.com/github'), isFalse);
      expect(GitHubProxy.shouldProxyUrl('not a url'), isFalse);
    });
  });

  group('GitHubProxy.proxiedUrl', () {
    test('uses default proxy when enabled by default', () async {
      SharedPreferences.setMockInitialValues({});

      const url = 'https://github.com/weijianxian/fzu_assistant/releases';

      expect(
        await GitHubProxy.proxiedUrl(url),
        '${GitHubProxy.defaultBaseUrl}$url',
      );
    });

    test('uses normalized custom proxy base url', () async {
      SharedPreferences.setMockInitialValues({
        SpKeys.githubProxyEnabled: true,
        SpKeys.githubProxyBaseUrl: 'proxy.example',
      });

      const url = 'https://github.com/weijianxian/fzu_assistant/releases';

      expect(await GitHubProxy.proxiedUrl(url), 'https://proxy.example/$url');
    });

    test('returns original url when disabled or not proxyable', () async {
      SharedPreferences.setMockInitialValues({
        SpKeys.githubProxyEnabled: false,
        SpKeys.githubProxyBaseUrl: 'proxy.example',
      });

      const githubUrl = 'https://github.com/weijianxian/fzu_assistant/releases';
      const apiUrl =
          'https://api.github.com/repos/weijianxian/fzu_assistant/contributors';

      expect(await GitHubProxy.proxiedUrl(githubUrl), githubUrl);
      expect(await GitHubProxy.proxiedUrl(apiUrl), apiUrl);
      expect(
        await GitHubProxy.proxiedUrl('https://example.com'),
        'https://example.com',
      );
    });
  });
}
