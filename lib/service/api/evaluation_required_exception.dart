/// 需要先完成教师评议才能访问目标页面。
class EvaluationRequiredException implements Exception {
  const EvaluationRequiredException();

  @override
  String toString() => '请先完成教师评议';
}
