import 'package:fzu_assistant/common/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/common/hooks/use_async_data.dart';
import 'package:fzu_assistant/common/utils/semester_utils.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';
import 'package:fzu_assistant/model/custom_course.dart';
import 'package:fzu_assistant/router/app_routes.dart';
import 'package:fzu_assistant/service/api/api_client.dart';
import 'package:fzu_assistant/service/custom_course_store.dart';
import 'package:fzu_assistant/service/settings/app_settings.dart';

const _courseColors = <int>[
  0xfff39f9d,
  0xff9fa5d5,
  0xff83b6b1,
  0xfffdc683,
  0xffeb90b1,
  0xff92c5f2,
  0xffa4d1a6,
];

List<String> _weekdays(AppLocalizations l10n) => [
  l10n.monday,
  l10n.tuesday,
  l10n.wednesday,
  l10n.thursday,
  l10n.friday,
  l10n.saturday,
  l10n.sunday,
];

class CustomCoursesPage extends HookWidget {
  const CustomCoursesPage({super.key, this.store, this.accountProvider});
  final CustomCourseStore? store;
  final String? Function()? accountProvider;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsProvider.of(context);
    final api = store ?? CustomCourseStore.instance;
    final l10n = AppLocalizations.of(context)!;
    final data = useValueListenable(api);
    final status = useAsyncData(() async {
      await api.load();
      return true;
    });
    String? currentAccount() => accountProvider != null
        ? accountProvider!()
        : ApiClient.instance.studentId;
    final account = currentAccount();
    final terms = useValueListenable(settings.termsKey);
    final configuredTerm = useValueListenable(settings.selectedSemesterKey);
    final term = useState(
      configuredTerm.isNotEmpty ? configuredTerm : terms.firstOrNull ?? '',
    );
    final busy = useState(false);
    final weekdays = _weekdays(l10n);
    final visible =
        data
            .where(
              (entry) => entry.account == account && entry.term == term.value,
            )
            .toList()
          ..sort((a, b) {
            final day = a.weekday.compareTo(b.weekday);
            return day != 0 ? day : a.startClass.compareTo(b.startClass);
          });
    final selectableTerms = <String>{
      ...terms,
      if (term.value.isNotEmpty) term.value,
      for (final course in data)
        if (course.account == account) course.term,
    }.toList()..sort((a, b) => b.compareTo(a));

    Future<void> remove(CustomCourse course) async {
      if (busy.value) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.customCourseDelete),
          content: Text(course.name),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.learningCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.customCourseDelete),
            ),
          ],
        ),
      );
      if (accepted != true || !context.mounted || account != currentAccount()) {
        return;
      }
      busy.value = true;
      try {
        await api.remove(course);
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.toString())));
        }
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.customCourseManagement)),
      body: Column(
        children: [
          if (selectableTerms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                key: ValueKey(term.value),
                initialValue: selectableTerms.contains(term.value)
                    ? term.value
                    : null,
                decoration: InputDecoration(labelText: l10n.selectSemester),
                items: [
                  for (final entry in selectableTerms)
                    DropdownMenuItem(
                      value: entry,
                      child: Text(SemesterUtils.formatSemester(entry)),
                    ),
                ],
                onChanged: (entry) {
                  if (entry != null) term.value = entry;
                },
              ),
            ),
          AppInfoCard(title: Text(l10n.customCoursesDescription)),
          Expanded(
            child: status.loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: status.refresh,
                    child: AppListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        AppSection.list(
                          children: [
                            if (status.error != null)
                              ListTile(
                                title: Text(status.error!),
                                trailing: TextButton(
                                  onPressed: status.refresh,
                                  child: Text(l10n.retry),
                                ),
                              ),
                            if (account == null)
                              ListTile(
                                title: Text(l10n.customCourseLoginRequired),
                              )
                            else if (visible.isEmpty)
                              ListTile(title: Text(l10n.customCoursesEmpty)),
                            for (final course in visible)
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Color(course.color),
                                  child: const Icon(
                                    Icons.event_note,
                                    color: Colors.black87,
                                  ),
                                ),
                                title: Text(course.name),
                                subtitle: Text(
                                  [
                                    '${weekdays[course.weekday - 1]} · ${l10n.classPeriodRange(course.startClass, course.endClass)}',
                                    '${l10n.weekN(course.startWeek)} – ${l10n.weekN(course.endWeek)} · ${course.single && course.double
                                        ? l10n.customCourseEveryWeek
                                        : course.single
                                        ? l10n.customCourseOddWeeks
                                        : l10n.customCourseEvenWeeks}',
                                    if (course.location.isNotEmpty)
                                      course.location,
                                  ].join('\n'),
                                ),
                                onTap: busy.value
                                    ? null
                                    : () => context.pushNamed(
                                        AppRoutes.customCourseEdit,
                                        arguments: CustomCourseEditArgs(
                                          course: course,
                                          term: course.term,
                                        ),
                                      ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: l10n.customCourseDelete,
                                  onPressed: busy.value
                                      ? null
                                      : () => remove(course),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class CustomCourseEditPage extends HookWidget {
  const CustomCourseEditPage({
    super.key,
    required this.args,
    this.store,
    this.accountProvider,
  });
  final CustomCourseEditArgs args;
  final CustomCourseStore? store;
  final String? Function()? accountProvider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final api = store ?? CustomCourseStore.instance;
    final initial = args.course;
    String? currentAccount() => accountProvider != null
        ? accountProvider!()
        : ApiClient.instance.studentId;
    final account = useMemoized(currentAccount);
    final id = useMemoized(() => initial?.id ?? CustomCourse.newId());
    final form = useMemoized(() => GlobalKey<FormState>());
    final name = useTextEditingController(text: initial?.name ?? '');
    final term = useTextEditingController(text: initial?.term ?? args.term);
    final teacher = useTextEditingController(text: initial?.teacher ?? '');
    final location = useTextEditingController(text: initial?.location ?? '');
    final remark = useTextEditingController(text: initial?.remark ?? '');
    final startWeek = useState(initial?.startWeek ?? 1);
    final endWeek = useState(initial?.endWeek ?? CustomCourse.maxWeek);
    final startClass = useState(initial?.startClass ?? 1);
    final endClass = useState(initial?.endClass ?? 2);
    final weekday = useState(initial?.weekday ?? 1);
    final parity = useState(
      initial == null || initial.single && initial.double
          ? 0
          : initial.single
          ? 1
          : 2,
    );
    final color = useState(initial?.color ?? _courseColors[2]);
    final busy = useState(false);
    final weekdays = _weekdays(l10n);

    Future<void> save() async {
      if (busy.value || !form.currentState!.validate()) return;
      if (account == null ||
          account != currentAccount() ||
          initial != null && initial.account != account) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.customCourseLoginRequired)));
        return;
      }
      if (endWeek.value < startWeek.value ||
          endClass.value < startClass.value) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.customCourseRangeInvalid)));
        return;
      }
      busy.value = true;
      try {
        final course = CustomCourse(
          id: id,
          account: account,
          term: term.text.trim(),
          name: name.text.trim(),
          teacher: teacher.text.trim(),
          location: location.text.trim(),
          remark: remark.text.trim(),
          startWeek: startWeek.value,
          endWeek: endWeek.value,
          startClass: startClass.value,
          endClass: endClass.value,
          weekday: weekday.value,
          single: parity.value != 2,
          double: parity.value != 1,
          color: color.value,
        );
        await api.load();
        if (!context.mounted || account != currentAccount()) return;
        await api.save(course, previous: initial);
        if (context.mounted) Navigator.of(context).pop();
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.toString())));
        }
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    Widget number(String label, ValueNotifier<int> state, int maximum) =>
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: state.value,
            decoration: InputDecoration(labelText: label),
            items: [
              for (var i = 1; i <= maximum; i++)
                DropdownMenuItem(value: i, child: Text('$i')),
            ],
            onChanged: busy.value
                ? null
                : (value) {
                    if (value != null) state.value = value;
                  },
          ),
        );

    return PopScope(
      canPop: !busy.value,
      child: AppScaffold(
        appBar: AppBar(
          title: Text(
            initial == null ? l10n.customCourseAdd : l10n.customCourseEdit,
          ),
        ),
        body: Form(
          key: form,
          child: AppListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              AppSection(
                title: l10n.customCourses,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: name,
                        enabled: !busy.value,
                        maxLength: 60,
                        decoration: InputDecoration(
                          labelText: l10n.customCourseName,
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? l10n.customCourseNameRequired
                            : null,
                      ),
                      TextFormField(
                        controller: term,
                        enabled: !busy.value,
                        maxLength: 6,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.selectSemester,
                          hintText: l10n.customCourseTermHint,
                        ),
                        validator: (value) =>
                            !RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                            ? l10n.customCourseTermInvalid
                            : null,
                      ),
                      TextFormField(
                        controller: teacher,
                        enabled: !busy.value,
                        maxLength: 100,
                        decoration: InputDecoration(
                          labelText: l10n.customCourseTeacher,
                        ),
                      ),
                      TextFormField(
                        controller: location,
                        enabled: !busy.value,
                        maxLength: 200,
                        decoration: InputDecoration(
                          labelText: l10n.customCourseLocation,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: weekday.value,
                        decoration: InputDecoration(
                          labelText: l10n.customCourseWeekday,
                        ),
                        items: [
                          for (var i = 1; i <= 7; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(weekdays[i - 1]),
                            ),
                        ],
                        onChanged: busy.value
                            ? null
                            : (value) {
                                if (value != null) weekday.value = value;
                              },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          number(
                            l10n.customCourseStartWeek,
                            startWeek,
                            CustomCourse.maxWeek,
                          ),
                          const SizedBox(width: 16),
                          number(
                            l10n.customCourseEndWeek,
                            endWeek,
                            CustomCourse.maxWeek,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: parity.value,
                        decoration: InputDecoration(
                          labelText: l10n.customCourseRepeat,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 0,
                            child: Text(l10n.customCourseEveryWeek),
                          ),
                          DropdownMenuItem(
                            value: 1,
                            child: Text(l10n.customCourseOddWeeks),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text(l10n.customCourseEvenWeeks),
                          ),
                        ],
                        onChanged: busy.value
                            ? null
                            : (value) {
                                if (value != null) parity.value = value;
                              },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          number(
                            l10n.startPeriod,
                            startClass,
                            CustomCourse.maxPeriod,
                          ),
                          const SizedBox(width: 16),
                          number(
                            l10n.endPeriod,
                            endClass,
                            CustomCourse.maxPeriod,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(l10n.customCourseColor),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final option in {..._courseColors, color.value})
                            IconButton(
                              tooltip:
                                  '${l10n.customCourseColor} ${option.toRadixString(16).substring(2)}',
                              onPressed: busy.value
                                  ? null
                                  : () => color.value = option,
                              icon: Icon(
                                color.value == option
                                    ? Icons.check_circle
                                    : Icons.circle,
                                color: Color(option),
                                size: 36,
                              ),
                            ),
                        ],
                      ),
                      TextFormField(
                        controller: remark,
                        enabled: !busy.value,
                        maxLength: 1000,
                        minLines: 2,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: l10n.customCourseRemark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: busy.value ? null : save,
                        icon: busy.value
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(l10n.customCourseSave),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
