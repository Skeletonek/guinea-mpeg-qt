#!/bin/bash
set -euo pipefail

# Package build script for GuineaMPEG
# Produces .deb, .rpm, .pkg.tar.zst (pacman) artifacts in out/
#
# Usage:
#   ./build/linux_package.sh                          # build all (fpm)
#   ./build/linux_package.sh --debian                 # build only .deb
#   ./build/linux_package.sh --fedora                 # build only .rpm
#   ./build/linux_package.sh --arch                   # build only .pkg.tar.zst
#   ./build/linux_package.sh --flatpak                # build only Flatpak
#   ./build/linux_package.sh --no-build               # skip cmake rebuild
#   ./build/linux_package.sh -d -n 0.3.0              # single flag combo

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUT_DIR="$PROJECT_DIR/out"

VERSION="$(grep '^version = ' "$PROJECT_DIR/rust/Cargo.toml" | head -1 | sed 's/version = "\(.*\)"/\1/')"
NO_BUILD=false
BUILD_DEB=false
BUILD_RPM=false
BUILD_PACMAN=false
BUILD_FLATPAK=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-build|-n)     NO_BUILD=true; shift ;;
        --debian|-d)       BUILD_DEB=true; shift ;;
        --fedora|-f)       BUILD_RPM=true; shift ;;
        --arch|-a)         BUILD_PACMAN=true; shift ;;
        --flatpak|-p)      BUILD_FLATPAK=true; shift ;;
        --help|-h)
            sed -n '4,15p' "$0"
            exit 0
            ;;
        *)                 VERSION="$1"; shift ;;
    esac
done

# If no target flag given, build all (fpm packages)
if ! $BUILD_DEB && ! $BUILD_RPM && ! $BUILD_PACMAN && ! $BUILD_FLATPAK; then
    BUILD_DEB=true
    BUILD_RPM=true
    BUILD_PACMAN=true
fi

ARCH="$(uname -m)"
PKGNAME="guinea-mpeg"
DESCRIPTION="FFmpeg GUI Frontend with Rust Core"

# ---- Build ----
if ! $NO_BUILD; then
    echo "=== Building GuineaMPEG $VERSION ==="
    cmake --build "$PROJECT_DIR/out" --target guinea-mpeg 2>/dev/null || {
        echo "Run 'cmake -S . -B out && cmake --build out' first, or press Enter to build now..."
        read -r
        cmake -S "$PROJECT_DIR" -B "$PROJECT_DIR/out"
        cmake --build "$PROJECT_DIR/out"
    }
fi

# ---- Stage files ----
stage_package() {
    local staging="$1"
    mkdir -p "$staging/usr/bin" "$staging/usr/lib/$PKGNAME" \
             "$staging/usr/share/applications" \
             "$staging/usr/share/icons" \
             "$staging/usr/share/$PKGNAME"

    install -m755 "$PROJECT_DIR/out/guinea-mpeg" "$staging/usr/bin/$PKGNAME"
    install -m644 "$PROJECT_DIR/rust/target/release/libguinea_mpeg_core.so" "$staging/usr/lib/$PKGNAME/"
    install -m644 "$PROJECT_DIR/default_profiles.toml" "$staging/usr/share/$PKGNAME/"
    install -m644 "$PROJECT_DIR/build/linux/applications/$PKGNAME.desktop" "$staging/usr/share/applications/"
    cp -r "$PROJECT_DIR/build/linux/icons/hicolor" "$staging/usr/share/icons/"
}

# ---- Dependencies ----
DEB_DEPS=(
    --depends "ffmpeg"
    --depends "libmpv2"
    --depends "libqt6quickcontrols2-6"
    --depends "libqt6quick6"
    --depends "libqt6widgets6"
    --depends "libqt6gui6"
    --depends "libqt6qml6"
    --depends "libqt6opengl6"
)
RPM_DEPS=(
    --depends "mpv-libs"
    --depends "qt6-qtquickcontrols2"
    --depends "qt6-qtdeclarative"
    --depends "qt6-qtbase-gui"
)
PACMAN_DEPS=(
    --depends "ffmpeg"
    --depends "mpv"
    --depends "qt6-base"
    --depends "qt6-declarative"
)

FPM_BASE=(
    --force -s dir
    -n "$PKGNAME"
    -v "$VERSION"
    -a "$ARCH"
    --description "$DESCRIPTION"
    --license "BSD-3-Clause"
    --vendor "skeletonek"
    --maintainer "Łukasz Plich <l.plich@skeletonek.com>"
    --url "https://gitlab.com/Skeletonek/guinea-mpeg-qt"
)

# ---- Package functions ----
build_deb() {
    local staging; staging=$(mktemp -d)
    trap "rm -rf '$staging'" RETURN
    stage_package "$staging"
    echo "=== Building .deb ==="
    fpm "${FPM_BASE[@]}" -t deb "${DEB_DEPS[@]}" \
        -C "$staging" \
        -p "$OUT_DIR/${PKGNAME}_${VERSION}_${ARCH}.deb" \
        usr/ || echo "WARNING: .deb build failed" >&2
}

build_rpm() {
    local staging; staging=$(mktemp -d)
    trap "rm -rf '$staging'" RETURN
    stage_package "$staging"
    echo "=== Building .rpm ==="
    fpm "${FPM_BASE[@]}" -t rpm "${RPM_DEPS[@]}" \
        -C "$staging" \
        -p "$OUT_DIR/${PKGNAME}-${VERSION}.${ARCH}.rpm" \
        usr/ || echo "WARNING: .rpm build failed" >&2
}

build_pacman() {
    local staging; staging=$(mktemp -d)
    trap "rm -rf '$staging'" RETURN
    stage_package "$staging"
    echo "=== Building .pkg.tar.zst (pacman) ==="
    fpm "${FPM_BASE[@]}" -t pacman "${PACMAN_DEPS[@]}" \
        -C "$staging" \
        -p "$OUT_DIR/${PKGNAME}-${VERSION}-${ARCH}.pkg.tar.zst" \
        usr/ || echo "WARNING: pacman build failed" >&2
}

# ---- Flatpak ----
build_flatpak() {
    if ! command -v flatpak-builder &>/dev/null; then
        echo "ERROR: flatpak-builder not found. Install it:"
        echo "  sudo apt install flatpak flatpak-builder"
        echo "  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
        return 1
    fi
    local manifest="$PROJECT_DIR/build/flatpak/guinea-mpeg.yaml"
    local build_dir="$OUT_DIR/flatpak-build"
    local bundle="$OUT_DIR/${PKGNAME}-${VERSION}-${ARCH}.flatpak"
    echo "=== Building Flatpak ==="
    flatpak-builder --force-clean --ccache \
        --install-deps-from flathub \
        --repo="$OUT_DIR/flatpak-repo" \
        "$build_dir" "$manifest"
    flatpak build-bundle "$OUT_DIR/flatpak-repo" "$bundle" \
        com.skeletonek.guinea-mpeg master
    rm -rf "$build_dir"
    echo "Created: $bundle"
}

# ---- Main ----
mkdir -p "$OUT_DIR"

if $BUILD_DEB || $BUILD_RPM || $BUILD_PACMAN; then
    if ! command -v fpm &>/dev/null; then
        echo "ERROR: fpm not found. Install it: gem install fpm"
        exit 1
    fi
    $BUILD_DEB    && build_deb
    $BUILD_RPM    && build_rpm
    $BUILD_PACMAN && build_pacman
fi

$BUILD_FLATPAK && build_flatpak

echo ""
echo "=== Packages created in $OUT_DIR ==="
ls -lh "$OUT_DIR/"
