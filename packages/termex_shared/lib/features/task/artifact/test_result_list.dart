/// Renders test_results artifact: pass/fail/skipped chips + a
/// per-failure expansion list.
library;

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import 'test_results_parser.dart';

class TestResultList extends StatelessWidget {
  final TestResultsPayload payload;
  const TestResultList({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryRow(
          framework: payload.framework,
          summary: payload.summary,
        ),
        if (payload.failures.isNotEmpty) ...[
          const SizedBox(height: TermexSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TermexSpacing.md),
            child: Text(
              'Failures (${payload.failures.length})',
              style: TermexTypography.body.copyWith(
                color: TermexColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final f in payload.failures) _FailureCard(failure: f),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String framework;
  final TestSummary summary;

  const _SummaryRow({required this.framework, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TermexSpacing.md),
      child: Wrap(
        spacing: TermexSpacing.sm,
        runSpacing: TermexSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _StatChip(label: framework, color: TermexColors.textSecondary),
          _StatChip(
            label: '${summary.passed} passed',
            color: TermexColors.success,
          ),
          if (summary.failed > 0)
            _StatChip(
              label: '${summary.failed} failed',
              color: TermexColors.danger,
            ),
          if (summary.skipped > 0)
            _StatChip(
              label: '${summary.skipped} skipped',
              color: TermexColors.warning,
            ),
          if (summary.durationMs != null)
            _StatChip(
              label: _formatDuration(summary.durationMs!),
              color: TermexColors.textMuted,
            ),
        ],
      ),
    );
  }

  String _formatDuration(int ms) {
    if (ms < 1000) return '${ms}ms';
    return '${(ms / 1000).toStringAsFixed(1)}s';
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TermexTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  final TestFailure failure;
  const _FailureCard({required this.failure});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.sm,
        vertical: TermexSpacing.xs,
      ),
      padding: const EdgeInsets.all(TermexSpacing.sm),
      decoration: BoxDecoration(
        color: TermexColors.danger.withValues(alpha: 0.05),
        border: Border.all(color: TermexColors.danger.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            failure.testName,
            style: TermexTypography.body.copyWith(
              color: TermexColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (failure.file != null) ...[
            const SizedBox(height: 2),
            Text(
              failure.line != null
                  ? '${failure.file}:${failure.line}'
                  : failure.file!,
              style: TermexTypography.monospace.copyWith(
                color: TermexColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
          if (failure.message != null) ...[
            const SizedBox(height: TermexSpacing.xs),
            Text(
              failure.message!,
              style: TermexTypography.monospace.copyWith(
                color: TermexColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
