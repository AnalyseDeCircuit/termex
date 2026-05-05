import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import 'state/snippet_provider.dart';

/// Shows a dialog to fill in snippet variables and returns the resolved content,
/// or null if the user cancels.
Future<String?> resolveSnippetVariables(BuildContext context, Snippet snippet) async {
  if (snippet.variables.isEmpty) return snippet.content;

  return showDialog<String>(
    context: context,
    builder: (_) => _VariableResolverDialog(snippet: snippet),
  );
}

class _VariableResolverDialog extends StatefulWidget {
  final Snippet snippet;
  const _VariableResolverDialog({required this.snippet});

  @override
  State<_VariableResolverDialog> createState() => _VariableResolverDialogState();
}

class _VariableResolverDialogState extends State<_VariableResolverDialog> {
  late final Map<String, TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final v in widget.snippet.variables)
        v.name: TextEditingController(text: v.defaultValue ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _preview() {
    final values = {for (final e in _ctrls.entries) e.key: e.value.text};
    return resolveSnippet(widget.snippet.content, values);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TermexColors.backgroundSecondary,
      title: Text('填写变量 — ${widget.snippet.title}',
          style: TextStyle(fontSize: 14, color: TermexColors.textPrimary)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...widget.snippet.variables.map((v) => _VarField(variable: v, controller: _ctrls[v.name]!,
                  onChanged: (_) => setState(() {}))),
              const SizedBox(height: 16),
              Text('预览', style: TextStyle(fontSize: 11, color: TermexColors.textSecondary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TermexColors.backgroundTertiary,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: TermexColors.border),
                ),
                child: SelectableText(
                  _preview(),
                  style: TextStyle(fontSize: 12, color: TermexColors.textPrimary, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消', style: TextStyle(fontSize: 12, color: TermexColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _preview()),
          style: ElevatedButton.styleFrom(
            backgroundColor: TermexColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(80, 32),
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: const Text('确认执行'),
        ),
      ],
    );
  }
}

class _VarField extends StatelessWidget {
  final SnippetVariable variable;
  final TextEditingController controller;
  final void Function(String) onChanged;

  const _VarField({
    required this.variable,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(variable.name,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TermexColors.textPrimary)),
              if (variable.defaultValue != null) ...[
                const SizedBox(width: 6),
                Text('默认: ${variable.defaultValue}',
                    style: TextStyle(fontSize: 10, color: TermexColors.textSecondary)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: variable.defaultValue ?? '请输入值',
              hintStyle: TextStyle(fontSize: 12, color: TermexColors.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: TermexColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: TermexColors.border),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
            style: TextStyle(fontSize: 12, color: TermexColors.textPrimary, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
