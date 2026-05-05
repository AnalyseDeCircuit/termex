import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import 'state/snippet_provider.dart';

class SnippetEditor extends ConsumerStatefulWidget {
  final Snippet? existing;
  const SnippetEditor({super.key, this.existing});

  @override
  ConsumerState<SnippetEditor> createState() => _SnippetEditorState();
}

class _SnippetEditorState extends ConsumerState<SnippetEditor> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _tagsCtrl;
  List<SnippetVariable> _vars = [];

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _titleCtrl = TextEditingController(text: s?.title ?? '');
    _contentCtrl = TextEditingController(text: s?.content ?? '');
    _tagsCtrl = TextEditingController(text: s?.tags.join(', ') ?? '');
    _vars = s?.variables ?? [];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  void _onContentChanged(String value) {
    setState(() => _vars = extractVariables(value));
  }

  List<String> get _tags => _tagsCtrl.text
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final notifier = ref.read(snippetProvider.notifier);
    if (widget.existing == null) {
      await notifier.create(_titleCtrl.text.trim(), _contentCtrl.text, _tags);
    } else {
      await notifier.update(widget.existing!.id, _titleCtrl.text.trim(), _contentCtrl.text, _tags);
    }
    notifier.setEditing(null);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TermexColors.backgroundPrimary,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title bar
          Row(
            children: [
              Text(
                widget.existing == null ? '新建 Snippet' : '编辑 Snippet',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: TermexColors.textPrimary),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => ref.read(snippetProvider.notifier).setEditing(null),
                child: Text('取消', style: TextStyle(fontSize: 12, color: TermexColors.textSecondary)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TermexColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(72, 32),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('保存'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Title
          _Label('标题'),
          const SizedBox(height: 4),
          TextField(
            controller: _titleCtrl,
            decoration: _dec('Snippet 名称'),
            style: TextStyle(fontSize: 13, color: TermexColors.textPrimary),
          ),
          const SizedBox(height: 12),
          // Tags
          _Label('标签（逗号分隔）'),
          const SizedBox(height: 4),
          TextField(
            controller: _tagsCtrl,
            decoration: _dec('ssh, 常用, docker'),
            style: TextStyle(fontSize: 13, color: TermexColors.textPrimary),
          ),
          const SizedBox(height: 12),
          // Content
          _Label('命令内容（使用 {{变量名:默认值}} 插入变量）'),
          const SizedBox(height: 4),
          Expanded(
            child: TextField(
              controller: _contentCtrl,
              onChanged: _onContentChanged,
              maxLines: null,
              expands: true,
              decoration: _dec('ssh -J {{bastion}} {{user}}@{{host}}').copyWith(
                alignLabelWithHint: true,
              ),
              style: TextStyle(
                fontSize: 13,
                color: TermexColors.textPrimary,
                fontFamily: 'monospace',
              ),
            ),
          ),
          // Variables preview
          if (_vars.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _vars.map((v) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: TermexColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: TermexColors.primary.withOpacity(0.3)),
                ),
                child: Text(
                  '{{${v.name}${v.defaultValue != null ? ":${v.defaultValue}" : ""}}}',
                  style: TextStyle(fontSize: 11, color: TermexColors.primary, fontFamily: 'monospace'),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: TermexColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: TermexColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: TermexColors.border),
        ),
        contentPadding: const EdgeInsets.all(10),
        isDense: true,
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(fontSize: 11, color: TermexColors.textSecondary),
      );
}
