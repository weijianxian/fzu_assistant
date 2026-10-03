/// SharedPreferences 存储 key 常量
abstract final class SpKeys {
  static const themeKey = 'theme_key';
  static const themeMode = 'theme_mode';
  static const localeKey = 'locale_key';
  static const homeStyle = 'home_style';
  static const timelineDays = 'timeline_days';
  static const cacheCoursesMap = 'cache_courses_map';
  static const cacheSchoolCalendar = 'cache_school_calendar';
  static const cacheTermEventsMap = 'cache_term_events_map';
  static const cacheExamRoomsMap = 'cache_exam_rooms_map';
  static const skipUpdateVersion = 'skip_update_version';
  static const skipUpdatesPermanently = 'skip_updates_permanently';
  static const siteInjectionEnabled = 'site_injection_enabled';
  static const showExamOnSchedule = 'show_exam_on_schedule';
  static const autoAdjustCourse = 'auto_adjust_course';
  static const githubProxyEnabled = 'github_proxy_enabled';
  static const githubProxyBaseUrl = 'github_proxy_base_url';

  /// 与登录账号绑定的缓存，登出/换号时必须清除。
  ///
  /// 这些缓存只按学期分片、不含账号维度，不清理会让新账号读到旧账号的数据。
  /// 校历（[cacheSchoolCalendar]、[cacheTermEventsMap]）是全校通用的，不在此列。
  static const userScopedCacheKeys = [cacheCoursesMap, cacheExamRoomsMap];
}
