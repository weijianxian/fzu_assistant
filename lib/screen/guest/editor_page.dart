import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

class EditorPage extends StatelessWidget {
  final String title;
  final String initialValue;
  final Future<bool> Function(String value) onSave;

  const EditorPage({
    super.key,
    required this.title,
    required this.initialValue,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final controller = CodeLineEditingController.fromText(initialValue);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.format_align_left),
            tooltip: 'Format JSON',
            onPressed: () {
              try {
                final obj = jsonDecode(controller.text);
                controller.text = const JsonEncoder.withIndent(
                  '  ',
                ).convert(obj);
              } catch (_) {}
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              final ok = await onSave(controller.text);
              if (context.mounted && ok) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: CodeEditor(
        controller: controller,
        style: CodeEditorStyle(
          codeTheme: CodeHighlightTheme(
            languages: {'json': CodeHighlightThemeMode(mode: langJson)},
            theme: atomOneLightTheme,
          ),
        ),
        wordWrap: false,
        indicatorBuilder:
            (context, editingController, chunkController, notifier) {
              return Row(
                children: [
                  DefaultCodeLineNumber(
                    controller: editingController,
                    notifier: notifier,
                  ),
                  DefaultCodeChunkIndicator(
                    width: 20,
                    controller: chunkController,
                    notifier: notifier,
                  ),
                ],
              );
            },
      ),
    );
  }
}
