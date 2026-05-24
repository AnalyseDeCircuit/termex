import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/cost/model/cost_view_model.dart';

void main() {
  group('CostKindVM.parse', () {
    test('maps known kinds', () {
      expect(CostKindVM.parse('primary_ai_call'), CostKindVM.primaryAiCall);
      expect(CostKindVM.parse('streaming_summary'), CostKindVM.streamingSummary);
      expect(CostKindVM.parse('tool_use'), CostKindVM.toolUse);
    });
    test('falls back to primaryAiCall for unknown input', () {
      expect(CostKindVM.parse('nonsense'), CostKindVM.primaryAiCall);
    });
  });

  group('formatUsd', () {
    test('renders zero as \$0.00', () {
      expect(formatUsd(0), '\$0.00');
    });
    test('uses 4 decimals for dust amounts', () {
      expect(formatUsd(0.0005), '\$0.0005');
    });
    test('uses 3 decimals for sub-dollar amounts', () {
      expect(formatUsd(0.123), '\$0.123');
    });
    test('uses 2 decimals for larger amounts', () {
      expect(formatUsd(12.345), '\$12.35');
    });
  });

  group('formatTokens', () {
    test('returns raw count under 1k', () {
      expect(formatTokens(999), '999');
    });
    test('K suffix for thousands', () {
      expect(formatTokens(8400), '8.4K');
    });
    test('M suffix for millions', () {
      expect(formatTokens(1500000), '1.50M');
    });
  });

  group('UserCostCapVM', () {
    test('isUnlimited when all caps null', () {
      expect(const UserCostCapVM().isUnlimited, isTrue);
    });
    test('not unlimited when any cap set', () {
      expect(const UserCostCapVM(monthlyUsd: 10).isUnlimited, isFalse);
    });
    test('copyWith preserves unchanged fields', () {
      const orig = UserCostCapVM(monthlyUsd: 10, singleTaskUsd: 1);
      final next = orig.copyWith(perServerUsd: 5.0);
      expect(next.monthlyUsd, 10);
      expect(next.singleTaskUsd, 1);
      expect(next.perServerUsd, 5.0);
    });
    test('copyWith can clear a field to null', () {
      const orig = UserCostCapVM(monthlyUsd: 10);
      final next = orig.copyWith(monthlyUsd: null);
      expect(next.monthlyUsd, isNull);
    });
  });

  group('CostSummaryVM.empty', () {
    test('initializes all aggregates to zero', () {
      final s = CostSummaryVM.empty('This month');
      expect(s.totalUsd, 0);
      expect(s.taskCount, 0);
      expect(s.byServer, isEmpty);
      expect(s.topTasks, isEmpty);
    });
  });
}
