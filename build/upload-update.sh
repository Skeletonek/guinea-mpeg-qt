#!/bin/bash
# Variables:
#   UPDATE_RSYNC_TARGET  - rsync destination, e.g. "user@server.com:/var/www/guinea-mpeg/"
#   UPDATE_SSH_KEY       - path to an existing SSH private key
#   UPDATE_SSH_PORT      - SSH port (default 22)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SOURCE_FILE="${1:-$PROJECT_DIR/update.toml}"

UPDATE_RSYNC_TARGET="${UPDATE_RSYNC_TARGET:-}"
UPDATE_SSH_KEY="${UPDATE_SSH_KEY:-}"
UPDATE_SSH_PORT="${UPDATE_SSH_PORT:-22}"

if [ ! -f "$SOURCE_FILE" ]; then
    echo "ERROR: update metadata not found: $SOURCE_FILE" >&2
    exit 1
fi

SSH_OPTS="-p '$UPDATE_SSH_PORT'"
if [ -n "$UPDATE_SSH_KEY" ]; then
    SSH_OPTS="-i '$UPDATE_SSH_KEY' $SSH_OPTS"
fi

rsync -az --chmod=644 --itemize-changes -e "ssh $SSH_OPTS" \
    "$SOURCE_FILE" "$UPDATE_RSYNC_TARGET"
echo "Uploaded update metadata to $UPDATE_RSYNC_TARGET"
