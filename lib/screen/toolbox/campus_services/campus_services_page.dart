import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/campus_service.dart';
import 'package:fzu_assistant/router/app_routes.dart';

/// Official campus services; west2 online is not contacted by this page.
class CampusServicesPage extends HookWidget {
  const CampusServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sections = useMemoized(
      () => {
        for (final category in CampusServiceCategory.values)
          category: CampusService.values
              .where((service) => service.category == category)
              .toList(growable: false),
      },
    );
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
          // Keep the small service groups in one masonry delegate. Multiple
          // short masonry slivers can repeatedly correct the viewport offset
          // when a completed group scrolls out of the cache area.
          MasonrySliverGrid(
            padding: EdgeInsets.zero,
            childCount: sections.length,
            itemBuilder: (context, index) {
              final section = sections.entries.elementAt(index);
              return AppSection.list(
                title: section.key.title(l10n),
                children: [
                  for (final service in section.value)
                    ListTile(
                      key: ValueKey(service),
                      leading: Icon(service.icon),
                      title: Text(service.title(l10n)),
                      subtitle: Text(service.description(l10n)),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => context.pushNamed(
                        AppRoutes.webview,
                        arguments: WebViewArgs(
                          url: service.url,
                          title: service.title(l10n),
                          injectCookies: false,
                          injectSsoCookies: service.requiresSso,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

extension on CampusServiceCategory {
  String title(AppLocalizations l10n) => switch (this) {
    CampusServiceCategory.life => l10n.campusServicesLife,
    CampusServiceCategory.bookings => l10n.campusServicesBookings,
    CampusServiceCategory.growth => l10n.campusServicesGrowth,
    CampusServiceCategory.office => l10n.campusServicesOffice,
    CampusServiceCategory.network => l10n.campusServicesNetwork,
  };
}

extension on CampusService {
  String title(AppLocalizations l10n) => switch (this) {
    CampusService.dormRepair => l10n.campusDormRepair,
    CampusService.accommodation => l10n.campusAccommodation,
    CampusService.lostAndFound => l10n.campusLostAndFound,
    CampusService.attendance => l10n.campusAttendance,
    CampusService.electricBike => l10n.campusElectricBike,
    CampusService.electricBikeRegistration =>
      l10n.campusElectricBikeRegistration,
    CampusService.newStudentServices => l10n.campusNewStudentServices,
    CampusService.returnReservation => l10n.campusReturnReservation,
    CampusService.reservations => l10n.campusReservations,
    CampusService.libraryReservation => l10n.campusLibraryReservation,
    CampusService.venueReservation => l10n.campusVenueReservation,
    CampusService.lectureReports => l10n.campusLectureReports,
    CampusService.certifications => l10n.campusCertifications,
    CampusService.resume => l10n.campusResume,
    CampusService.activities => l10n.campusActivities,
    CampusService.savedActivities => l10n.campusSavedActivities,
    CampusService.youthLeague => l10n.campusYouthLeague,
    CampusService.partyTraining => l10n.campusPartyTraining,
    CampusService.yiban => l10n.campusYiban,
    CampusService.mailbox => l10n.campusMailbox,
    CampusService.quickResponse => l10n.campusQuickResponse,
    CampusService.trustedDocuments => l10n.campusTrustedDocuments,
    CampusService.officialNotices => l10n.campusOfficialNotices,
    CampusService.studentAffairs => l10n.campusStudentAffairs,
    CampusService.unifiedPayment => l10n.campusUnifiedPayment,
    CampusService.cardServices => l10n.campusCardServices,
    CampusService.forms => l10n.campusForms,
    CampusService.identityVerification => l10n.campusIdentityVerification,
    CampusService.map => l10n.campusMap,
    CampusService.networkRepair => l10n.campusNetworkRepair,
    CampusService.networkGuide => l10n.campusNetworkGuide,
  };

  String description(AppLocalizations l10n) => switch (this) {
    CampusService.dormRepair => l10n.campusDormRepairDescription,
    CampusService.accommodation => l10n.campusAccommodationDescription,
    CampusService.lostAndFound => l10n.campusLostAndFoundDescription,
    CampusService.attendance => l10n.campusAttendanceDescription,
    CampusService.electricBike => l10n.campusElectricBikeDescription,
    CampusService.electricBikeRegistration =>
      l10n.campusElectricBikeRegistrationDescription,
    CampusService.newStudentServices =>
      l10n.campusNewStudentServicesDescription,
    CampusService.returnReservation => l10n.campusReturnReservationDescription,
    CampusService.reservations => l10n.campusReservationsDescription,
    CampusService.libraryReservation =>
      l10n.campusLibraryReservationDescription,
    CampusService.venueReservation => l10n.campusVenueReservationDescription,
    CampusService.lectureReports => l10n.campusLectureReportsDescription,
    CampusService.certifications => l10n.campusCertificationsDescription,
    CampusService.resume => l10n.campusResumeDescription,
    CampusService.activities => l10n.campusActivitiesDescription,
    CampusService.savedActivities => l10n.campusSavedActivitiesDescription,
    CampusService.youthLeague => l10n.campusYouthLeagueDescription,
    CampusService.partyTraining => l10n.campusPartyTrainingDescription,
    CampusService.yiban => l10n.campusYibanDescription,
    CampusService.mailbox => l10n.campusMailboxDescription,
    CampusService.quickResponse => l10n.campusQuickResponseDescription,
    CampusService.trustedDocuments => l10n.campusTrustedDocumentsDescription,
    CampusService.officialNotices => l10n.campusOfficialNoticesDescription,
    CampusService.studentAffairs => l10n.campusStudentAffairsDescription,
    CampusService.unifiedPayment => l10n.campusUnifiedPaymentDescription,
    CampusService.cardServices => l10n.campusCardServicesDescription,
    CampusService.forms => l10n.campusFormsDescription,
    CampusService.identityVerification =>
      l10n.campusIdentityVerificationDescription,
    CampusService.map => l10n.campusMapDescription,
    CampusService.networkRepair => l10n.campusNetworkRepairDescription,
    CampusService.networkGuide => l10n.campusNetworkGuideDescription,
  };

  IconData get icon => switch (this) {
    CampusService.dormRepair => Icons.apartment_outlined,
    CampusService.accommodation => Icons.bed_outlined,
    CampusService.lostAndFound => Icons.find_in_page_outlined,
    CampusService.attendance => Icons.fact_check_outlined,
    CampusService.electricBike ||
    CampusService.electricBikeRegistration => Icons.electric_bike_outlined,
    CampusService.newStudentServices => Icons.how_to_reg_outlined,
    CampusService.returnReservation => Icons.directions_bus_outlined,
    CampusService.reservations => Icons.event_seat_outlined,
    CampusService.libraryReservation => Icons.local_library_outlined,
    CampusService.venueReservation => Icons.stadium_outlined,
    CampusService.lectureReports => Icons.record_voice_over_outlined,
    CampusService.certifications => Icons.workspace_premium_outlined,
    CampusService.resume => Icons.badge_outlined,
    CampusService.activities => Icons.event_outlined,
    CampusService.savedActivities => Icons.bookmarks_outlined,
    CampusService.youthLeague => Icons.groups_outlined,
    CampusService.partyTraining => Icons.menu_book_outlined,
    CampusService.yiban => Icons.school_outlined,
    CampusService.mailbox => Icons.mail_outline,
    CampusService.quickResponse => Icons.support_agent_outlined,
    CampusService.trustedDocuments => Icons.verified_user_outlined,
    CampusService.officialNotices => Icons.campaign_outlined,
    CampusService.studentAffairs => Icons.school_outlined,
    CampusService.unifiedPayment => Icons.account_balance_outlined,
    CampusService.cardServices => Icons.credit_card_outlined,
    CampusService.forms => Icons.assignment_outlined,
    CampusService.identityVerification => Icons.person_search_outlined,
    CampusService.map => Icons.map_outlined,
    CampusService.networkRepair => Icons.router_outlined,
    CampusService.networkGuide => Icons.wifi_outlined,
  };
}
