#!/bin/bash
#
# Uploads one or more local artifacts (matched by a glob) to a Filen.io
# directory. Usage: filen-upload.sh <local-glob> <cloud-dir>
#
set -euo pipefail

GLOB="${1:?usage: filen-upload.sh <local-glob> <cloud-dir>}"
CLOUD_DIR="${2:?usage: filen-upload.sh <local-glob> <cloud-dir>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/filen-common.sh"

install_filen
restore_auth_config

shopt -s nullglob
files=( $GLOB )
if [ "${#files[@]}" -eq 0 ]; then
    echo "No files match: $GLOB" >&2
    exit 1
fi

# mkdir is idempotent and harmless when the folder already exists.
filen --quiet --no-autocomplete mkdir "$CLOUD_DIR" >/dev/null 2>&1 || true

for f in "${files[@]}"; do
    filen --quiet --no-autocomplete upload "$f" "$CLOUD_DIR"
    echo "Uploaded $(basename "$f") -> $CLOUD_DIR"
done