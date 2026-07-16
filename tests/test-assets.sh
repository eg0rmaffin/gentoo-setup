#!/usr/bin/env bash
# Tests assets.sh against its acceptance criteria, using file:// mirrors and a
# throwaway $HOME — no network, no Gentoo, runs anywhere bash + curl exist.
#
#     ./tests/test-assets.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0 fail=0
ok()  { echo "  ok: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1"; fail=$((fail + 1)); }
check() { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

# --- fixtures ---
GOOD="$TMP/mirror/good.bin"
CORRUPT="$TMP/mirror/corrupt.bin"
mkdir -p "$TMP/mirror"
printf 'the real payload' > "$GOOD"
printf 'not the payload!' > "$CORRUPT"
SHA="$(sha256sum "$GOOD" | cut -d' ' -f1)"

DEST="games/doom/test.wad"
export ASSETS_HOME="$TMP/home"
TARGET="$ASSETS_HOME/$DEST"

manifest() { printf '%s\n' "$@" > "$TMP/manifest"; }
run() { ASSETS_MANIFEST="$TMP/manifest" "$REPO/assets.sh" >"$TMP/out" 2>"$TMP/err"; echo $?; }

echo "assets.sh"

# --- first run fetches ---
manifest "# comment line" "$SHA | $DEST | file://$GOOD"
check "first run exits 0" "$(run)" "0"
if [[ -f "$TARGET" ]]; then ok "first run fetches the file"; else bad "first run fetches the file"; fi
check "fetched content verifies" "$(sha256sum "$TARGET" | cut -d' ' -f1)" "$SHA"

# --- second run is offline-silent ---
# Every mirror is now a URL that cannot resolve: any network attempt shows up
# as a warning, so silence here proves the cached file was trusted from disk.
manifest "$SHA | $DEST | file://$TMP/does-not-exist"
check "second run exits 0" "$(run)" "0"
check "second run prints nothing" "$(cat "$TMP/out" "$TMP/err")" ""

# --- a corrupted local file is re-fetched ---
printf 'corrupted on disk' > "$TARGET"
manifest "$SHA | $DEST | file://$GOOD"
check "corrupt local exits 0" "$(run)" "0"
check "corrupt local is re-fetched" "$(sha256sum "$TARGET" | cut -d' ' -f1)" "$SHA"
if grep -q "does not match its hash" "$TMP/err"; then ok "corrupt local warns"; else bad "corrupt local warns"; fi

# --- hash-as-truth: a bad mirror is discarded, the next one is used ---
rm -f "$TARGET"
manifest "$SHA | $DEST | file://$CORRUPT file://$GOOD"
check "bad primary exits 0" "$(run)" "0"
check "falls through to a good mirror" "$(sha256sum "$TARGET" | cut -d' ' -f1)" "$SHA"
if grep -q "hash mismatch" "$TMP/err"; then ok "bad mirror warns"; else bad "bad mirror warns"; fi

# --- total failure: loud, non-fatal, leaves nothing behind ---
rm -f "$TARGET"
manifest "$SHA | $DEST | file://$CORRUPT file://$TMP/does-not-exist"
check "total failure still exits 0" "$(run)" "0"
if [[ ! -e "$TARGET" ]]; then ok "no unverified file is installed"; else bad "no unverified file is installed"; fi
if [[ ! -e "$TARGET.part" ]]; then ok "no .part is left behind"; else bad "no .part is left behind"; fi
if grep -q "could not fetch" "$TMP/err"; then ok "total failure warns loudly"; else bad "total failure warns loudly"; fi

# --- malformed and unsafe entries are skipped, not obeyed ---
manifest "deadbeef | $DEST | file://$GOOD"
run >/dev/null
if grep -q "malformed" "$TMP/err"; then ok "short hash rejected"; else bad "short hash rejected"; fi

manifest "$SHA | ../escape.bin | file://$GOOD"
run >/dev/null
if grep -q "unsafe dest" "$TMP/err"; then ok "path traversal rejected"; else bad "path traversal rejected"; fi
if [[ ! -e "$TMP/escape.bin" ]]; then ok "nothing written outside \$HOME"; else bad "nothing written outside \$HOME"; fi

echo
echo "$pass passed, $fail failed"
(( fail == 0 ))
