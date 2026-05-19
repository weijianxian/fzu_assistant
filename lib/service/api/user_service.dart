import 'package:html/dom.dart';
import 'package:fzu_assistant/model/student_info.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/api/html_helper.dart';

class UserService {
  static const _userInfoUrl =
      'https://jwcjwxt2.fzu.edu.cn:81/jcxx/xsxx/StudentInformation.aspx';

  Future<StudentInfo> getUserInfo() async {
    final id = ApiClient.instance.userId;
    if (id == null) throw Exception('未登录');

    final doc = await HtmlHelper.fetchHtml(
      _userInfoUrl,
      queryParameters: {'id': id},
    );

    return StudentInfo(
      name: _extract(doc, 'ContentPlaceHolder1_LB_xm'),
      sex: _extract(doc, 'ContentPlaceHolder1_LB_xb'),
      birthday: _extract(doc, 'ContentPlaceHolder1_LB_csrq'),
      phone: _extract(doc, 'ContentPlaceHolder1_LB_lxdh'),
      email: _extract(doc, 'ContentPlaceHolder1_LB_email'),
      college: _extract(doc, 'ContentPlaceHolder1_LB_xymc'),
      grade: _extract(doc, 'ContentPlaceHolder1_LB_nj'),
      major: _extract(doc, 'ContentPlaceHolder1_LB_zymc'),
      counselor: _extract(doc, 'ContentPlaceHolder1_LB_zdy'),
      examineeCategory: _extract(doc, 'ContentPlaceHolder1_LB_kslb'),
      nationality: _extract(doc, 'ContentPlaceHolder1_LB_mz'),
      country: _extract(doc, 'ContentPlaceHolder1_LB_gb'),
      politicalStatus: _extract(doc, 'ContentPlaceHolder1_LB_zzmm'),
      source: _extract(doc, 'ContentPlaceHolder1_LB_xssy'),
      statusChanges: _extract(doc, 'ContentPlaceHolder1_LB_xjxx'),
    );
  }

  static String _extract(Document doc, String id) {
    return doc.getElementById(id)?.text.trim() ?? '';
  }
}
