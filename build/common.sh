#!/usr/bin/env bash
# Shared helpers for build scripts (version, project root, arch mapping).
# Source via: source "$(dirname "$0")/common.sh"

get_project_root() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$(cd "$script_dir/.." && pwd)"
}

get_version() {
    local root="$1"
    root="${root:-$(get_project_root)}"
    grep -m1 '^version = ' "$root/rust/Cargo.toml" | sed -E 's/.*\"([^\"]+)\".*/\1/'
}

get_out_dir() {
    local root="$1"
    root="${root:-$(get_project_root)}"
    echo "$root/out"
}

# Arch helpers for docker cross builds
docker_arch_for() {
    case "$1" in aarch64) echo "arm64" ;; *) echo "$1" ;; esac
}
binfmt_arch_for() {
    case "$1" in aarch64) echo "aarch64" ;; *) echo "$1" ;; esac
}
