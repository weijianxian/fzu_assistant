/// 需要先完成教师评议才能访问目标页面。
class EvaluationRequiredException implements Exception {
  const EvaluationRequiredException();

  @override
  String toString() => '请先完成教师评议';
}

/// 检测响应是否被重定向到了评议拦截页面。
abstract final class EvaluationRequiredDetector {
  /// 教务处的措辞并不统一：jwch 实测是"请先对任课教师进行测评"，
  /// 线上还出现过带"和教材"的版本。用宽松匹配把两种都覆盖，
  /// 否则会漏判并把用户丢进一堆看不懂的解析错误里。
  static final _pattern = RegExp(r'请先对任课教师.*测评');

  static bool isRequired(String html) => _pattern.hasMatch(html);
}
