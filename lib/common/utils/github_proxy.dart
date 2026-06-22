import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GitHubProxy {
  static const defaultBaseUrl = 'https://gh-proxy.org/';

  GitHubProxy._();

  static Future<String> proxiedUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !_isGitHubUri(uri)) {
      return url;
    }

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(SpKeys.githubProxyEnabled) ?? true;
    if (!enabled) {
      return url;
    }

    final baseUrl = normalizeBaseUrl(
      prefs.getString(SpKeys.githubProxyBaseUrl) ?? defaultBaseUrl,
    );
    return '$baseUrl$url';
  }

  static String normalizeBaseUrl(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) return defaultBaseUrl;
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    if (!normalized.endsWith('/')) {
      normalized = '$normalized/';
    }
    return normalized;
  }

  static bool _isGitHubUri(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'api.github.com') return false;

    return host == 'github.com' ||
        host.endsWith('.github.com') ||
        host == 'githubusercontent.com' ||
        host.endsWith('.githubusercontent.com');
  }
}
