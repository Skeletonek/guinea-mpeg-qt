#!/bin/bash
set -euo pipefail

show_help() {
    cat <<EOF
Usage: $0 [options]

Options:
  --clean               Remove out/ and rust/target/ before building
  --package <list>      Build packages (comma-separated: deb,rpm,pacman,flatpak)
  --no-build            Skip the cmake build step
  --version <ver>       Update project version via update-version.sh, then build
  --help                Show this help message

Examples:
  $0                                        Build only
  $0 --package deb                          Build + .deb package
  $0 --package deb,flatpak                  Build + .deb + flatpak
  $0 --clean --version 0.3.0 --package deb,rpm,pacman
                                            Full clean, bump version, rebuild, package
  $0 --version 0.3.0 --no-build             Bump version only (no build/packages)
EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUT_DIR="$PROJECT_DIR/out"

VERSION="$(grep '^version = ' "$PROJECT_DIR/rust/Cargo.toml" | head -1 | sed 's/version = "\(.*\)"/\1/')"
NO_BUILD=false
DO_CLEAN=false
DO_DEB=false
DO_RPM=false
DO_PACMAN=false
DO_FLATPAK=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)
            DO_CLEAN=true; shift ;;
        --package)
            shift
            IFS=',' read -ra PKG_LIST <<< "$1"
            for pkg in "${PKG_LIST[@]}"; do
                case "$pkg" in
                    deb)     DO_DEB=true ;;
                    rpm)     DO_RPM=true ;;
                    pacman)  DO_PACMAN=true ;;
                    flatpak) DO_FLATPAK=true ;;
                    *)       echo "ERROR: unknown package target '$pkg' (valid: deb, rpm, pacman, flatpak)"; exit 1 ;;
                esac
            done
            shift ;;
        --no-build|-n)
            NO_BUILD=true; shift ;;
        --version)
            shift
            "$PROJECT_DIR/update-version.sh" "$1"
            VERSION="$1"
            shift ;;
        --help|-h)
            show_help
            exit 0 ;;
        *)
            echo "ERROR: unknown option '$1'. Use --help for usage."
            exit 1 ;;
    esac
done

ARCH="$(uname -m)"
PKGNAME="guinea-mpeg"
DESCRIPTION="FFmpeg GUI Frontend with Rust Core"

# ---- Clean ----
if $DO_CLEAN; then
    echo "=== Cleaning build artifacts ==="
    rm -rf "$OUT_DIR" "$PROJECT_DIR/rust/target"
fi

# ---- Build ----
if ! $NO_BUILD; then
    echo "=== Building GuineaMPEG $VERSION ==="
    if [ ! -f "$OUT_DIR/CMakeCache.txt" ]; then
        cmake -S "$PROJECT_DIR" -B "$OUT_DIR"
    fi
    cmake --build "$OUT_DIR"
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
    trap 'rm -rf "$staging"' RETURN
    stage_package "$staging"
    echo "=== Building .deb ==="
    fpm "${FPM_BASE[@]}" -t deb "${DEB_DEPS[@]}" \
        -C "$staging" \
        -p "$OUT_DIR/${PKGNAME}_${VERSION}_${ARCH}.deb" \
        usr/ || echo "WARNING: .deb build failed" >&2
}

build_rpm() {
    local staging; staging=$(mktemp -d)
    trap 'rm -rf "$staging"' RETURN
    stage_package "$staging"
    echo "=== Building .rpm ==="
    fpm "${FPM_BASE[@]}" -t rpm "${RPM_DEPS[@]}" \
        -C "$staging" \
        -p "$OUT_DIR/${PKGNAME}-${VERSION}.${ARCH}.rpm" \
        usr/ || echo "WARNING: .rpm build failed" >&2
}

build_pacman() {
    local staging; staging=$(mktemp -d)
    trap 'rm -rf "$staging"' RETURN
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

if $DO_DEB || $DO_RPM || $DO_PACMAN; then
    if ! command -v fpm &>/dev/null; then
        echo "ERROR: fpm not found. Install it: gem install fpm"
        exit 1
    fi
    $DO_DEB    && build_deb
    $DO_RPM    && build_rpm
    $DO_PACMAN && build_pacman
fi

$DO_FLATPAK && build_flatpak

echo ""
echo "=== Output in $OUT_DIR ==="
ls -lh "$OUT_DIR/"
