class GitHubRelease {
  final String tagName;
  final String version;
  final String body;
  final String htmlUrl;
  final String publishedAt;
  final bool prerelease;
  final List<GitHubReleaseAsset> assets;

  const GitHubRelease({
    required this.tagName,
    required this.version,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.prerelease,
    required this.assets,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? '';
    final assetsJson = json['assets'] as List<dynamic>? ?? const [];
    return GitHubRelease(
      tagName: tagName,
      version: tagName.replaceFirst(RegExp(r'^v'), ''),
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      publishedAt: json['published_at'] as String? ?? '',
      prerelease: json['prerelease'] as bool? ?? false,
      assets: assetsJson
          .whereType<Map<String, dynamic>>()
          .map(GitHubReleaseAsset.fromJson)
          .toList(growable: false),
    );
  }
}

class GitHubReleaseAsset {
  final String name;
  final String downloadUrl;
  final int size;
  final String contentType;

  const GitHubReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
    required this.contentType,
  });

  factory GitHubReleaseAsset.fromJson(Map<String, dynamic> json) {
    return GitHubReleaseAsset(
      name: json['name'] as String? ?? '',
      downloadUrl: json['browser_download_url'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      contentType: json['content_type'] as String? ?? '',
    );
  }
}
