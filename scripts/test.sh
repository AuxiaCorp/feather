#!/usr/bin/env bash
set -euo pipefail
LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEED="$ROOT/bootstrap/feather-seed"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ok=0
pass() { printf 'PASS %s\n' "$1"; ok=$((ok+1)); }
failtest() { echo "FAIL $1" >&2; exit 1; }
expect_reject() {
  local name="$1"; shift
  printf '%s' "$1" > "$TMP/$name.feather"
  if "$TMP/stage2" "$TMP/$name.feather" "$TMP/$name.fthr" >"$TMP/$name.stdout" 2>"$TMP/$name.stderr"; then
    failtest "$name unexpectedly accepted"
  fi
  test ! -e "$TMP/$name.fthr" || failtest "$name produced a binary despite error"
  pass "reject $name"
}
[ -x "$SEED" ] || failtest 'seed missing or not executable'
! find "$ROOT" \( -name '*.rs' -o -name Cargo.toml -o -name Cargo.lock \) | grep -q . || failtest 'Rust source/build file in tree'
pass 'no Rust source or Cargo files'
"$SEED" "$ROOT/src/compiler.feather" "$TMP/stage1"
cmp -s "$SEED" "$TMP/stage1" || failtest 'seed != stage1'
pass 'seed -> compiler.feather -> stage1 (byte-identical)'
"$TMP/stage1" "$ROOT/src/compiler.feather" "$TMP/stage2"
cmp -s "$TMP/stage1" "$TMP/stage2" || failtest 'stage1 != stage2'
pass 'stage1 -> compiler.feather -> stage2 (byte-identical)'
"$TMP/stage2" "$ROOT/src/compiler.feather" "$TMP/stage3"
cmp -s "$TMP/stage2" "$TMP/stage3" || failtest 'stage2 != stage3'
pass 'stage2 -> compiler.feather -> stage3 (byte-identical)'

for example in hello control math buffer; do
  "$TMP/stage3" "$ROOT/examples/$example.feather" "$TMP/$example.fthr"
  chmod +x "$TMP/$example.fthr"
  "$TMP/$example.fthr" > "$TMP/$example.actual"
  cmp -s "$ROOT/tests/$example.stdout" "$TMP/$example.actual" || failtest "$example output mismatch"
  pass "compile + run $example"
done

"$TMP/stage3" "$ROOT/examples/copy-file.feather" "$TMP/copy-file.fthr"
printf '\000\001Feather\377Binary\000End' > "$TMP/input.bin"
"$TMP/copy-file.fthr" "$TMP/input.bin" "$TMP/output.bin"
cmp -s "$TMP/input.bin" "$TMP/output.bin" || failtest 'binary file data differs'
pass 'native file read/write and binary round trip'
if "$TMP/copy-file.fthr" "$TMP/nonexistent" "$TMP/should-not-exist"; then failtest 'missing source accepted'; fi
[ ! -e "$TMP/should-not-exist" ] || failtest 'unexpected output on failed read'
pass 'native I/O error propagation'

expect_reject bad-mode $'WRONG\nquit.script\n'
expect_reject missing-quit $'#terminal-only\nsay"Hello"\n'
expect_reject extra-after-quit $'#terminal-only\nquit.script\nsay"later"\n'
expect_reject malformed-hex $'#terminal-only\nset r01=1234567890abcdefg\nquit.script\n'
expect_reject unmatched-close $'#terminal-only\n]\nquit.script\n'
expect_reject unmatched-open $'#terminal-only\nset r01=0000000000000000\nwhen r01==r01 [\nquit.script\n'
expect_reject missing-quote $'#terminal-only\nsay true\nquit.script\n'
expect_reject broken-append $'#terminal-only\nset r01=0000000000000000\nappend r01="ABC"\nquit.script\n'
expect_reject unknown-op $'#terminal-only\nfoobar r01\nquit.script\n'
expect_reject no-final-newline $'#terminal-only\nquit.script'

if command -v readelf >/dev/null 2>&1; then
  readelf -h "$TMP/stage3" | grep -q 'Machine:.*Advanced Micro Devices X86-64' || failtest 'wrong ELF machine'
  readelf -l "$TMP/stage3" | grep -q 'GNU_STACK' || failtest 'no GNU_STACK program header'
  readelf -l "$TMP/stage3" | grep 'GNU_STACK' -A1 | grep -q ' RW ' || failtest 'stack not marked NX'
  pass 'ELF machine and non-executable stack'
fi
printf 'PASS total: %d checks\n' "$ok"
sha256sum "$SEED" "$TMP/stage1" "$TMP/stage2" "$TMP/stage3"
