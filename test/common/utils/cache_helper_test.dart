import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/common/utils/cache_helper.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('登出清理会删掉账号相关的课程与考场缓存', () async {
    await CacheHelper.saveForKey(SpKeys.cacheCoursesMap, '202501', {
      'courses': <dynamic>[],
    });
    await CacheHelper.saveForKey(
      SpKeys.cacheExamRoomsMap,
      '202501',
      <dynamic>[],
    );
    // 校历是全校通用的，不该跟着账号被清掉。
    await CacheHelper.saveMap(SpKeys.cacheSchoolCalendar, {
      'currentTerm': '202501',
      'terms': <dynamic>[],
    });

    await CacheHelper.removeAll(SpKeys.userScopedCacheKeys);

    final sp = await SharedPreferences.getInstance();
    expect(sp.getString(SpKeys.cacheCoursesMap), isNull);
    expect(sp.getString(SpKeys.cacheExamRoomsMap), isNull);
    expect(sp.getString(SpKeys.cacheSchoolCalendar), isNotNull);
  });
}
