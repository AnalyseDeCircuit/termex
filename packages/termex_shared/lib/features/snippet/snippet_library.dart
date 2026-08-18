import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sidebar_search.dart';

import '../../design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../icons/termex_icons.dart';
import '../../widgets/menu.dart';
import '../../widgets/panel_context_menu.dart';
import 'snippet_editor.dart';
import 'snippet_row.dart';
import 'state/snippet_provider.dart';

class SnippetLibrary extends ConsumerStatefulWidget {
  final void Function(String command)? onExecute;
  const SnippetLibrary({super.key, this.onExecute});

  /// Opens the snippet editor in "new" mode. Public so a host shell's
  /// nav-bar "+" button can trigger snippet creation without keeping an
  /// inline button inside the library toolbar.
  ///
  /// Presents a modal rather than swapping the panel's contents: the desktop
  /// sidebar is ~300px wide and the editor's action row does not fit there,
  /// and servers/proxies already add through dialogs.
  static void startNew(BuildContext context) {
    SnippetEditor.show(context);
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

    if (editingId != null && editingId != '__new__') {
      // firstWhere's orElse used to fall back to `snippets.first`, which
      // throws on an empty list — reachable whenever an edit id outlives the
      // entry it points at.
      final existing =
          state.snippets.where((s) => s.id == editingId).firstOrNull;
      if (existing != null) return SnippetEditor(existing: existing);
      // Stale id: drop it and fall through to the list.
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(snippetProvider.notifier).setEditing(null));
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (d) => _showPanelMenu(context, d.globalPosition),
      child: Column(
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
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.colors.border)),
            ),
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: ref.read(snippetProvider.notifier).setSearch,
                decoration: InputDecoration(
                  hintText: l10n.snippetSearchPlaceholder,
                  hintStyle: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                  prefixIcon: Icon(Icons.search, size: 14, color: context.colors.textSecondary),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
              ),
            ),
          ),
        // The tag filter no longer lives here. It used to be a 28pt
        // horizontally-scrolling chip strip on its own row, which in a 240pt
        // sidebar cost a full line to show one control and only allowed one
        // category at a time. It is now `SnippetCategoryFilter`, a
        // multi-select dropdown mounted next to the "Snippet" title in each
        // host's section header (desktop `_CategorySectionHeader`, mobile
        // `_TerminalTabHeader`).
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
              ? Center(child: CircularProgressIndicator(color: context.colors.primary))
              : state.filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.code_off, size: 36, color: context.colors.textSecondary),
                          const SizedBox(height: 8),
                          Text(l10n.snippetNoMatch,
                              style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
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
      ),
    );
  }

  /// Blank-area menu: what applies to the library as a whole.
  void _showPanelMenu(BuildContext context, Offset position) {
    final l10n = AppLocalizations.of(context);
    final state = ref.read(snippetProvider);
    showContextMenu(
      context: context,
      position: position,
      items: [
        MenuItem(
          label: l10n.snippetCreate,
          icon: menuIcon(context, TermexIcons.add),
          onSelected: () => SnippetLibrary.startNew(context),
        ),
        if (state.selectedTags.isNotEmpty) ...[
          const MenuItem.separator(),
          MenuItem(
            label: l10n.snippetCategoryAll,
            icon: menuIcon(context, TermexIcons.close),
            onSelected: ref.read(snippetProvider.notifier).clearTags,
          ),
        ],
      ],
    );
  }
}

