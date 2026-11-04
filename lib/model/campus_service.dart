/// The official campus directory is static and does not fetch service metadata.
enum CampusServiceCategory { life, bookings, growth, office, network }

/// Destinations from the university service directory, without academic cookies.
///
/// Public information pages bypass the existing SSO flow. SSO
/// tickets remain scoped to the SSO host by the shared WebView implementation.
enum CampusService {
  dormRepair(
    CampusServiceCategory.life,
    'http://ehall.fzu.edu.cn/ssfw/sys/swmssbxapp/*default/index.do',
  ),
  accommodation(
    CampusServiceCategory.life,
    'http://ehall.fzu.edu.cn/ssfw/sys/swmxszsapp/*default/index.do',
  ),
  lostAndFound(
    CampusServiceCategory.life,
    'https://app.fzu.edu.cn/appEntry/app/index?redirectUrl=https://app.fzu.edu.cn/appService/lostAndFound/app',
  ),
  attendance(
    CampusServiceCategory.life,
    'https://yzsxg.fzu.edu.cn/livecloud/project/fzu/attn/oauth2/authorize.action',
  ),
  electricBike(
    CampusServiceCategory.life,
    'http://doorwxoa.fzu.edu.cn/appCas/index',
  ),
  electricBikeRegistration(
    CampusServiceCategory.life,
    'http://doorwxoa.fzu.edu.cn/nonmotorReg',
  ),
  newStudentServices(
    CampusServiceCategory.life,
    'http://ehall.fzu.edu.cn/fxfw/sys/swmyxapp/*default/index.do',
  ),
  returnReservation(
    CampusServiceCategory.life,
    'https://app.fzu.edu.cn/appEntry/app/index?redirectUrl=https://app.fzu.edu.cn/appService/backToSchool/app/index',
  ),
  reservations(
    CampusServiceCategory.bookings,
    'https://aiot.fzu.edu.cn/ibs/#/',
  ),
  libraryReservation(
    CampusServiceCategory.bookings,
    'https://kjgl.fzu.edu.cn/libseat',
  ),
  venueReservation(
    CampusServiceCategory.bookings,
    'https://app.fzu.edu.cn/appEntry/app/index?redirectUrl=https://app.fzu.edu.cn/appService/area/app/index',
  ),
  lectureReports(
    CampusServiceCategory.growth,
    'https://www.fzu.edu.cn/jzbg.htm',
    requiresSso: false,
  ),
  certifications(
    CampusServiceCategory.growth,
    'https://app.fzu.edu.cn/appService/guidance/app/searchExam',
  ),
  resume(
    CampusServiceCategory.growth,
    'https://app.fzu.edu.cn/appEntry/app/index?redirectUrl=https://app.fzu.edu.cn/appService/curriculumVitae/app/index',
  ),
  activities(
    CampusServiceCategory.growth,
    'https://app.fzu.edu.cn/appEntry/app/index?redirectUrl=https://app.fzu.edu.cn/appService/activityCenter/app/center',
  ),
  savedActivities(
    CampusServiceCategory.growth,
    'https://app.fzu.edu.cn/appEntry/app/index?redirectUrl=https://app.fzu.edu.cn/appService/activityCenter/app/collectList',
  ),
  youthLeague(CampusServiceCategory.growth, 'http://59.77.241.196:8081/wise/'),
  partyTraining(
    CampusServiceCategory.growth,
    'https://sso.fzu.edu.cn/login?service=https://oss.fzu.edu.cn/api/auth/cas/connector/login?applicationUrl=https://oss.fzu.edu.cn/gbpxMobileUserApp',
  ),
  yiban(
    CampusServiceCategory.growth,
    'https://api.uyiban.com/base/c/rgsid/login',
  ),
  mailbox(
    CampusServiceCategory.office,
    'https://app.fzu.edu.cn/appEntry/app/index?redirectUrl=https%3A%2F%2Fapp.fzu.edu.cn%2FappService%2Fmailbox%2Fapp%2FfreeMailbox',
  ),
  quickResponse(
    CampusServiceCategory.office,
    'https://sso.fzu.edu.cn/login?service=https://oss.fzu.edu.cn/api/auth/cas/connector/login?applicationUrl=https://oss.fzu.edu.cn/kuz12345-h5/',
  ),
  trustedDocuments(
    CampusServiceCategory.office,
    'https://sso.fzu.edu.cn/login?service=http%3A%2F%2Fetrust.fzu.edu.cn%2Fapi%2Fcas%2Flogin%3Fsource%3Dmobile',
  ),
  officialNotices(
    CampusServiceCategory.office,
    'https://info.fzu.edu.cn/',
    requiresSso: false,
  ),
  studentAffairs(CampusServiceCategory.office, 'https://yzsxg.fzu.edu.cn'),
  unifiedPayment(CampusServiceCategory.office, 'http://tyzf.fzu.edu.cn'),
  cardServices(
    CampusServiceCategory.office,
    'https://xcx.fzu.edu.cn/berserker-auth/cas/redirect/ruiJie?targetUrl=https%3A%2F%2Fxcx.fzu.edu.cn%2Fberserker-base%2Fredirect%3FappId%3D16%26nodeId%3D15%26type%3Dapp',
  ),
  forms(
    CampusServiceCategory.office,
    'https://sso.fzu.edu.cn/login?service=https://mybt.fzu.edu.cn/login',
  ),
  identityVerification(
    CampusServiceCategory.office,
    'https://idself.fzu.edu.cn/public/client/account-activate/name?backUrl=https:%2F%2Fidself.fzu.edu.cn',
  ),
  map(
    CampusServiceCategory.network,
    'https://map.fzu.edu.cn',
    requiresSso: false,
  ),
  networkRepair(
    CampusServiceCategory.network,
    'http://59.77.227.111:32001/relax/mobile/index.html',
  ),
  networkGuide(
    CampusServiceCategory.network,
    'https://app.fzu.edu.cn/appService/guidance/app/articleCollapse',
    requiresSso: false,
  );

  const CampusService(this.category, this.url, {this.requiresSso = true});

  final CampusServiceCategory category;
  final String url;
  final bool requiresSso;
}
