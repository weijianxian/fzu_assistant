import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/constants/time_slots.dart';
import 'package:fzu_assistant/service/early_class_reminder_service.dart';

class EarlyClassReminderPage extends HookWidget {
  const EarlyClassReminderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final enabled = useState(EarlyClassReminderService.isEnabled);
    final minutes = useState(EarlyClassReminderService.minutesBefore);
    final skipWeekend = useState(EarlyClassReminderService.skipWeekend);

    final now = DateTime.now();
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Early Class Reminder')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Enable Reminder'),
            subtitle: const Text('Notify tomorrow\'s first class each evening'),
            value: enabled.value,
            onChanged: (v) async {
              await EarlyClassReminderService.setEnabled(v);
              enabled.value = v;
            },
          ),
          ListTile(
            title: Text('Minutes before last class ends: ${minutes.value}'),
            subtitle: Slider(
              min: 0,
              max: 20,
              divisions: 20,
              value: minutes.value.toDouble(),
              label: '${minutes.value} min',
              onChanged: enabled.value
                  ? (v) {
                      minutes.value = v.round();
                      EarlyClassReminderService.setMinutesBefore(v.round());
                    }
                  : null,
            ),
          ),
          SwitchListTile(
            title: const Text('Skip Weekend'),
            subtitle: const Text('Don\'t notify if tomorrow is Sat/Sun'),
            value: skipWeekend.value,
            onChanged: enabled.value
                ? (v) async {
                    await EarlyClassReminderService.setSkipWeekend(v);
                    skipWeekend.value = v;
                  }
                : null,
          ),
          const Divider(),
          ListTile(
            title: const Text('Scheduled Alarms'),
            trailing: FilledButton.tonal(
              onPressed: () async {
                await EarlyClassReminderService.scheduleForWeek();
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Rescheduled')));
                }
              },
              child: const Text('Reschedule'),
            ),
          ),
          for (var i = 0; i < 7; i++)
            _AlarmTile(
              weekday: i + 1,
              label: days[i],
              now: now,
              isToday: i + 1 == now.weekday,
              color: scheme.primary,
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Alarm time = last class end - ${minutes.value} min\n'
              'If no class, uses default last slot (${timeSlots.last.$2})\n'
              'Alarm IDs: 3001-3007 (Mon-Sun)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlarmTile extends StatelessWidget {
  final int weekday;
  final String label;
  final DateTime now;
  final bool isToday;
  final Color color;

  const _AlarmTile({
    required this.weekday,
    required this.label,
    required this.now,
    required this.isToday,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final daysToAdd = weekday - now.weekday;
    final date = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: daysToAdd <= 0 ? daysToAdd + 7 : daysToAdd));

    return ListTile(
      leading: Icon(
        isToday ? Icons.today : Icons.calendar_today,
        color: isToday ? color : null,
      ),
      title: Text('$label (${date.month}/${date.day})'),
      subtitle: Text('ID: ${3000 + weekday}'),
      dense: true,
    );
  }
}
