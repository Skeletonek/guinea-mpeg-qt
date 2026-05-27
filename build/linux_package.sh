#!/bin/bash
set -euo pipefail

# Package build script for GuineaMPEG
# Produces .deb, .rpm, .pkg.tar.zst (pacman) artifacts in out/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUT_DIR="$PROJECT_DIR/out"

VERSION="${1:-0.2.0}"
ARCH="$(uname -m)"
PKGNAME="guinea-mpeg"
DESCRIPTION="FFmpeg GUI Frontend with Rust Core"

# Build the project first (cmake outputs to out/)
echo "=== Building GuineaMPEG $VERSION ==="
cmake --build "$PROJECT_DIR/out" --target appguinea_mpeg 2>/dev/null || {
    echo "Run 'cmake -S . -B out && cmake --build out' manually first, or press enter..."
    read -r
    cmake -S "$PROJECT_DIR" -B "$PROJECT_DIR/out"
    cmake --build "$PROJECT_DIR/out"
}

mkdir -p "$OUT_DIR"

# Staging directory
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

BINDIR="$STAGING/usr/bin"
LIBDIR="$STAGING/usr/lib/$PKGNAME"
APPDIR="$STAGING/usr/share/applications"
ICONDIR="$STAGING/usr/share/icons/hicolor"
DATADIR="$STAGING/usr/share/$PKGNAME"

mkdir -p "$BINDIR" "$LIBDIR" "$APPDIR" "$DATADIR"

# Copy binary
install -m755 "$PROJECT_DIR/out/appguinea_mpeg" "$BINDIR/$PKGNAME"

# Copy Rust library
install -m644 "$PROJECT_DIR/rust/target/release/libguinea_mpeg_core.so" "$LIBDIR/"

# Copy default profiles
install -m644 "$PROJECT_DIR/default_profiles.toml" "$DATADIR/"

# Copy desktop entry
install -m644 "$PROJECT_DIR/build/linux/applications/$PKGNAME.desktop" "$APPDIR/"

# Copy pre-built PNG icons
cp -r "$PROJECT_DIR/build/linux/icons/hicolor" "$ICONDIR/"

# Build packages using fpm
if ! command -v fpm &>/dev/null; then
    echo "ERROR: fpm not found. Install it: gem install fpm"
    echo "Staging directory left at: $STAGING"
    exit 1
fi

echo "=== Building .deb ==="
fpm -s dir -t deb \
    -n "$PKGNAME" \
    -v "$VERSION" \
    -a "$ARCH" \
    --description "$DESCRIPTION" \
    --license "MIT" \
    --vendor "skeletonek" \
    --maintainer "skeletonek" \
    --url "https://github.com/skeletonek/guinea-mpeg" \
    --depends "ffmpeg" \
    --depends "libmpv2" \
    -C "$STAGING" \
    -p "$OUT_DIR/${PKGNAME}_${VERSION}_${ARCH}.deb" \
    usr/

echo "=== Building .rpm ==="
fpm -s dir -t rpm \
    -n "$PKGNAME" \
    -v "$VERSION" \
    -a "$ARCH" \
    --description "$DESCRIPTION" \
    --license "MIT" \
    --vendor "skeletonek" \
    --maintainer "skeletonek" \
    --url "https://github.com/skeletonek/guinea-mpeg" \
    --depends "ffmpeg" \
    --depends "mpv-libs" \
    -C "$STAGING" \
    -p "$OUT_DIR/${PKGNAME}-${VERSION}-1.${ARCH}.rpm" \
    usr/

echo "=== Building .pkg.tar.zst (pacman) ==="
fpm -s dir -t pacman \
    -n "$PKGNAME" \
    -v "$VERSION" \
    -a "$ARCH" \
    --description "$DESCRIPTION" \
    --license "MIT" \
    --vendor "skeletonek" \
    --maintainer "skeletonek" \
    --url "https://github.com/skeletonek/guinea-mpeg" \
    --depends "ffmpeg" \
    --depends "mpv" \
    -C "$STAGING" \
    -p "$OUT_DIR/${PKGNAME}-${VERSION}-1-${ARCH}.pkg.tar.zst" \
    usr/

echo ""
echo "=== Packages created in $OUT_DIR ==="
ls -lh "$OUT_DIR/"
