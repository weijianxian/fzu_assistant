import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/widgets.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/learning_center.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/screen/toolbox/learning_center/learning_center_widgets.dart';
import 'package:fzu_assistant/service/api/learning_center_service.dart';

class LearningAppointmentsPage extends HookWidget {
  const LearningAppointmentsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final records = useState<List<LearningAppointment>>([]);
    final page = useRef(0);
    final loading = useState(false);
    final acting = useState(false);
    final more = useState(true);
    final error = useState<String?>(null);
    final updatedAt = useState<DateTime?>(null);
    final now = useState(DateTime.now());
    final api = LearningCenterService.instance;

    Future<void> fetch({bool refresh = true}) async {
      if (loading.value) return;
      loading.value = true;
      error.value = null;
      final next = refresh ? 1 : page.value + 1;
      try {
        final result = await api.appointments(page: next);
        if (!context.mounted) return;
        records.value = (refresh ? result : [...records.value, ...result])
          ..sort(LearningAppointment.compareNewestFirst);
        page.value = next;
        more.value = result.length == 30;
        updatedAt.value = DateTime.now();
        now.value = DateTime.now();
      } catch (e) {
        if (context.mounted) {
          error.value = e.toString();
          await showLearningError(context, e);
        }
      } finally {
        if (context.mounted) loading.value = false;
      }
    }

    useEffect(() {
      fetch();
      final timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (context.mounted) now.value = DateTime.now();
      });
      return timer.cancel;
    }, const []);

    Future<void> act(
      LearningAppointment appointment,
      LearningAppointmentStatus status,
    ) async {
      if (acting.value || loading.value) return;
      acting.value = true;
      try {
        if (status == LearningAppointmentStatus.pending) {
          await context.pushNamed(
            AppRoutes.learningScanner,
            arguments: LearningScannerArgs(appointmentId: appointment.id),
          );
        } else {
          final label = status == LearningAppointmentStatus.signedIn
              ? l10n.learningSignOut
              : l10n.learningCancelAppointment;
          if (!await confirmLearningAction(
            context,
            label,
            '${l10n.learningSeatLabel(appointment.floor, appointment.seatName)}\n${appointment.date} ${appointment.beginTime}–${appointment.endTime}',
          )) {
            return;
          }
          if (status == LearningAppointmentStatus.signedIn) {
            await api.signOut(appointment.id);
          } else {
            await api.cancel(appointment.id);
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.learningActionSucceeded)),
            );
          }
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        if (context.mounted) await fetch();
      } catch (e) {
        if (context.mounted) await showLearningError(context, e);
      } finally {
        if (context.mounted) acting.value = false;
      }
    }

    String statusText(LearningAppointmentStatus status) => switch (status) {
      LearningAppointmentStatus.upcoming => l10n.learningUpcoming,
      LearningAppointmentStatus.pending => l10n.learningPending,
      LearningAppointmentStatus.signedIn => l10n.learningSignedIn,
      LearningAppointmentStatus.missed => l10n.learningMissed,
      LearningAppointmentStatus.cancelled => l10n.learningCancelled,
      LearningAppointmentStatus.completed => l10n.learningCompleted,
      LearningAppointmentStatus.unknown => l10n.learningUnknown,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.learningAppointments),
        actions: [
          IconButton(
            tooltip: l10n.learningSeatGuide,
            icon: const Icon(Icons.map_outlined),
            onPressed: () => showLearningSeatGuide(context),
          ),
          IconButton(
            onPressed: loading.value || acting.value ? null : fetch,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: ToolPageWrapper(
        loading: loading.value && records.value.isEmpty,
        emptyText: l10n.learningNoAppointments,
        onRefresh: () => fetch(),
        refreshTime: updatedAt.value,
        slivers: [
          if (error.value != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(error.value!),
                    TextButton(
                      onPressed: loading.value ? null : fetch,
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            ),
          if (records.value.isEmpty && !loading.value)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.learningNoAppointments),
              ),
            ),
          if (acting.value || (loading.value && records.value.isNotEmpty))
            const SliverToBoxAdapter(child: LinearProgressIndicator()),
          MasonrySliverGrid(
            padding: const EdgeInsets.all(16),
            childCount: records.value.length,
            itemBuilder: (context, index) {
              final item = records.value[index];
              final status = item.statusAt(now.value);
              final action = switch (status) {
                LearningAppointmentStatus.upcoming =>
                  l10n.learningCancelAppointment,
                LearningAppointmentStatus.pending => l10n.learningScanSignIn,
                LearningAppointmentStatus.signedIn => l10n.learningSignOut,
                _ => null,
              };
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: l10n.learningAppointmentTitle(
                            item.floor,
                            item.seatName.padLeft(3, '0'),
                          ),
                          children: [
                            TextSpan(
                              text: ' #${item.id}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.date} ${item.beginTime}–${item.endTime}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusText(status),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (action != null) ...[
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: acting.value || loading.value
                              ? null
                              : () => act(item, status),
                          child: Text(action),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          if (more.value && records.value.isNotEmpty)
            SliverToBoxAdapter(
              child: TextButton(
                onPressed: loading.value || acting.value
                    ? null
                    : () => fetch(refresh: false),
                child: Text(l10n.learningLoadMore),
              ),
            ),
        ],
      ),
    );
  }
}
