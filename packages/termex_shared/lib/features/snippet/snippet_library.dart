import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sidebar_search.dart';

import '../../design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/clickable.dart';
import 'snippet_editor.dart';
import 'snippet_row.dart';
import 'state/snippet_provider.dart';

class SnippetLibrary extends ConsumerStatefulWidget {
  final void Function(String command)? onExecute;
  const SnippetLibrary({super.key, this.onExecute});

  /// v0.79.59: open the snippet editor in "new" mode. Public so a host
  /// shell's nav-bar "+" button can trigger snippet creation without
  /// having to keep an inline button inside the library toolbar.
  static void startNew(WidgetRef ref) {
    ref.read(snippetProvider.notifier).setEditing('__new__');
  }

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
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(snippetProvider);
    final editingId = state.editingId;

    if (editingId != null) {
      final existing = editingId == '__new__'
          ? null
          : state.snippets.firstWhere((s) => s.id == editingId, orElse: () => state.snippets.first);
      return SnippetEditor(existing: editingId == '__new__' ? null : existing);
    }

    ref.listen<bool>(
      sidebarSearchVisibleProvider(SidebarSearchPanel.snippets),
      (_, visible) {
        // Dropping the field has to drop the filter with it, or entries stay
        // missing with nothing on screen explaining why.
        if (!visible) {
          _searchCtrl.clear();
          ref.read(snippetProvider.notifier).setSearch('');
        }
      },
    );

    return Column(
      children: [
        // v0.79.59: toolbar slimmed down. The inline "+ 新建" elevated
        // button next to the search field was redundant (host shells
        // now paint a top-right "+" in their nav bar — see mobile
        // `_TerminalTabHeader`'s `onAdd: () => SnippetLibrary.startNew`),
        // and forced the search field into a 32pt min-height column.
        // Removing it lets the search field collapse to its natural
        // ~32pt and reclaims the right-side real estate.
        // Behind the section-header search toggle — the field used to sit
        // here permanently, which made a short snippet list look busier
        // than it is. Hiding it also clears the query below.
        if (ref.watch(
            sidebarSearchVisibleProvider(SidebarSearchPanel.snippets)))
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: TermexColors.border)),
            ),
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: ref.read(snippetProvider.notifier).setSearch,
                decoration: InputDecoration(
                  hintText: l10n.snippetSearchPlaceholder,
                  hintStyle: const TextStyle(fontSize: 12, color: TermexColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, size: 14, color: TermexColors.textSecondary),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: TermexColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: TermexColors.border),
                  ),
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12, color: TermexColors.textPrimary),
              ),
            ),
          ),
        // v0.79.59: tightened tag-filter row. The previous 36pt SizedBox
        // with vertical:6 padding rendered a visually-tall band with a
        // disproportionate gap before the first row (~140pt total). The
        // chip itself is ~22pt — 28pt SizedBox + symmetric padding 3 is
        // enough to host it without floating in dead space.
        if (state.allTags.isNotEmpty)
          SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              children: [
                _TagFilter(tag: null, selected: state.selectedTag == null, label: l10n.snippetAllFolder),
                ...state.allTags.map((t) => _TagFilter(
                      tag: t,
                      selected: state.selectedTag == t,
                      label: t,
                    )),
              ],
            ),
          ),
        // List
        //
        // v0.79.60: `MediaQuery.removePadding(removeTop: true)` wrapping
        // the ListView fixes the empty band that sat above the first
        // snippet on iPhone 17 Pro. Even though `MobileShell` already
        // consumed `MediaQuery.padding.top` via a SizedBox spacer, the
        // unmodified MediaQuery still propagated to children — and a
        // nested vertical ListView with `primary: true` (default) reads
        // that top inset and re-applies it as scroll-content padding.
        // Result: ~59pt double-padding showing as dead space between
        // the tag-chip row and the first snippet row.
        //
        // Two-belt-one-suspender fix: (a) strip inherited top padding
        // via `MediaQuery.removePadding`, and (b) force `primary: false
        // + padding: EdgeInsets.zero` on the ListView so we never
        // depend on inherited insets again.
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator(color: TermexColors.primary))
              : state.filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.code_off, size: 36, color: TermexColors.textSecondary),
                          const SizedBox(height: 8),
                          Text(l10n.snippetNoMatch,
                              style: const TextStyle(fontSize: 12, color: TermexColors.textSecondary)),
                        ],
                      ),
                    )
                  : MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: ListView.builder(
                        primary: false,
                        padding: EdgeInsets.zero,
                        itemCount: state.filtered.length,
                        itemBuilder: (_, i) => SnippetRow(
                          snippet: state.filtered[i],
                          onExecute: widget.onExecute,
                        ),
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
    return Clickable(
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
