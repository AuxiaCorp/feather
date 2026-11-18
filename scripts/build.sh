#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/bootstrap/feather-seed" "$ROOT/src/compiler.feather" "$ROOT/bin/feather.new"
chmod 755 "$ROOT/bin/feather.new"
cmp "$ROOT/bootstrap/feather-seed" "$ROOT/bin/feather.new" || { rm -f "$ROOT/bin/feather.new"; echo 'Self-hosting parity verification failed' >&2; exit 1; }
mv -f "$ROOT/bin/feather.new" "$ROOT/bin/feather"
"$ROOT/scripts/test.sh"
