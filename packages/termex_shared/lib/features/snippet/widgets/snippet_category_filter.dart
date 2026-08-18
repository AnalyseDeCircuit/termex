/// Multi-select category (tag) filter for the snippet panel.
///
/// Lives beside the "Snippet" title in the host's section header rather than
/// on a row of its own. The panel used to spend a full 28pt line on a
/// horizontally-scrolling chip strip — in a 240pt sidebar that pushed the
/// first snippet down without earning the space, and it only ever allowed one
/// category at a time.
///
/// Shared by both hosts so desktop and mobile stay in parity: the desktop
/// sidebar mounts it in `_CategorySectionHeader`, mobile in
/// `_TerminalTabHeader`. It renders nothing at all when no snippet carries a
/// tag, so a fresh install shows no dead control.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/colors.dart';
import '../../../icons/termex_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/clickable.dart';
import '../../../widgets/menu.dart';
import '../state/snippet_provider.dart';

class SnippetCategoryFilter extends ConsumerWidget {
  const SnippetCategoryFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(snippetProvider);
    final tags = state.allTags;
    if (tags.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final selected = state.selectedTags;
    final active = selected.isNotEmpty;

    final label = switch (selected.length) {
      0 => l10n.snippetCategoryFilter,
      1 => selected.first,
      _ => l10n.snippetCategoryCount(selected.length),
    };

    return Clickable(
      onTap: () => _open(context, ref, tags, selected),
      child: Container(
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: active
              ? context.colors.primary.withOpacity(0.12)
              : context.colors.backgroundTertiary,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active
                ? context.colors.primary.withOpacity(0.4)
                : context.colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Constrained so a long category name truncates instead of
            // squeezing the search / add buttons out of a narrow sidebar.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 84),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  color: active
                      ? context.colors.primary
                      : context.colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 2),
            TermexIconWidget(
              TermexIcons.chevronDown,
              size: 11,
              color:
                  active ? context.colors.primary : context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _open(
    BuildContext context,
    WidgetRef ref,
    List<String> tags,
    Set<String> selected,
  ) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(snippetProvider.notifier);

    // Anchored to the control's bottom-left so the menu drops beneath the
    // chip rather than landing under the pointer.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? Offset.zero
        : box.localToGlobal(Offset(0, box.size.height + 2));

    showContextMenu(
      context: context,
      position: origin,
      items: [
        MenuItem(
          label: l10n.snippetCategoryAll,
          icon: _tick(context, selected.isEmpty),
          onSelected: notifier.clearTags,
        ),
        const MenuItem.separator(),
        for (final tag in tags)
          MenuItem(
            label: tag,
            icon: _tick(context, selected.contains(tag)),
            onSelected: () => notifier.toggleTag(tag),
          ),
      ],
    );
  }

  /// A checkmark for ticked entries and an equally-sized blank for the rest,
  /// so labels stay aligned down the menu.
  Widget _tick(BuildContext context, bool on) => SizedBox(
        width: 13,
        height: 13,
        child: on
            ? TermexIconWidget(
                TermexIcons.check,
                size: 13,
                color: context.colors.primary,
              )
            : null,
      );
}
