#!/usr/bin/env bash
# Run the full test suite: Rust core (cargo test), QML JS utilities and the
# C++ FFI smoke test (Qt Quick Test / Qt Test via ctest).
#
# Usage:
#   $0                    Run the full suite
#   $0 --clean            Remove out/.build-tests and rust/target first
#   $0 --help             Show this help message
set -euo pipefail

show_help() {
    cat <<EOF
Run the GuineaMPEG test suite: Rust core (cargo test), QML JS utilities and the
C++ FFI smoke test (Qt Quick Test / Qt Test via ctest).

Usage:
  $0                    Run the full suite
  $0 --clean            Remove out/.build-tests and rust/target first, then run everything fresh
  $0 --help             Show this help message
EOF
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT}/out/.build-tests"

DO_CLEAN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)
            DO_CLEAN=true; shift ;;
        --help)
            show_help
            exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run '$0 --help' for usage." >&2
            exit 1 ;;
    esac
done

if $DO_CLEAN; then
    echo "==> Cleaning test artifacts"
    rm -rf "$BUILD_DIR" "$ROOT/rust/target"
fi

echo "==> Rust core (cargo test)"
cargo test --manifest-path "${ROOT}/rust/Cargo.toml"

echo "==> C++/QML test targets"
cmake -S "${ROOT}" -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE=Debug -DPACKAGE_TARGET=generic >/dev/null
cmake --build "${BUILD_DIR}" --target tst_qml tst_backend_ffi >/dev/null

echo "==> ctest"
ctest --test-dir "${BUILD_DIR}" --output-on-failure