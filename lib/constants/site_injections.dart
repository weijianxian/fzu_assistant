class SiteInjection {
  final String pattern;
  final String? css;
  final String? js;

  const SiteInjection({required this.pattern, this.css, this.js});
}

const kSiteInjections = <SiteInjection>[
  SiteInjection(
    pattern: r'https://example\.com/',
    css: '#inject-success { color: green; font-size: 20px; }',
    js: 'var content =  document.getElementsByTagName("body")[0].childNodes[0];content.innerHTML = content.innerHTML + "<p id=\'inject-success\'>注入成功</p>"',
  ),
];
