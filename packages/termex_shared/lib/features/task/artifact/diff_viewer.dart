/// Renders a [ParsedDiff] as a list of per-file expansion tiles.
library;

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../widgets/clickable.dart';
import 'parser/diff_parser.dart';

class DiffViewer extends StatelessWidget {
  final ParsedDiff diff;
  const DiffViewer({super.key, required this.diff});

  @override
  Widget build(BuildContext context) {
    if (diff.hunks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(TermexSpacing.md),
        child: Text(
          'No diff content',
          style: TermexTypography.body.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryHeader(diff: diff),
        for (var i = 0; i < diff.hunks.length; i++)
          _HunkTile(hunk: diff.hunks[i], initiallyExpanded: i < 2),
      ],
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final ParsedDiff diff;
  const _SummaryHeader({required this.diff});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.md,
        vertical: TermexSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            '${diff.filesChanged} files changed',
            style: TermexTypography.body.copyWith(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '+${diff.totalAdditions} ',
            style: TermexTypography.body.copyWith(color: context.colors.success),
          ),
          Text(
            '−${diff.totalDeletions}',
            style: TermexTypography.body.copyWith(color: context.colors.danger),
          ),
        ],
      ),
    );
  }
}

class _HunkTile extends StatefulWidget {
  final DiffHunk hunk;
  final bool initiallyExpanded;
  const _HunkTile({required this.hunk, required this.initiallyExpanded});

  @override
  State<_HunkTile> createState() => _HunkTileState();
}

class _HunkTileState extends State<_HunkTile> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.sm,
        vertical: TermexSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Clickable(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TermexSpacing.md,
                vertical: TermexSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    _expanded ? '▾' : '▸',
                    style: TermexTypography.body.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: TermexSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.hunk.filePath,
                      style: TermexTypography.monospace.copyWith(
                        color: context.colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '+${widget.hunk.additions} ',
                    style: TermexTypography.caption
                        .copyWith(color: context.colors.success),
                  ),
                  Text(
                    '−${widget.hunk.deletions}',
                    style: TermexTypography.caption
                        .copyWith(color: context.colors.danger),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(bottom: TermexSpacing.xs),
              child: Column(
                children: [
                  for (final line in widget.hunk.lines)
                    _DiffLineRow(line: line),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DiffLineRow extends StatelessWidget {
  final DiffLine line;
  const _DiffLineRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final bg = switch (line.kind) {
      DiffLineKind.add => context.colors.success.withValues(alpha: 0.10),
      DiffLineKind.del => context.colors.danger.withValues(alpha: 0.10),
      _ => null,
    };
    final prefix = switch (line.kind) {
      DiffLineKind.add => '+',
      DiffLineKind.del => '−',
      _ => ' ',
    };
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.sm,
        vertical: 1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              line.oldNum?.toString() ?? '',
              textAlign: TextAlign.right,
              style: TermexTypography.monospace.copyWith(
                color: context.colors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            child: Text(
              line.newNum?.toString() ?? '',
              textAlign: TextAlign.right,
              style: TermexTypography.monospace.copyWith(
                color: context.colors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            prefix,
            style: TermexTypography.monospace.copyWith(
              color: context.colors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              line.content,
              style: TermexTypography.monospace.copyWith(
                color: context.colors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
