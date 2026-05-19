import 'package:html/dom.dart';

/// 仅保留中文和数字。
String chineseOnly(String s) {
  return s.replaceAll(RegExp(r'[^一-龥0-9]'), '');
}

/// 从子元素 [tag] 中提取文本，找不到则返回空串。
String extractText(Element el, String tag) {
  return el.querySelector(tag)?.text.trim() ?? '';
}
