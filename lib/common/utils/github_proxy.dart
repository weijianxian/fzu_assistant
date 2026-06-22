import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GitHubProxy {
  static const defaultBaseUrl = 'https://gh-proxy.org/';

  GitHubProxy._();

  static Future<String> proxiedUrl(String url) async {
    if (!shouldProxyUrl(url)) {
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

  static bool shouldProxyUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    return isProxyableHost(uri.host);
  }

  static bool isProxyableHost(String host) {
    final normalizedHost = host.toLowerCase();
    if (normalizedHost == 'api.github.com') return false;

    return normalizedHost == 'github.com' ||
        normalizedHost.endsWith('.github.com') ||
        normalizedHost == 'githubusercontent.com' ||
        normalizedHost.endsWith('.githubusercontent.com');
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
}
