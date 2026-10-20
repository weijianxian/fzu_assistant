import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fzu_assistant/l10n/app_localizations.dart';

class PasswordField extends HookWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final obscure = useState(true);
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure.value,
      autofillHints: const [AutofillHints.password],
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.password,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure.value ? Icons.visibility_off : Icons.visibility),
          onPressed: enabled ? () => obscure.value = !obscure.value : null,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
