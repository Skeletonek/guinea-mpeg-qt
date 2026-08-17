#!/bin/bash
#
# Prints the release summary with public Filen.io links for the artifacts
# uploaded by the appimage and windows workflows. Runs as the last CI job.
#
# `filen links` is interactive but idempotent: piping a newline dismisses the
# prompt and re-prints the already-existing link if present.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/filen-common.sh"

install_filen
restore_auth_config

VERSION="$(grep '^version = ' rust/Cargo.toml | head -1 | sed -E 's/^version = "([^"]+)"/\1/')"
if [ -z "$VERSION" ]; then
    echo "Could not parse version from rust/Cargo.toml" >&2
    exit 1
fi

DIR="/Shared/apps/guinea-mpeg"

fetch_link() {
    local cloud_path="$1"
    local out
    out="$(printf '\n' | filen --quiet --no-autocomplete links "$cloud_path" 2>/dev/null || true)"
    grep -o 'https://drive\.filen\.io/[^[:space:]]*' <<<"$out" | head -1 || true
}

APPIMAGE="$(fetch_link "$DIR/guinea-mpeg-${VERSION}-x86_64.AppImage")"
ZIP="$(fetch_link "$DIR/guinea-mpeg-${VERSION}-x86_64.zip")"
EXE="$(fetch_link "$DIR/guinea-mpeg-${VERSION}-x86_64.exe")"

sep="$(printf '=%.0s' {1..72})"
printf '%s\n' "$sep"
printf '  GuineaMPEG v%s - release artifacts\n' "$VERSION"
printf '%s\n' "$sep"
printf '  %-30s %s\n' "Linux AppImage (x86_64):" "${APPIMAGE:-<missing>}"
printf '  %-30s %s\n' "Windows portable ZIP (x86_64):" "${ZIP:-<missing>}"
printf '  %-30s %s\n' "Windows installer (x86_64):" "${EXE:-<missing>}"
printf '%s\n' "$sep"