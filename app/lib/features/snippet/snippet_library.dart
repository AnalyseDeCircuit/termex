import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import 'snippet_editor.dart';
import 'snippet_row.dart';
import 'state/snippet_provider.dart';

class SnippetLibrary extends ConsumerStatefulWidget {
  final void Function(String command)? onExecute;
  const SnippetLibrary({super.key, this.onExecute});

  @override
  ConsumerState<SnippetLibrary> createState() => _SnippetLibraryState();
}

class _SnippetLibraryState extends ConsumerState<SnippetLibrary> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(snippetProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(snippetProvider);
    final editingId = state.editingId;

    if (editingId != null) {
      final existing = editingId == '__new__'
          ? null
          : state.snippets.firstWhere((s) => s.id == editingId, orElse: () => state.snippets.first);
      return SnippetEditor(existing: editingId == '__new__' ? null : existing);
    }

    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: TermexColors.border)),
          ),
          child: Row(
            children: [
              // Search
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: ref.read(snippetProvider.notifier).setSearch,
                  decoration: InputDecoration(
                    hintText: '搜索 snippet…',
                    hintStyle: TextStyle(fontSize: 12, color: TermexColors.textSecondary),
                    prefixIcon: Icon(Icons.search, size: 16, color: TermexColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: TermexColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: TermexColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: 12, color: TermexColors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => ref.read(snippetProvider.notifier).setEditing('__new__'),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('新建', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TermexColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(72, 32),
                ),
              ),
            ],
          ),
        ),
        // Tag filter
        if (state.allTags.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _TagFilter(tag: null, selected: state.selectedTag == null, label: '全部'),
                ...state.allTags.map((t) => _TagFilter(
                      tag: t,
                      selected: state.selectedTag == t,
                      label: t,
                    )),
              ],
            ),
          ),
        // List
        Expanded(
          child: state.isLoading
              ? Center(child: CircularProgressIndicator(color: TermexColors.primary))
              : state.filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.code_off, size: 36, color: TermexColors.textSecondary),
                          const SizedBox(height: 8),
                          Text('没有匹配的 Snippet',
                              style: TextStyle(fontSize: 12, color: TermexColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: state.filtered.length,
                      itemBuilder: (_, i) => SnippetRow(
                        snippet: state.filtered[i],
                        onExecute: widget.onExecute,
                      ),
                    ),
        ),
      ],
    );
  }
}

class _TagFilter extends ConsumerWidget {
  final String? tag;
  final bool selected;
  final String label;

  const _TagFilter({required this.tag, required this.selected, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(snippetProvider.notifier).setTag(tag),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? TermexColors.primary.withOpacity(0.12) : TermexColors.backgroundTertiary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? TermexColors.primary.withOpacity(0.4) : TermexColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? TermexColors.primary : TermexColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
