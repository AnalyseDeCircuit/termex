import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:termex_shared/design/colors.dart';
import 'package:termex_shared/design/spacing.dart';
import 'package:termex_shared/design/typography.dart';
import 'package:termex_shared/features/tabs/state/tab_controller.dart';
import 'package:termex_shared/widgets/dialog.dart';
import 'package:termex_shared/widgets/text_field.dart';
import 'cross_tab_search.dart';

/// Cmd+Shift+F search across every open tab's scrollback buffer.
///
/// Tauri parity: src/components/terminal/CrossTabSearchDialog.vue. The
/// query field is debounced to keep large scrollbacks responsive; tapping
/// a hit row activates the source tab.
class CrossTabSearchDialog extends ConsumerStatefulWidget {
  const CrossTabSearchDialog({super.key});

  static Future<void> show(BuildContext context) =>
      showTermexDialog<void>(
        context: context,
        title: 'Search across tabs',
        size: DialogSize.large,
        body: const CrossTabSearchDialog(),
      );

  @override
  ConsumerState<CrossTabSearchDialog> createState() =>
      _CrossTabSearchDialogState();
}

class _CrossTabSearchDialogState extends ConsumerState<CrossTabSearchDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    ref.read(crossTabSearchProvider.notifier).search(q);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(crossTabSearchProvider);

    return SizedBox(
      width: 720,
      height: 460,
      child: Padding(
        padding: const EdgeInsets.all(TermexSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TermexTextField(
              controller: _ctrl,
              autofocus: true,
              placeholder: 'Type to search every open tab\'s scrollback…',
              onChanged: _onChanged,
            ),
            const SizedBox(height: TermexSpacing.md),
            Expanded(
              child: state.query.isEmpty
                  ? const _Empty(message: 'Start typing to search.')
                  : state.results.isEmpty
                      ? _Empty(
                          message: state.isSearching
                              ? 'Searching…'
                              : 'No matches in any open tab.')
                      : _ResultList(results: state.results),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String message;
  const _Empty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: TermexTypography.body.copyWith(color: TermexColors.textMuted),
      ),
    );
  }
}

class _ResultList extends ConsumerWidget {
  final List<TabSearchResult> results;
  const _ResultList({required this.results});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (ctx, i) {
        final r = results[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: TermexSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${r.serverName}  ·  ${r.count} match${r.count == 1 ? '' : 'es'}',
                style: TermexTypography.body.copyWith(
                  color: TermexColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: TermexSpacing.xs),
              for (final m in r.matches.take(20))
                _MatchRow(match: m, onActivate: () {
                  ref.read(activeTabIdProvider.notifier).state = r.tabId;
                  Navigator.of(context, rootNavigator: true).pop();
                }),
              if (r.matches.length > 20)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '… ${r.matches.length - 20} more',
                    style: TermexTypography.caption.copyWith(
                      color: TermexColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MatchRow extends StatefulWidget {
  final CrossTabMatch match;
  final VoidCallback onActivate;
  const _MatchRow({required this.match, required this.onActivate});

  @override
  State<_MatchRow> createState() => _MatchRowState();
}

class _MatchRowState extends State<_MatchRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onActivate,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TermexSpacing.sm,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: _hovered ? TermexColors.backgroundTertiary : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  'L${widget.match.lineNumber}',
                  style: TermexTypography.caption.copyWith(
                    color: TermexColors.textMuted,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  widget.match.linePreview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TermexTypography.monospace.copyWith(
                    color: TermexColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
