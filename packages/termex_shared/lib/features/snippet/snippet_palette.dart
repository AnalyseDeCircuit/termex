import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../widgets/dialog.dart';
import '../../widgets/text_field.dart';
import '../tabs/state/tab_controller.dart';
import '../server_list/state/connection_provider.dart';
import 'state/snippet_provider.dart';

/// Cmd+Shift+S quick palette.
///
/// Mirrors the Tauri SnippetPalette.vue: fuzzy filter, ↑/↓ to move
/// selection, Enter to inject the resolved snippet content into the
/// active tab's terminal stdin. ESC dismisses.
class SnippetPalette extends ConsumerStatefulWidget {
  const SnippetPalette({super.key});

  static Future<void> show(BuildContext context) =>
      showTermexDialog<void>(
        context: context,
        title: '插入命令片段',
        size: DialogSize.medium,
        body: const SnippetPalette(),
      );

  @override
  ConsumerState<SnippetPalette> createState() => _SnippetPaletteState();
}

class _SnippetPaletteState extends ConsumerState<SnippetPalette> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  int _highlight = 0;

  @override
  void initState() {
    super.initState();
    // Trigger an initial load if the snippet store is empty so the palette
    // has something to show on first open.
    Future.microtask(() {
      final state = ref.read(snippetProvider);
      if (state.snippets.isEmpty && !state.isLoading) {
        ref.read(snippetProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<Snippet> _candidates() {
    final state = ref.read(snippetProvider);
    final q = _ctrl.text.trim().toLowerCase();
    if (q.isEmpty) return state.snippets;
    return state.snippets
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.content.toLowerCase().contains(q) ||
            s.tags.any((t) => t.toLowerCase().contains(q)))
        .toList();
  }

  void _inject(Snippet snippet) {
    final activeTabId = ref.read(activeTabIdProvider);
    if (activeTabId == null) {
      _close();
      return;
    }
    final sessionId = ref.read(connectionProvider(activeTabId)).sessionId;
    if (sessionId == null) {
      _close();
      return;
    }
    // Ship the content as-is (variable resolution UI is the SnippetForm
    // dialog's job; the palette is for known/no-var snippets).
    bridge
        .writeStdin(sessionId: sessionId, data: utf8.encode(snippet.content))
        .catchError((_) {});
    _close();
  }

  void _close() {
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final candidates = _candidates();
    if (candidates.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() =>
          _highlight = (_highlight + 1).clamp(0, candidates.length - 1));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() =>
          _highlight = (_highlight - 1).clamp(0, candidates.length - 1));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _inject(candidates[_highlight]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates();
    if (_highlight >= candidates.length) _highlight = 0;

    return SizedBox(
      width: 560,
      height: 420,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Padding(
          padding: const EdgeInsets.all(TermexSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TermexTextField(
                controller: _ctrl,
                placeholder: 'Type to filter snippets…',
                autofocus: true,
                onChanged: (_) => setState(() => _highlight = 0),
              ),
              const SizedBox(height: TermexSpacing.md),
              Expanded(
                child: candidates.isEmpty
                    ? Center(
                        child: Text(
                          'No snippets match.',
                          style: TermexTypography.body.copyWith(
                            color: TermexColors.textMuted,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: candidates.length,
                        itemBuilder: (ctx, i) => _SnippetRow(
                          snippet: candidates[i],
                          highlighted: i == _highlight,
                          onTap: () => _inject(candidates[i]),
                          onHover: () => setState(() => _highlight = i),
                        ),
                      ),
              ),
              const SizedBox(height: TermexSpacing.sm),
              Text(
                '↑/↓ to move · Enter to insert · Esc to close',
                style: TermexTypography.caption.copyWith(
                  color: TermexColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnippetRow extends StatelessWidget {
  final Snippet snippet;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback onHover;

  const _SnippetRow({
    required this.snippet,
    required this.highlighted,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TermexSpacing.sm,
            vertical: TermexSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: highlighted
                ? TermexColors.primary.withOpacity(0.10)
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                snippet.title,
                style: TermexTypography.body.copyWith(
                  color: TermexColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                snippet.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TermexTypography.monospace.copyWith(
                  color: TermexColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
