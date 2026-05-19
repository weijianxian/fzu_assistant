class GitHubRelease {
  final String tagName;
  final String version;
  final String body;
  final String htmlUrl;
  final String publishedAt;
  final bool prerelease;

  const GitHubRelease({
    required this.tagName,
    required this.version,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.prerelease,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? '';
    return GitHubRelease(
      tagName: tagName,
      version: tagName.replaceFirst(RegExp(r'^v'), ''),
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      publishedAt: json['published_at'] as String? ?? '',
      prerelease: json['prerelease'] as bool? ?? false,
    );
  }
}
