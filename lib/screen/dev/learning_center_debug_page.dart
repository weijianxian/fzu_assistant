import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:fzu_assistant/constants/breakpoints.dart';
import 'package:fzu_assistant/model/learning_center.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/api/learning_center_service.dart';
import 'package:fzu_assistant/service/api/sso_service.dart';

/// Mirrors fzuhelper-app's devtools/learning-center-api.tsx.
class LearningCenterDebugPage extends HookWidget {
  const LearningCenterDebugPage({super.key});
  @override
  Widget build(BuildContext context) {
    final token = useTextEditingController();
    final date = useTextEditingController(
      text: learningDate(
        learningBeijingTime(DateTime.now()).add(const Duration(days: 3)),
      ),
    );
    final begin = useTextEditingController(text: '08:00');
    final end = useTextEditingController(text: '10:00');
    final floor = useTextEditingController(text: '4');
    final seat = useTextEditingController();
    final appointmentId = useTextEditingController();
    final busy = useState(false);
    final result = useState('');
    final showToken = useState(false);
    final api = LearningCenterService.instance;

    Future<void> loadToken() async {
      try {
        final value = await SsoService.instance.loadStudyToken();
        if (context.mounted) token.text = value ?? '';
      } catch (e) {
        if (context.mounted) result.value = e.toString();
      }
    }

    useEffect(() {
      loadToken();
      return null;
    }, const []);

    Future<void> run(Future<Object?> Function() operation) async {
      if (busy.value) return;
      busy.value = true;
      try {
        final response = await operation();
        if (context.mounted) {
          result.value = const JsonEncoder.withIndent('  ').convert(response);
        }
      } catch (e) {
        if (context.mounted) result.value = e.toString();
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    Future<Object?> request(String path, Map<String, dynamic> data) async {
      final response = await api.dio.post<dynamic>(
        path,
        data: data,
        options: Options(
          contentType: Headers.jsonContentType,
          followRedirects: false,
          validateStatus: (_) => true,
          headers: {
            'token': token.text.trim(),
            'Referer': 'https://aiot.fzu.edu.cn/ibs/',
            'Origin': 'https://aiot.fzu.edu.cn',
            'User-Agent': SsoService.userAgent,
          },
        ),
      );
      return {'statusCode': response.statusCode, 'data': response.data};
    }

    Widget field(
      TextEditingController controller,
      String label, {
      bool secret = false,
      Widget? suffixIcon,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        enabled: !busy.value,
        obscureText: secret,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: suffixIcon,
        ),
      ),
    );
    Widget button(String label, Future<Object?> Function() action) =>
        OutlinedButton(
          onPressed: busy.value ? null : () => run(action),
          child: Text(label),
        );

    return Scaffold(
      appBar: AppBar(title: Text('学习中心 API 调试')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DebugButtonGroup(
            children: [
              OutlinedButton(
                onPressed: busy.value
                    ? null
                    : () => context.pushNamed(AppRoutes.learningCenter),
                child: Text('学习中心'),
              ),
              OutlinedButton(
                onPressed: busy.value
                    ? null
                    : () async {
                        await context.pushNamed(AppRoutes.ssoLogin);
                        if (context.mounted) await loadToken();
                      },
                child: Text('统一身份认证登录'),
              ),
            ],
          ),
          field(
            token,
            '学习中心 token',
            secret: !showToken.value,
            suffixIcon: IconButton(
              tooltip: showToken.value ? '隐藏 token' : '显示 token',
              icon: Icon(
                showToken.value ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: busy.value
                  ? null
                  : () => showToken.value = !showToken.value,
            ),
          ),
          _DebugButtonGroup(
            children: [
              button('保存 token', () async {
                await SsoService.instance.saveStudyToken(token.text.trim());
                return {'saved': true};
              }),
              button('读取 token', () async {
                await loadToken();
                return {'loaded': token.text.isNotEmpty};
              }),
              button('清除 token', () async {
                await SsoService.instance.clearStudyToken();
                token.clear();
                return {'cleared': true};
              }),
              button(
                '我的预约',
                () => request('/spaceAppoint/app/queryMyAppoint', {
                  'currentPage': '1',
                  'pageSize': '30',
                  'auditStatus': '',
                }),
              ),
            ],
          ),
          const Divider(),
          field(floor, '楼层'),
          field(date, '日期'),
          field(begin, '开始时间'),
          field(end, '结束时间'),
          field(seat, 'spaceId'),
          _DebugButtonGroup(
            children: [
              button(
                '查询座位',
                () => request('/spaceAppoint/app/queryStationStatusByTime', {
                  'beginTime': '${date.text.trim()} ${begin.text.trim()}',
                  'endTime': '${date.text.trim()} ${end.text.trim()}',
                  'floorLike': floor.text.trim(),
                  'parentId': 'null',
                  'region': '1',
                }),
              ),
              button(
                '预约座位',
                () => request('/spaceAppoint/app/addSpaceAppoint', {
                  'spaceId': seat.text.trim(),
                  'date': date.text.trim(),
                  'beginTime': begin.text.trim(),
                  'endTime': end.text.trim(),
                }),
              ),
            ],
          ),
          const Divider(),
          field(appointmentId, '预约 ID'),
          _DebugButtonGroup(
            children: [
              button(
                '直接签到（调试）',
                () => request('/station/app/signIn', {
                  'id': appointmentId.text.trim(),
                }),
              ),
              button(
                '签退',
                () => request('/station/app/signOut', {
                  'id': appointmentId.text.trim(),
                }),
              ),
              button(
                '取消预约',
                () => request('/spaceAppoint/app/revocationAppointApp', {
                  'id': appointmentId.text.trim(),
                }),
              ),
              OutlinedButton(
                onPressed: busy.value
                    ? null
                    : () async {
                        await context.pushNamed(
                          AppRoutes.learningScanner,
                          arguments: LearningScannerArgs(
                            appointmentId: appointmentId.text.trim(),
                            token: token.text.trim(),
                          ),
                        );
                      },
                child: Text('扫码签到'),
              ),
            ],
          ),
          if (busy.value) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Text('接口响应', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText(
            result.value,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

class _DebugButtonGroup extends StatelessWidget {
  const _DebugButtonGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kDevButtonGroupMaxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= kDevButtonGroupWideWidth
                ? children.length
                : 2;
            return Material(
              color: colors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: OutlinedButtonTheme(
                data: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    side: BorderSide.none,
                    shape: const RoundedRectangleBorder(),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (
                      var start = 0;
                      start < children.length;
                      start += columns
                    ) ...[
                      if (start > 0)
                        Divider(height: 1, color: colors.outlineVariant),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < columns; i++) ...[
                              if (i > 0)
                                VerticalDivider(
                                  width: 1,
                                  color: colors.outlineVariant,
                                ),
                              Expanded(
                                child: start + i < children.length
                                    ? children[start + i]
                                    : const SizedBox(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
