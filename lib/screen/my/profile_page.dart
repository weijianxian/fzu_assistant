import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/student_info.dart';
import 'package:fzu_assistant/service/api/user_service.dart';
import 'package:fzu_assistant/service/auth_storage.dart';

class ProfilePage extends HookWidget {
  const ProfilePage({super.key, this.showAppBar = true, this.footer});

  final bool showAppBar;
  final Widget? footer;

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

    final body = loading.value
        ? const Center(child: CircularProgressIndicator())
        : error.value != null
        ? Center(
            child: Text(
              AppLocalizations.of(context)!.loadingFailed(error.value ?? ''),
            ),
          )
        : _buildContent(context, info.value!, username.value);

    if (!showAppBar) return body;
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.profileInfo)),
      body: body,
    );
  }

  Widget _buildContent(
    BuildContext context,
    StudentInfo info,
    String? username,
  ) {
    final l10n = AppLocalizations.of(context)!;
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
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _infoRow(l10n.college, info.college),
                _infoRow(l10n.major, info.major),
                _infoRow(l10n.grade, info.grade),
              ],
            ),
          ),
        ),
        ?footer,
      ],
    );
  }

  Widget _infoRow(String label, String value) => Padding(
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
