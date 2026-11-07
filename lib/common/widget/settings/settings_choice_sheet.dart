import 'package:flutter/material.dart';
import 'package:fzu_assistant/common/widget/layout/app_section.dart';
import 'package:fzu_assistant/common/widget/sheet/app_bottom_sheet.dart';
import 'package:fzu_assistant/service/app_themes.dart';

class SettingsChoice<T> {
  const SettingsChoice({required this.value, required this.label, this.detail});

  final T value;
  final String label;
  final String? detail;
}

/// A single choice with native radio semantics and the app's shared insets.
Future<T?> showSettingsChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required T selected,
  required List<SettingsChoice<T>> choices,
}) => showAppBottomSheet<T>(
  context: context,
  backgroundColor: InterfaceTheme.of(context).style == InterfaceStyle.cards
      ? Theme.of(context).colorScheme.surface
      : null,
  builder: (sheetContext) => RadioGroup<T>(
    groupValue: selected,
    onChanged: (value) => Navigator.of(sheetContext).pop(value),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Text(
            title,
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
        ),
        AppSection.list(
          children: [
            for (final choice in choices)
              RadioListTile<T>(
                value: choice.value,
                title: Text(choice.label),
                subtitle: choice.detail == null ? null : Text(choice.detail!),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    ),
  ),
);
