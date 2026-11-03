import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';

/// Official campus services; west2 online is not contacted by this page.
class CampusServicesPage extends HookWidget {
  const CampusServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final services = [
      (
        Icons.apartment_outlined,
        l10n.campusDormRepair,
        'http://ehall.fzu.edu.cn/ssfw/sys/swmssbxapp/*default/index.do',
      ),
      (
        Icons.event_seat_outlined,
        l10n.campusReservations,
        'https://aiot.fzu.edu.cn/ibs/#/',
      ),
      (
        Icons.local_library_outlined,
        l10n.campusLibraryReservation,
        'https://kjgl.fzu.edu.cn/libseat',
      ),
      (
        Icons.find_in_page_outlined,
        l10n.campusLostAndFound,
        'https://app.fzu.edu.cn/appEntry/app/index?redirectUrl=https://app.fzu.edu.cn/appService/lostAndFound/app',
      ),
      (
        Icons.fact_check_outlined,
        l10n.campusAttendance,
        'https://yzsxg.fzu.edu.cn/livecloud/project/fzu/attn/oauth2/authorize.action',
      ),
      (
        Icons.electric_bike_outlined,
        l10n.campusElectricBike,
        'http://doorwxoa.fzu.edu.cn/appCas/index',
      ),
      (
        Icons.school_outlined,
        l10n.campusYiban,
        'https://api.uyiban.com/base/c/rgsid/login',
      ),
    ];
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.campusServices)),
      body: ToolPageWrapper(
        loading: false,
        emptyText: l10n.noData,
        onRefresh: () async {},
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.campusServicesDescription),
            ),
          ),
          MasonrySliverGrid(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            childCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(service.$1),
                  title: Text(service.$2),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => context.pushNamed(
                    AppRoutes.webview,
                    arguments: WebViewArgs(
                      url: service.$3,
                      title: service.$2,
                      injectCookies: false,
                      injectSsoCookies: true,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
