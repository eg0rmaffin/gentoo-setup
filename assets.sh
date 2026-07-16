#!/usr/bin/env bash
# Fetches the assets declared in the `assets` manifest.
#
#   idempotent    file present + hash ok -> no network at all
#   atomic        download to .part, rename only once the hash verifies
#   hash-as-truth mismatch -> discard, try the next mirror
#   non-fatal     a failed fetch warns loudly and never aborts install.sh
#
# No `set -e`: a dead mirror must not kill the run.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${ASSETS_MANIFEST:-$REPO/assets}"
DEST_ROOT="${ASSETS_HOME:-$HOME}"

info() { echo "assets: $*"; }
warn() { echo "assets: WARNING: $*" >&2; }

hash_of() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }

if [[ ! -f "$MANIFEST" ]]; then
    warn "no manifest at $MANIFEST, nothing to fetch"
    exit 0
fi

missing=()

while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue

    IFS='|' read -r sha dest urls <<< "$line"
    sha="${sha//[[:space:]]/}"
    dest="${dest//[[:space:]]/}"
    read -ra mirrors <<< "${urls:-}"

    if [[ ! "$sha" =~ ^[0-9a-f]{64}$ ]] || [[ -z "$dest" ]] || (( ${#mirrors[@]} == 0 )); then
        warn "skipping malformed entry: $line"
        continue
    fi
    # dest is joined onto $HOME: keep it there.
    if [[ "$dest" = /* ]] || [[ "$dest" == *..* ]]; then
        warn "skipping unsafe dest: $dest"
        continue
    fi

    target="$DEST_ROOT/$dest"

    if [[ -f "$target" ]]; then
        # The idempotent path: verified from disk, silent, zero network.
        [[ "$(hash_of "$target")" == "$sha" ]] && continue
        warn "$dest: local file does not match its hash, re-fetching"
        rm -f "$target"
    fi

    if ! mkdir -p "$(dirname "$target")"; then
        warn "$dest: cannot create destination directory"
        missing+=("$dest")
        continue
    fi

    part="$target.part"
    ok=0
    for url in "${mirrors[@]}"; do
        info "$dest: fetching from $url"
        rm -f "$part"
        if ! curl --fail --location --silent --show-error \
                  --connect-timeout 15 --retry 2 --output "$part" "$url"; then
            warn "$dest: download failed from $url"
            continue
        fi
        got="$(hash_of "$part")"
        if [[ "$got" == "$sha" ]]; then
            if mv -f "$part" "$target"; then
                info "$dest: ok"
                ok=1
                break
            fi
            warn "$dest: cannot install into place"
            continue
        fi
        warn "$dest: hash mismatch from $url (got ${got:-none}), discarded"
    done
    rm -f "$part"

    (( ok )) || missing+=("$dest")
done < "$MANIFEST"

if (( ${#missing[@]} )); then
    warn "could not fetch: ${missing[*]}"
    warn "no mirror served a file matching the declared hash — continuing anyway."
fi

exit 0
