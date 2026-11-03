import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fzu_assistant/constants/sp_keys.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final old in [null, false, true]) {
    test(
      'legacy west2 consent $old migrates without enabling other services',
      () async {
        SharedPreferences.setMockInitialValues({
          SpKeys.west2AdjustmentsEnabled: ?old,
        });
        final settings = AppSettings();
        await settings.load();
        expect(settings.useWest2Adjustments, old == true);
        expect(settings.papersAccess.value, FeatureAccess.tip);
        settings.west2AdjustmentsAccess.value = FeatureAccess.hide;
        settings.papersAccess.value = FeatureAccess.allow;
        final next = AppSettings();
        await next.load();
        expect(next.west2AdjustmentsAccess.value, FeatureAccess.hide);
        expect(next.useWest2Adjustments, isFalse);
        expect(next.papersAccess.value, FeatureAccess.allow);
        settings.dispose();
        next.dispose();
      },
    );
  }
}
