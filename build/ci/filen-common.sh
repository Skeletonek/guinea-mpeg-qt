#!/bin/bash
#
# Shared helpers for the Woodpecker CI steps that talk to Filen.io via the
# classic filen-cli v0.0.36 (the only release that ships the `links` command).
# Glibc-only pkg binary: run inside a Debian image, never Alpine.
#
set -euo pipefail

FILEN_VERSION="0.0.36"
FILEN_BIN="/usr/local/bin/filen"
FILEN_URL="https://github.com/FilenCloudDienste/filen-cli/releases/download/v${FILEN_VERSION}/filen-cli-v${FILEN_VERSION}-linux-x64"

install_filen() {
    if [ ! -x "$FILEN_BIN" ]; then
        curl -fsSL -o /tmp/filen "$FILEN_URL"
        chmod +x /tmp/filen
        mv /tmp/filen "$FILEN_BIN"
    fi
}

restore_auth_config() {
    : "${FILEN_AUTH_CONFIG_B64:?FILEN_AUTH_CONFIG_B64 secret is not set}"
    printf '%s' "$FILEN_AUTH_CONFIG_B64" | base64 -d > .filen-cli-auth-config
    chmod 600 .filen-cli-auth-config
}