import 'package:html/dom.dart';

/// 仅保留中文和数字。
String chineseOnly(String s) {
  return s.replaceAll(RegExp(r'[^一-龥0-9]'), '');
}

/// 从子元素 [tag] 中提取文本，找不到则返回整个元素的文本。
String extractText(Element el, String tag) {
  final child = el.querySelector(tag);
  return child != null ? child.text.trim() : el.text.trim();
}
