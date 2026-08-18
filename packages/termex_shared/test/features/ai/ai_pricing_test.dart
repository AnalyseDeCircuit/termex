/// Unit tests for [estimateCostUsd] + [formatCostUsd] (v0.79.50).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/ai/state/ai_pricing.dart';

void main() {
  group('estimateCostUsd — known models', () {
    test('Claude Sonnet 4.5 priced via prefix', () {
      // claude-sonnet-4 prefix: $3 in / $15 out per 1M tokens.
      // 1000 in + 1000 out → $0.003 + $0.015 = $0.018
      final c = estimateCostUsd(
        model: 'claude-sonnet-4-5-20251020',
        tokensIn: 1000,
        tokensOut: 1000,
      );
      expect(c, closeTo(0.018, 1e-9));
    });

    test('GPT-4o-mini priced (cheaper than gpt-4o)', () {
      // gpt-4o-mini matches before gpt-4o due to entry order.
      // $0.15 / $0.60 per 1M.
      final c = estimateCostUsd(
        // provider hidden in v0.79.50: API uses isSelfHosted bool
        model: 'gpt-4o-mini-2024-07-18',
        tokensIn: 1000000,
        tokensOut: 100000,
      );
      expect(c, closeTo(0.15 + 0.06, 1e-9)); // $0.21
    });

    test('GPT-4o (without -mini suffix) priced separately', () {
      final c = estimateCostUsd(
        // provider hidden in v0.79.50: API uses isSelfHosted bool
        model: 'gpt-4o-2024-11-20',
        tokensIn: 1000,
        tokensOut: 1000,
      );
      // $2.50 / $10.00 per 1M → $0.0025 + $0.01 = $0.0125
      expect(c, closeTo(0.0125, 1e-9));
    });

    test('Gemini 2.0 Flash priced', () {
      final c = estimateCostUsd(
        // provider hidden in v0.79.50: API uses isSelfHosted bool
        model: 'gemini-2.0-flash',
        tokensIn: 1000000,
        tokensOut: 1000000,
      );
      expect(c, closeTo(0.075 + 0.30, 1e-9)); // $0.375
    });

    test('DeepSeek V3 priced', () {
      final c = estimateCostUsd(
        // provider hidden in v0.79.50: API uses isSelfHosted bool
        model: 'deepseek-v3',
        tokensIn: 1000000,
        tokensOut: 0,
      );
      expect(c, closeTo(0.27, 1e-9));
    });
  });

  group('estimateCostUsd — self-hosted', () {
    test('Ollama always returns 0', () {
      final c = estimateCostUsd(
        isSelfHosted: true,
        model: 'llama3:8b',
        tokensIn: 999999999,
        tokensOut: 999999999,
      );
      expect(c, 0.0);
    });

    test('LocalLlama always returns 0', () {
      final c = estimateCostUsd(
        isSelfHosted: true,
        model: 'qwen-2.5-coder-32b',
        tokensIn: 1000,
        tokensOut: 1000,
      );
      expect(c, 0.0);
    });
  });

  group('estimateCostUsd — unknown / missing', () {
    test('unknown model returns null', () {
      expect(
        estimateCostUsd(
          // provider hidden in v0.79.50: API uses isSelfHosted bool
          model: 'made-up-model-xyz',
          tokensIn: 1000,
          tokensOut: 1000,
        ),
        isNull,
      );
    });

    test('null tokens treated as 0', () {
      expect(
        estimateCostUsd(
          // provider hidden in v0.79.50: API uses isSelfHosted bool
          model: 'claude-sonnet-4-5',
          tokensIn: null,
          tokensOut: null,
        ),
        0.0,
      );
    });

    test('case-insensitive prefix match', () {
      final c = estimateCostUsd(
        // provider hidden in v0.79.50: API uses isSelfHosted bool
        model: 'CLAUDE-OPUS-4-8',
        tokensIn: 1000,
        tokensOut: 1000,
      );
      expect(c, closeTo(0.015 + 0.075, 1e-9)); // $15 + $75 per 1M
    });
  });

  group('estimateCostUsd — extended vendors (v0.79.51)', () {
    test('Grok-3 priced (\$3 / \$15 per 1M)', () {
      final c = estimateCostUsd(
        model: 'grok-3',
        tokensIn: 1000000,
        tokensOut: 1000000,
      );
      expect(c, closeTo(3.0 + 15.0, 1e-9));
    });

    test('Grok-3-mini cheaper than Grok-3 via more-specific prefix', () {
      final c = estimateCostUsd(
        model: 'grok-3-mini-2025',
        tokensIn: 1000000,
        tokensOut: 1000000,
      );
      expect(c, closeTo(0.30 + 0.50, 1e-9));
    });

    test('Mistral Large priced', () {
      final c = estimateCostUsd(
        model: 'mistral-large-2407',
        tokensIn: 1000000,
        tokensOut: 1000000,
      );
      expect(c, closeTo(2.0 + 6.0, 1e-9));
    });

    test('Mistral Small priced (more specific than mistral-large)', () {
      final c = estimateCostUsd(
        model: 'mistral-small-2501',
        tokensIn: 1000000,
        tokensOut: 0,
      );
      expect(c, closeTo(0.20, 1e-9));
    });

    test('OpenAI o3 reasoning model priced', () {
      final c = estimateCostUsd(
        model: 'o3-2026-01-01',
        tokensIn: 1000,
        tokensOut: 1000,
      );
      expect(c, closeTo(0.015 + 0.060, 1e-9));
    });

    test('OpenAI o3-mini cheaper via more-specific prefix', () {
      final c = estimateCostUsd(
        model: 'o3-mini',
        tokensIn: 1000000,
        tokensOut: 0,
      );
      expect(c, closeTo(1.10, 1e-9));
    });

    test('China-native vendors (GLM/MiniMax/Doubao) intentionally unknown', () {
      // Deferred to CNY-display iteration — until then null keeps the
      // summary honest rather than guessing a USD rate.
      expect(estimateCostUsd(model: 'glm-4-plus', tokensIn: 1, tokensOut: 1), isNull);
      expect(estimateCostUsd(model: 'abab6.5-chat', tokensIn: 1, tokensOut: 1), isNull);
      expect(estimateCostUsd(model: 'doubao-pro-32k', tokensIn: 1, tokensOut: 1), isNull);
    });
  });

  group('isPricingStale / pricingAgeDays', () {
    test('fresh snapshot is not stale (1 day after)', () {
      final updated = DateTime.parse(kPricingLastUpdatedIso);
      final fresh = updated.add(const Duration(days: 1));
      expect(isPricingStale(now: fresh), isFalse);
      expect(pricingAgeDays(now: fresh), 1);
    });

    test('snapshot just under threshold is not stale', () {
      final updated = DateTime.parse(kPricingLastUpdatedIso);
      final justUnder = updated.add(const Duration(days: kPricingStaleAfterDays));
      expect(isPricingStale(now: justUnder), isFalse);
    });

    test('snapshot past threshold is stale', () {
      final updated = DateTime.parse(kPricingLastUpdatedIso);
      final past = updated.add(const Duration(days: kPricingStaleAfterDays + 1));
      expect(isPricingStale(now: past), isTrue);
    });

    test('custom thresholdDays honored', () {
      final updated = DateTime.parse(kPricingLastUpdatedIso);
      final tenDaysLater = updated.add(const Duration(days: 10));
      expect(isPricingStale(thresholdDays: 5, now: tenDaysLater), isTrue);
      expect(isPricingStale(thresholdDays: 30, now: tenDaysLater), isFalse);
    });

    test('pricingAgeDays sane for a future "now"', () {
      final updated = DateTime.parse(kPricingLastUpdatedIso);
      final future = updated.add(const Duration(days: 42));
      expect(pricingAgeDays(now: future), 42);
    });
  });

  group('formatCostUsd', () {
    test('zero / negative renders as \$0', () {
      expect(formatCostUsd(0), '\$0');
      expect(formatCostUsd(-1), '\$0');
    });

    test('sub-millicent renders as <\$0.001', () {
      expect(formatCostUsd(0.0001), '<\$0.001');
      expect(formatCostUsd(0.0009), '<\$0.001');
    });

    test('sub-dollar uses 3 sig figs (trailing zeros trimmed)', () {
      expect(formatCostUsd(0.0023), '\$0.0023');
      expect(formatCostUsd(0.018), '\$0.018');
      expect(formatCostUsd(0.5), '\$0.5');
    });

    test('1+ dollar uses 2 decimals', () {
      expect(formatCostUsd(1), '\$1.00');
      expect(formatCostUsd(12.345), '\$12.35');
    });

    test('0.999 stays sub-dollar (3 sig fig rounding)', () {
      // 3 sig figs preserves precision so 0.999 doesn't visually round
      // to "1.0" then trim to a misleading "$1".
      expect(formatCostUsd(0.999), '\$0.999');
    });
  });
}
