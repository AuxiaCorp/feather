#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
install -d "$PREFIX/bin"
install -m 0755 "$ROOT/bin/feather" "$PREFIX/bin/feather"
printf 'Installed: %s/bin/feather\n' "$PREFIX"
