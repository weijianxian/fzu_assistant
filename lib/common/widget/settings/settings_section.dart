import 'package:fzu_assistant/common/widget/layout/app_section.dart';

/// Settings use the same groups as the rest of the app.
class SettingsSection extends AppSection {
  const SettingsSection({super.key, super.title, required super.child});

  const SettingsSection.list({super.key, super.title, required super.children})
    : super.list();
}

class SettingsDivider extends AppDivider {
  const SettingsDivider({super.key});
}
