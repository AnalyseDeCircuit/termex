#!/usr/bin/env bash
# Checks that app_zh.arb and app_en.arb contain the same set of keys.
#
# Usage: bash scripts/check-arb-completeness.sh
# Exit code 0 = OK; exit code 1 = mismatch found.
set -euo pipefail

ZH="app/lib/l10n/app_zh.arb"
EN="app/lib/l10n/app_en.arb"

if [[ ! -f "$ZH" || ! -f "$EN" ]]; then
  echo "❌ ARB files not found. Run from the repository root." >&2
  exit 2
fi

# Extract top-level ARB keys (exactly 2-space indent, skip @meta lines).
extract_keys() {
  grep -E '^  "[a-zA-Z][^@"]' "$1" | grep -v '^  "@' | sed 's/^  "\([^"]*\)".*/\1/' | sort
}

ZH_KEYS=$(extract_keys "$ZH")
EN_KEYS=$(extract_keys "$EN")

ONLY_ZH=$(comm -23 <(echo "$ZH_KEYS") <(echo "$EN_KEYS"))
ONLY_EN=$(comm -13 <(echo "$ZH_KEYS") <(echo "$EN_KEYS"))

if [[ -z "$ONLY_ZH" && -z "$ONLY_EN" ]]; then
  echo "✅ ARB files are in sync ($(echo "$ZH_KEYS" | wc -l | tr -d ' ') keys each)."
  exit 0
fi

if [[ -n "$ONLY_ZH" ]]; then
  echo "❌ Keys in zh but NOT in en:" >&2
  echo "$ONLY_ZH" | sed 's/^/  /' >&2
fi

if [[ -n "$ONLY_EN" ]]; then
  echo "❌ Keys in en but NOT in zh:" >&2
  echo "$ONLY_EN" | sed 's/^/  /' >&2
fi

exit 1
