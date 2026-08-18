import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/dialog.dart';

import '../../design/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'state/snippet_provider.dart';

class SnippetEditor extends ConsumerStatefulWidget {
  final Snippet? existing;

  /// Set when hosted by [show]. The dialog paints its own title bar, and
  /// closing means popping the route rather than clearing the editing id.
  final bool inDialog;

  const SnippetEditor({super.key, this.existing, this.inDialog = false});

  /// Opens the editor as a modal, matching how servers and proxies add.
  ///
  /// It used to render inline, replacing the whole library panel. In the
  /// desktop sidebar that panel is ~300px wide, and the editor's title row
  /// (title + Cancel + Save, none of it flexible) could not fit, so creating
  /// a snippet painted a RenderFlex overflow instead of a form.
  static Future<void> show(BuildContext context, {Snippet? existing}) {
    final l10n = AppLocalizations.of(context);
    return showTermexDialog<void>(
      context: context,
      title: existing == null ? l10n.snippetNewTitle : l10n.snippetEditSnippet,
      size: DialogSize.medium,
      body: SnippetEditor(existing: existing, inDialog: true),
    );
  }

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
      await notifier.update(widget.existing!.id, _titleCtrl.text.trim(),
          _contentCtrl.text, _tags);
    }
    _close();
  }

  /// Inline hosting clears the editing id; the modal pops itself.
  void _close() {
    if (widget.inDialog) {
      Navigator.of(context).pop();
    } else {
      ref.read(snippetProvider.notifier).setEditing(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The editor is built from Material widgets (TextField, TextButton,
    // ElevatedButton) but neither host guarantees a Material ancestor: the
    // sidebar paints on plain widgets, and showTermexDialog builds its own
    // chrome. Without this the form threw "No Material widget found" and
    // rendered a red error box instead — which is what clicking "+" showed.
    return Material(
      color: context.colors.backgroundPrimary,
      child: SizedBox(
        // The content field is Expanded, which needs a bounded height. Inline
        // the panel supplies one; the dialog does not, so state it here.
        height: widget.inDialog ? 460 : null,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title bar
              Row(
                children: [
                  if (!widget.inDialog)
                    Flexible(
                      child: Text(
                        widget.existing == null
                            ? l10n.snippetNewTitle
                            : l10n.snippetEditSnippet,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _close,
                    child: Text(l10n.commonCancel,
                        style: TextStyle(
                            fontSize: 12, color: context.colors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(72, 32),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: Text(l10n.commonSave),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Title
              _Label(l10n.snippetTitleLabel),
              const SizedBox(height: 4),
              TextField(
                controller: _titleCtrl,
                decoration: _dec(l10n.snippetNamePlaceholder),
                style: TextStyle(
                    fontSize: 13, color: context.colors.textPrimary),
              ),
              const SizedBox(height: 12),
              // Tags
              _Label(l10n.snippetTagsCommaLabel),
              const SizedBox(height: 4),
              TextField(
                controller: _tagsCtrl,
                decoration: _dec(l10n.snippetTagsPlaceholderExample),
                style: TextStyle(
                    fontSize: 13, color: context.colors.textPrimary),
              ),
              const SizedBox(height: 12),
              // Content
              _Label(l10n.snippetContentLabel),
              const SizedBox(height: 4),
              Expanded(
                child: TextField(
                  controller: _contentCtrl,
                  onChanged: _onContentChanged,
                  maxLines: null,
                  expands: true,
                  decoration:
                      _dec('ssh -J {{bastion}} {{user}}@{{host}}').copyWith(
                    alignLabelWithHint: true,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textPrimary,
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
                  children: _vars
                      .map((v) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: context.colors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color:
                                      context.colors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '{{${v.name}${v.defaultValue != null ? ":${v.defaultValue}" : ""}}}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: context.colors.primary,
                                  fontFamily: 'monospace'),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(fontSize: 12, color: context.colors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: context.colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: context.colors.border),
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
        style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
      );
}
