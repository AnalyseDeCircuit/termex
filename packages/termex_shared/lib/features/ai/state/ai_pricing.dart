/// Static AI-provider pricing table for cost estimation (v0.79.50).
///
/// Each entry is `(inputUsdPerMTokens, outputUsdPerMTokens)`. Lookup is by
/// case-insensitive **prefix** match against the model string —
/// `claude-opus-4-8-20251020` resolves through `claude-opus-4` prefix,
/// `gpt-4o-mini-2024-07-18` through `gpt-4o-mini`, etc. This lets a
/// single table entry cover dated snapshots without exact-match
/// maintenance per release.
///
/// **Limitations**
/// - Vendor pricing changes monthly; this table is a 2026-Q2 snapshot
///   and SHOULD be updated periodically (track `_kPricingLastUpdatedIso`
///   in CHANGELOG when refreshed).
/// - Unknown providers / models return `null` → caller falls back to
///   the tokens-only ARB variant. Failing soft is intentional:
///   showing a wrong cost is worse than showing none.
/// - Ollama / LocalLlama always return `0.0` (self-hosted = no marginal
///   $ — power / GPU depreciation is out of scope).
library;

/// When the table was last refreshed against vendor docs. Update + add
/// a note in the v0.x.x iteration doc whenever you sweep prices.
const String kPricingLastUpdatedIso = '2026-06-08';

/// Default staleness threshold for the pricing snapshot — beyond this
/// many days from [kPricingLastUpdatedIso], the table is "stale" and a
/// maintenance refresh is due. 90d = roughly one quarter, matching how
/// often the major vendors tend to revise rates.
const int kPricingStaleAfterDays = 90;

/// Internal pair (input rate, output rate) per 1M tokens, in USD.
class _Rate {
  final double inputPerM;
  final double outputPerM;
  const _Rate(this.inputPerM, this.outputPerM);
}

/// Per-prefix pricing. Order matters for ambiguous prefixes — keep more
/// specific keys above their shorter siblings (e.g. `gpt-4o-mini` above
/// `gpt-4o`).
const Map<String, _Rate> _kPricing = {
  // Anthropic
  'claude-opus-4': _Rate(15.0, 75.0),
  'claude-sonnet-4': _Rate(3.0, 15.0),
  'claude-haiku-4': _Rate(0.80, 4.0),
  'claude-3-opus': _Rate(15.0, 75.0),
  'claude-3-5-sonnet': _Rate(3.0, 15.0),
  'claude-3-5-haiku': _Rate(0.80, 4.0),
  // OpenAI — reasoning families first (more specific prefixes win
  // over the bare gpt-4 family below).
  'o3-mini': _Rate(1.10, 4.40),
  'o3': _Rate(15.0, 60.0),
  'o1-mini': _Rate(1.10, 4.40),
  'o1-preview': _Rate(15.0, 60.0),
  'o1': _Rate(15.0, 60.0),
  // OpenAI — chat families. Specific suffixes before shorter siblings.
  'gpt-4o-mini': _Rate(0.15, 0.60),
  'gpt-4o': _Rate(2.50, 10.0),
  'gpt-4-turbo': _Rate(10.0, 30.0),
  'gpt-4': _Rate(30.0, 60.0),
  'gpt-3.5-turbo': _Rate(0.50, 1.50),
  // Google
  'gemini-2.0-flash': _Rate(0.075, 0.30),
  'gemini-1.5-pro': _Rate(1.25, 5.0),
  'gemini-1.5-flash': _Rate(0.075, 0.30),
  // xAI (Grok)
  'grok-3-mini': _Rate(0.30, 0.50),
  'grok-3': _Rate(3.0, 15.0),
  'grok-2': _Rate(2.0, 10.0),
  // Mistral
  'mistral-large': _Rate(2.0, 6.0),
  'mistral-small': _Rate(0.20, 0.60),
  'mistral-nemo': _Rate(0.15, 0.15),
  'codestral': _Rate(0.30, 0.90),
  // Open-weight via API
  'deepseek-v3': _Rate(0.27, 1.10),
  'deepseek-r1': _Rate(0.55, 2.19),
  // v0.79.63: 阿里云百炼 / 通义千问 (DashScope) — CNY-native pricing
  // (¥/M tokens), converted at ~7 RMB/USD as an approximation. Real
  // billing happens on DashScope's side in CNY; these USD estimates
  // are only for the in-app cost summary. Treat as ±15% accuracy.
  //   qwen-max:        ¥20/¥60 → ~$2.86/$8.57
  //   qwen-plus:       ¥0.8/¥2 → ~$0.114/$0.286
  //   qwen-turbo:      ¥0.3/¥0.6 → ~$0.043/$0.086
  //   qwen-long:       ¥0.5/¥2 → ~$0.071/$0.286
  //   qwen3-coder:     ¥4/¥16 → ~$0.57/$2.29
  //   qwen2.5-coder:   ¥3.5/¥7 → ~$0.50/$1.00
  'qwen-max': _Rate(2.86, 8.57),
  'qwen-plus': _Rate(0.114, 0.286),
  'qwen-turbo': _Rate(0.043, 0.086),
  'qwen-long': _Rate(0.071, 0.286),
  'qwen3-coder': _Rate(0.57, 2.29),
  'qwen2.5-coder': _Rate(0.50, 1.00),
  'qwen2.5': _Rate(0.50, 1.00), // generic fallback for qwen2.5-* variants
  // China-native vendors (GLM / MiniMax / Doubao) priced in CNY and
  // deferred to the CNY-display iteration. Until then, returning null
  // (unknown) keeps the summary honest rather than guessing a USD rate.
  // Local — self-hosted = no marginal cost
  'llama': _Rate(0.0, 0.0),
};

/// Returns the USD cost of a generation, or `null` if [model] isn't
/// priced in [_kPricing]. Tokens of `0` collapse the corresponding term;
/// pass `null` for either token count to treat as 0. Pass
/// `isSelfHosted: true` for Ollama / LocalLlama — those always return
/// `0.0` regardless of model.
///
/// Provider is not passed as an enum so this function can live in
/// `termex_shared` without dragging the bridge-dependent
/// `conversation_provider` import into the shared test setup.
double? estimateCostUsd({
  required String model,
  int? tokensIn,
  int? tokensOut,
  bool isSelfHosted = false,
}) {
  // Self-hosted providers never reach the priced table.
  if (isSelfHosted) return 0.0;
  final m = model.toLowerCase();
  for (final entry in _kPricing.entries) {
    if (m.startsWith(entry.key)) {
      final inTok = tokensIn ?? 0;
      final outTok = tokensOut ?? 0;
      return (inTok * entry.value.inputPerM +
              outTok * entry.value.outputPerM) /
          1000000.0;
    }
  }
  return null;
}

/// Returns true when the snapshot at [kPricingLastUpdatedIso] is older
/// than [thresholdDays] (default: [kPricingStaleAfterDays]). Accepts
/// an optional [now] for deterministic tests; production callers should
/// pass nothing and let it default to wall-clock time.
///
/// Use this from a startup diagnostic / settings panel to surface
/// "AI pricing table last refreshed YYYY-MM-DD (stale — please update)"
/// — silently letting the table drift causes wrong cost summaries.
bool isPricingStale({int thresholdDays = kPricingStaleAfterDays, DateTime? now}) {
  final updated = DateTime.tryParse(kPricingLastUpdatedIso);
  if (updated == null) return true; // malformed constant → fail loud
  final reference = now ?? DateTime.now();
  return reference.difference(updated).inDays > thresholdDays;
}

/// Returns the days since [kPricingLastUpdatedIso]. Negative if the
/// constant is set to a future date (treated as a bug). Mirrors
/// [isPricingStale]'s [now] override for test determinism.
int pricingAgeDays({DateTime? now}) {
  final updated = DateTime.tryParse(kPricingLastUpdatedIso);
  if (updated == null) return -1;
  final reference = now ?? DateTime.now();
  return reference.difference(updated).inDays;
}

/// Formats a USD cost with adaptive precision:
/// - `< 0.001` → `<$0.001` (sub-millicent costs aren't worth a long fraction)
/// - `< 1`     → 4 significant figures (e.g. `$0.0023`)
/// - `>= 1`    → 2 decimal places (e.g. `$1.23` or `$12.34`)
String formatCostUsd(double cost) {
  if (cost <= 0) return '\$0';
  if (cost < 0.001) return '<\$0.001';
  if (cost < 1) {
    // 3 sig figs via toStringAsPrecision — covers $0.001..$0.999. Trim
    // trailing zeros after the decimal but keep at least one decimal
    // digit so "$1.0" doesn't collapse into a misleading "$1" when
    // the true value is e.g. 0.999. Precision=3 was chosen over 2 so
    // 0.999 stays visibly < $1 instead of rounding up to "1.0" and
    // then being trimmed.
    var s = cost.toStringAsPrecision(3);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s += '0'; // keep "1.0" rather than "1"
    }
    return '\$$s';
  }
  return '\$${cost.toStringAsFixed(2)}';
}
