#!/usr/bin/env bash
# The Definition of Done, as one command. Nothing merges to the v2 branch red.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> flutter analyze"
flutter analyze

echo "==> token contrast gate"
python3 tool/check_contrast.py

echo "==> tokens are in sync with design/tokens.json"
dart run tool/gen_tokens.dart >/dev/null
if ! git diff --quiet -- lib/core/theme/cove_tokens.dart; then
  echo "! cove_tokens.dart is stale or was hand-edited. Commit the regenerated file." >&2
  git --no-pager diff --stat -- lib/core/theme/cove_tokens.dart >&2
  exit 1
fi

echo "==> style ratchet"
dart run tool/style_gate.dart

echo "==> version strings agree"
dart run tool/check_version.dart

echo "==> tests (goldens included)"
flutter test

echo "all green"
