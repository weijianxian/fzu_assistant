import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';

class AcademicShortcutsPage extends HookWidget {
  const AcademicShortcutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sections = [
      (
        l10n.courseSelection,
        [
          (l10n.evalTabXqxk, 'glxk/xqxk/xqxk_cszt.aspx'),
          (l10n.campusElectiveSelection, 'glxk/xxk/xxk_cszt.aspx'),
          (l10n.retakeSelection, 'glxk/cxxk/cxxk_cszt.aspx'),
          (l10n.minorSelection, 'glxk/erzyxk/erzyxk_cszt.aspx'),
        ],
      ),
      (
        l10n.academicApplications,
        [
          (l10n.majorTransferApplication, 'glsq/zzysq/zzyapplication.aspx'),
          (l10n.examDeferralApplication, 'glsq/hksq/hkapplication.aspx'),
          (l10n.courseExemptionApplication, 'glsq/mxsq/mxapplication.aspx'),
          (l10n.minorApplication, 'glsq/fxsq/fxapplication.aspx'),
          (l10n.classroomApplication, 'glsq/jssq/classroomapplication.aspx'),
          (l10n.creditRecognition, 'glsq/xftd/xftd_cszt.aspx'),
          (l10n.majorAllocation, 'glsq/majordistribution/major_cszt.aspx'),
          (l10n.electiveCreditConversion, 'glsq/xxzcy/xxzcy_cszt.aspx'),
        ],
      ),
      (l10n.campusInfo, [(l10n.jiaxiLectures, 'glbm/lecture/jxjt_cszt.aspx')]),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.academicShortcuts)),
      body: ToolPageWrapper(
        loading: false,
        emptyText: l10n.noData,
        onRefresh: () async {},
        slivers: [
          for (final section in sections)
            Section.sliver(
              title: section.$1,
              child: MasonrySliverGrid(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                childCount: section.$2.length,
                itemBuilder: (context, index) {
                  final entry = section.$2[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      title: Text(entry.$1),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => context.pushNamed(
                        AppRoutes.webview,
                        arguments: WebViewArgs(
                          url:
                              'https://jwcjwxt2.fzu.edu.cn:81/student/${entry.$2}',
                          title: entry.$1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
