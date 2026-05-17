class NoticeInfo {
  final String title; // 通知标题
  final String url; // 通知链接
  final String date; // 通知日期
  final String department; // 所属部门
  final String wbTreeId; // 部门ID
  final String wbNewsId; // 新闻ID

  const NoticeInfo({
    required this.title,
    required this.url,
    required this.date,
    required this.department,
    required this.wbTreeId,
    required this.wbNewsId,
  });
}
