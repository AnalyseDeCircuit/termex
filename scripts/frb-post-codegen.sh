#!/usr/bin/env bash
#
# Post-codegen cleanup — run after the first successful FRB codegen.
#
# Does:
#   1. Verifies generated files exist
#   2. Replaces the hand-written api.dart stub with a re-export of generated bindings
#   3. Runs flutter analyze + flutter test to catch contract mismatches
#   4. Reports remaining action items (usually small find-replace fixes)
#
# Usage:
#   ./scripts/frb-post-codegen.sh

set -euo pipefail

cd "$(dirname "$0")/.."

REPO_ROOT="$(pwd)"
GEN_DIR="$REPO_ROOT/app/lib/src/frb_generated"
STUB_API="$REPO_ROOT/crates/termex-flutter-bridge/lib/src/api.dart"
STUB_MODELS="$REPO_ROOT/crates/termex-flutter-bridge/lib/src/models.dart"

echo "▶ Step 1/4: Verify generated files"
if ! test -d "$GEN_DIR"; then
  echo "❌ Generated directory not found: $GEN_DIR"
  echo "   Run ./scripts/frb-codegen.sh first."
  exit 1
fi

if ! ls "$GEN_DIR"/*.dart >/dev/null 2>&1; then
  echo "❌ No .dart files in $GEN_DIR"
  exit 1
fi
echo "✅ Generated $(ls $GEN_DIR/*.dart | wc -l | tr -d ' ') Dart files"

echo ""
echo "▶ Step 2/4: Backup stub contracts"
cp "$STUB_API" "$STUB_API.pre-codegen.bak"
cp "$STUB_MODELS" "$STUB_MODELS.pre-codegen.bak"
echo "✅ Backed up to *.pre-codegen.bak"

echo ""
echo "▶ Step 3/4: Switch api.dart to re-export generated"
cat > "$STUB_API" << 'EOF'
/// Real FRB-generated bindings (was stub-only before v0.51.x codegen).
///
/// Original hand-written stubs preserved in api.dart.pre-codegen.bak
/// for reference during the transition.
export 'package:termex/src/frb_generated/frb_generated.dart';
EOF
echo "✅ api.dart now re-exports generated bindings"

echo ""
echo "▶ Step 4/4: Run Flutter analysis + test"
(
  cd app
  flutter pub get
  echo ""
  echo "── flutter analyze ──"
  if flutter analyze 2>&1 | tee /tmp/termex-analyze.log; then
    echo "✅ analyze clean"
  else
    echo "⚠️  analyze reported issues — likely signature mismatches between stub and generated"
    echo "   See /tmp/termex-analyze.log"
    echo "   Common fixes:"
    echo "     1. snake_case in stub → camelCase in generated (search/replace)"
    echo "     2. missing named-arg key (stub uses positional)"
    echo "     3. Sync vs async return (add/remove 'await')"
  fi

  echo ""
  echo "── flutter test ──"
  flutter test 2>&1 | tail -20
)

echo ""
echo "✅ Post-codegen cleanup done."
echo ""
echo "If flutter analyze reported issues, fix them per the common-fix hints above."
echo "If flutter analyze was clean, you're done — commit and push:"
echo "  git add app/lib/src/frb_generated crates/termex-flutter-bridge/include"
echo "  git add app/lib/src/api.dart crates/termex-flutter-bridge/lib/src/api.dart"
echo "  git commit -m 'feat(frb): first-time codegen + switch stubs to real bindings'"
