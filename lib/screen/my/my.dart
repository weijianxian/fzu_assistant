import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/student_info.dart';
import 'package:fzu_assistant/screen/dev/dev_tool.dart';
import 'package:fzu_assistant/screen/guest/login.dart';
import 'package:fzu_assistant/screen/my/about/about_page.dart';
import 'package:fzu_assistant/screen/my/calendar/calendar_page.dart';
import 'package:fzu_assistant/screen/settings/language_settings.dart';
import 'package:fzu_assistant/screen/settings/theme_settings.dart';
import 'package:fzu_assistant/service/auth_storage.dart';
import 'package:fzu_assistant/service/user_service.dart';

class MyPage extends HookWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final username = useState<String?>(null);
    final info = useState<StudentInfo?>(null);
    final loading = useState(true);
    final error = useState<String?>(null);
    final auth = useMemoized(() => AuthStorage());
    final userService = useMemoized(() => UserService());
    final mounted = useRef(true);
    useEffect(
      () => () {
        mounted.value = false;
      },
      [],
    );

    useEffect(() {
      auth.loadCredentials().then((creds) {
        if (mounted.value) username.value = creds?.username;
      });
      userService
          .getUserInfo()
          .then((data) {
            if (!mounted.value) return;
            info.value = data;
            loading.value = false;
          })
          .catchError((e) {
            if (!mounted.value) return;
            error.value = e.toString();
            loading.value = false;
          });
      return null;
    }, []);

    Future<void> handleLogout() async {
      await auth.clearCredentials();
      if (context.mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.navMy),
        actions: [
          IconButton(
            icon: const Icon(Icons.developer_board),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const DevToolPage())),
          ),
        ],
      ),
      body: loading.value
          ? const Center(child: CircularProgressIndicator())
          : error.value != null
          ? Center(
              child: Text(
                AppLocalizations.of(context)!.loadingFailed(error.value ?? ''),
              ),
            )
          : _buildContent(context, info.value!, username.value, handleLogout),
    );
  }

  Widget _buildContent(
    BuildContext context,
    StudentInfo info,
    String? username,
    VoidCallback onLogout,
  ) {
    return ListView(
      children: [
        const SizedBox(height: 32),
        Center(
          child: CircleAvatar(
            radius: 48,
            child: Text(
              info.name.isNotEmpty ? info.name[0] : '?',
              style: const TextStyle(fontSize: 36),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            info.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        Center(
          child: Text(
            username ?? '',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 24),
        // _infoCard([
        //   _infoRow('性别', info.sex),
        //   _infoRow('民族', info.nationality),
        //   _infoRow('出生日期', info.birthday),
        //   _infoRow('政治面貌', info.politicalStatus),
        // ]),
        _infoCard([
          _infoRow(AppLocalizations.of(context)!.college, info.college),
          _infoRow(AppLocalizations.of(context)!.major, info.major),
          _infoRow(AppLocalizations.of(context)!.grade, info.grade),
          // _infoRow('辅导员', info.counselor),
        ]),
        // _infoCard([
        //   _infoRow('手机号', info.phone),
        //   _infoRow('邮箱', info.email),
        //   _infoRow('生源地', info.source),
        //   _infoRow('考生类别', info.examineeCategory),
        //   _infoRow('国别', info.country),
        // ]),
        // if (info.statusChanges.isNotEmpty)
        //   _infoCard([
        //     _infoRow('学籍异动', info.statusChanges),
        //   ]),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.calendar_month_outlined),
          title: Text(AppLocalizations.of(context)!.calendar),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CalendarPage())),
        ),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: Text(AppLocalizations.of(context)!.themeSettings),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ThemeSettingsPage())),
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(AppLocalizations.of(context)!.language),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LanguageSettingsPage()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(AppLocalizations.of(context)!.about),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AboutPage())),
        ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: Text(
            AppLocalizations.of(context)!.logout,
            style: const TextStyle(color: Colors.red),
          ),
          onTap: onLogout,
        ),
      ],
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: children),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(value.isNotEmpty ? value : '-')),
        ],
      ),
    );
  }
}
