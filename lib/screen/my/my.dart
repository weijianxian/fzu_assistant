import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/student_info.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/auth_storage.dart';
import 'package:fzu_assistant/service/api/user_service.dart';

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

    useEffect(() {
      auth.loadCredentials().then((creds) {
        if (context.mounted) username.value = creds?.username;
      });
      userService
          .getUserInfo()
          .then((data) {
            if (!context.mounted) return;
            info.value = data;
            loading.value = false;
          })
          .catchError((e) {
            if (!context.mounted) return;
            error.value = e.toString();
            loading.value = false;
          });
      return null;
    }, []);

    Future<void> handleLogout() async {
      await auth.clearCredentials();
      if (context.mounted) {
        context.pushReplacementNamed(AppRoutes.login);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.navMy),
        actions: [
          IconButton(
            icon: const Icon(Icons.developer_board),
            onPressed: () => context.pushNamed(AppRoutes.dev),
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
        _infoCard([
          _infoRow(AppLocalizations.of(context)!.college, info.college),
          _infoRow(AppLocalizations.of(context)!.major, info.major),
          _infoRow(AppLocalizations.of(context)!.grade, info.grade),
        ]),
        const Divider(),
        ChevronListTile(
          leading: const Icon(Icons.calendar_month_outlined),
          title: Text(AppLocalizations.of(context)!.calendar),
          onTap: () => context.pushNamed(AppRoutes.calendar),
        ),
        ChevronListTile(
          leading: const Icon(Icons.settings_outlined),
          title: Text(AppLocalizations.of(context)!.settings),
          onTap: () => context.pushNamed(AppRoutes.settings),
        ),
        ChevronListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(AppLocalizations.of(context)!.about),
          onTap: () => context.pushNamed(AppRoutes.about),
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
