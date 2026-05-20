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
  // 教学大纲页面移动端优化
  SiteInjection(
    pattern:
        r'https://jwcjwxt2\.fzu\.edu\.cn:\d+/pyfa/jxdg/TeachingProgram_view\.aspx',
    css: '''
      body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        font-size: 14px;
        line-height: 1.6;
        padding: 0 8px;
        word-break: break-word;
        -webkit-text-size-adjust: 100%;
      }

      /* 主表格自适应 */
      table[width="600px"] {
        width: 100% !important;
        table-layout: auto !important;
        border-collapse: collapse;
        margin: 0 auto;
      }

      /* 所有 td 优化间距 */
      table td {
        padding: 8px 10px;
        vertical-align: top;
        font-size: inherit;
        line-height: 1.5;
        word-break: break-word;
      }

      /* 标签列不换行 */
      table[width="600px"] > tbody > tr > td:first-child:not([colspan]) {
        white-space: nowrap;
        font-weight: 600;
      }

      /* 内嵌表格 */
      table table {
        width: 100% !important;
        margin: 4px 0;
      }
      table table td {
        padding: 6px 8px;
        font-size: inherit;
        border: 1px solid #ddd;
      }
      table table tr:first-child td {
        background: #e8e8e8;
        font-weight: 600;
        text-align: center;
      }

      /* 覆盖 font 标签固定字号 */
      font[size="4"] { font-size: 18px !important; }
      font[size="+1"] { font-size: 15px !important; }

      /* 竖屏放大 */
      @media (orientation: portrait) {
        body { font-size: 18px; }
        table td { padding: 10px 12px; }
        table table td { padding: 8px 10px; }
        font[size="4"] { font-size: 22px !important; }
        font[size="+1"] { font-size: 18px !important; }
      }
    ''',
  ),
  // 授课计划页面移动端优化
  SiteInjection(
    pattern:
        r'https://jwcjwxt2\.fzu\.edu\.cn:\d+/pyfa/skjh/TeachingPlan_view\.aspx',
    css: '''
      body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        font-size: 14px;
        line-height: 1.6;
        padding: 0 8px;
        word-break: break-word;
        -webkit-text-size-adjust: 100%;
      }

      /* 主表格自适应 */
      table[width="800"] {
        width: 100% !important;
        table-layout: auto !important;
        border-collapse: collapse;
        margin: 0 auto;
      }

      /* 所有 td */
      table td {
        padding: 8px 10px;
        vertical-align: top;
        font-size: inherit;
        line-height: 1.5;
        word-break: break-word;
      }

      /* 内嵌表格 */
      table table {
        width: 100% !important;
        margin: 4px 0;
      }
      table table td {
        padding: 6px 8px;
        font-size: inherit;
        border: 1px solid #ddd;
      }
      table table tr:first-child td {
        background: #e8e8e8;
        font-weight: 600;
        text-align: center;
      }

      /* 竖屏放大 */
      @media (orientation: portrait) {
        body { font-size: 18px; }
        table td { padding: 10px 12px; }
        table table td { padding: 8px 10px; }
      }
    ''',
  ),
];
