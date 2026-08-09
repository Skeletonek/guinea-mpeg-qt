#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/out/.build-generic"

NO_OBSOLETE=false
CLEAN=false
for arg in "$@"; do
    case "$arg" in
        --no-obsolete|-no-obsolete) NO_OBSOLETE=true ;;
        --clean) CLEAN=true ;;
        *)
            echo "Unknown argument: $arg" >&2
            echo "Usage: $0 [--no-obsolete] [--clean]" >&2
            exit 1 ;;
    esac
done

echo "=== Updating translation source strings (lupdate) ==="

if $CLEAN; then
    echo "  Mode: cleaning build directory"
    rm -rf "$BUILD_DIR"
fi
if $NO_OBSOLETE; then
    echo "  Mode: dropping obsolete/vanished entries (-no-obsolete)"
fi

CMAKE_FLAGS=(-DCMAKE_BUILD_TYPE=Release -DPACKAGE_TARGET=generic)
if $NO_OBSOLETE; then
    CMAKE_FLAGS+=(-DGUINEA_LUPDATE_NO_OBSOLETE=ON)
else
    CMAKE_FLAGS+=(-DGUINEA_LUPDATE_NO_OBSOLETE=OFF)
fi

cmake -S "$PROJECT_DIR" -B "$BUILD_DIR" "${CMAKE_FLAGS[@]}"

cmake --build "$BUILD_DIR" --target guinea_mpeg_lupdate

echo ""
echo "=== Translations updated ==="
echo "  Source: $PROJECT_DIR/translations/guinea-mpeg_pl_PL.ts"
echo "  Note: fill in any new <translation> entries, then build with:"
echo "        ./build/linux-build.sh"
