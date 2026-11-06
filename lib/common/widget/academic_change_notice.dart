import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/academic_changes_service.dart';
import 'package:fzu_assistant/service/api/api_client.dart';

class AcademicChangeNotice extends HookWidget {
  const AcademicChangeNotice({super.key, required this.exams});
  final bool exams;

  @override
  Widget build(BuildContext context) {
    final service = AcademicChangesService.instance;
    final account = ApiClient.instance.studentId ?? '';
    final changes = useValueListenable(service);
    useEffect(() {
      unawaited(service.load(account).catchError((Object _) {}));
      return null;
    }, [account]);
    final count = changes
        .where((item) => !item.read && item.type.isExam == exams)
        .length;
    if (count == 0) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.notifications_active_outlined),
      title: Text(AppLocalizations.of(context)!.academicChangeCount(count)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.pushNamed(AppRoutes.academicChanges),
    );
  }
}
