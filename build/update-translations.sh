#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/out/.build-generic"

echo "=== Updating translation source strings (lupdate) ==="

if [ ! -f "$BUILD_DIR/CMakeCache.txt" ]; then
    echo "Configuring build directory..."
    cmake -S "$PROJECT_DIR" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release -DPACKAGE_TARGET=generic
fi

cmake --build "$BUILD_DIR" --target guinea_mpeg_lupdate

echo ""
echo "=== Translations updated ==="
echo "  Source: $PROJECT_DIR/translations/guinea-mpeg_pl_PL.ts"
echo "  Note: fill in any new <translation> entries, then build with:"
echo "        ./build/linux-build.sh"
