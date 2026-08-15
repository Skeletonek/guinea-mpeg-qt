#!/bin/bash
set -euo pipefail

show_help() {
    cat <<EOF
Usage: $0 [options]

Options:
  --clean               Remove out/ and rust/target/ before building
  --package <list>      Build packages (comma-separated: deb,rpm,pacman,flatpak,generic)
  --arch <arch>         Target architecture: x86_64 (default) or aarch64
  --no-build            Skip the build step
   --release             Build release binary (default is a debug build), strip debug info
   --no-strip            Disable stripping (keep debug info) even in release builds
  --version <ver>       Update project version, then build
  --help                Show this help message

Package targets:
  all           Build all package types (deb, rpm, pacman, flatpak, appimage, generic)
  generic       Build locally and create .tar.gz (default if no --package)
  deb           Build in Debian Docker container, produce .deb
  rpm           Build in Fedora Docker container, produce .rpm
  pacman        Build in Arch Linux Docker container, produce .pkg.tar.zst
  appimage      Build in Debian Docker container, produce .AppImage
  flatpak       Build using flatpak-builder (native, requires flatpak)

Architecture targets:
  x86_64        Default. Native builds everywhere.
  aarch64       ARM64. deb/rpm/generic build in Docker with --platform linux/arm64
                (needs docker buildx + QEMU binfmt on an x86_64 host, or a native
                ARM64 host). pacman, appimage and flatpak for aarch64 are not
                supported when cross-building; build them on a native ARM64 host.

Examples:
  $0                                        Build to out/generic
  $0 --package generic                      Build + .tar.gz
  $0 --package deb                          Docker build + .deb
  $0 --package deb,flatpak                  Docker build + .deb + flatpak
  $0 --arch aarch64 --package deb,rpm       ARM64 Docker builds + packages
  $0 --clean --version 0.3.0 --package deb,rpm,pacman
                                            Clean, bump, rebuild all, package
  $0 --package appimage                     Build self-contained AppImage
  $0 --version 0.3.0 --no-build             Bump version only (no build/packages)
EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUT_DIR="$PROJECT_DIR/out"
CARGO_HOME_DIR="$OUT_DIR/.cargo-home"

VERSION="$(grep '^version = ' "$PROJECT_DIR/rust/Cargo.toml" | head -1 | sed 's/version = "\(.*\)"/\1/')"

NO_BUILD=false
DO_CLEAN=false
DO_DEB=false
DO_RPM=false
DO_PACMAN=false
DO_FLATPAK=false
DO_APPIMAGE=false
DO_GENERIC=false
DO_RELEASE=false
DO_STRIP=false
DO_NO_STRIP=false
ARCH_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)
            DO_CLEAN=true; shift ;;
        --arch)
            shift
            ARCH_OVERRIDE="$1"
            shift ;;
        --package)
            shift
            IFS=',' read -ra PKG_LIST <<< "$1"
            for pkg in "${PKG_LIST[@]}"; do
                case "$pkg" in
                    all)       DO_DEB=true; DO_RPM=true; DO_PACMAN=true; DO_FLATPAK=true; DO_APPIMAGE=true; DO_GENERIC=true ;;
                    deb)       DO_DEB=true ;;
                    rpm)       DO_RPM=true ;;
                    pacman)    DO_PACMAN=true ;;
                    flatpak)   DO_FLATPAK=true ;;
                    appimage)  DO_APPIMAGE=true ;;
                    generic)   DO_GENERIC=true ;;
                    *)         echo "ERROR: unknown package target '$pkg' (valid: deb, rpm, pacman, flatpak, appimage, generic, all)"; exit 1 ;;
                esac
            done
            shift ;;
        --no-build|-n)
            NO_BUILD=true; shift ;;
        --release)
            DO_RELEASE=true; shift ;;
        --no-strip)
            DO_NO_STRIP=true; shift ;;
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

HOST_ARCH="$(uname -m)"
ARCH="$HOST_ARCH"
if [[ -n "$ARCH_OVERRIDE" ]]; then
    ARCH="$ARCH_OVERRIDE"
fi
case "$ARCH" in
    x86_64|aarch64) ;;
    *) echo "ERROR: unsupported --arch '$ARCH' (valid: x86_64, aarch64)"; exit 1 ;;
esac
DOCKER_ARCH="$ARCH"
[ "$DOCKER_ARCH" = "aarch64" ] && DOCKER_ARCH="arm64"
DOCKER_PLATFORM="linux/${DOCKER_ARCH}"
BINFMT_ARCH="$DOCKER_ARCH"
[ "$BINFMT_ARCH" = "arm64" ] && BINFMT_ARCH="aarch64"
CROSS_ARCH=false
if [[ "$ARCH" != "$HOST_ARCH" ]]; then
    CROSS_ARCH=true
fi
ARCH_SUFFIX=""
if $CROSS_ARCH; then
    ARCH_SUFFIX="-$ARCH"
fi
PKGNAME="guinea-mpeg"
DESCRIPTION="FFmpeg GUI Frontend with Rust Core"

HAS_PKG_FLAG=false
if $DO_DEB || $DO_RPM || $DO_PACMAN || $DO_FLATPAK || $DO_APPIMAGE || $DO_GENERIC; then
    HAS_PKG_FLAG=true
fi

if ! $HAS_PKG_FLAG; then
    DO_GENERIC=true
fi

if $DO_RELEASE; then
    DO_STRIP=true
fi

if $DO_NO_STRIP; then
    DO_STRIP=false
fi

# ---- Clean ----
if $DO_CLEAN; then
    echo "=== Cleaning build artifacts ==="
    rm -rf "$OUT_DIR" "$PROJECT_DIR/rust/target" "$PROJECT_DIR/.flatpak-builder"
fi

mkdir -p "$OUT_DIR"

# ---- Strip Function ----

strip_artifacts() {
    local dir="$1"
    if ! $DO_STRIP; then return; fi
    if command -v strip &>/dev/null; then
        for f in "$dir/guinea-mpeg" "$dir/libguinea_mpeg_core.so"; do
            [ -f "$f" ] && strip "$f" && echo "  stripped: $f" || true
        done
    fi
}

# ---- Build Functions ----

build_generic() {
    local generic_dir="$OUT_DIR/generic"
    local build_dir="$OUT_DIR/.build-generic"
    local cargo_dir="$OUT_DIR/.cargo-generic"

    echo "=== Building GuineaMPEG $VERSION (generic) ==="

    local build_type="Debug"
    if $DO_RELEASE; then
        build_type="Release"
    fi

    local cargo_subdir="debug"
    if $DO_RELEASE; then
        cargo_subdir="release"
    fi

    export CARGO_TARGET_DIR="$cargo_dir"
    local cmake_opts="-DCMAKE_BUILD_TYPE=${build_type} -DPACKAGE_TARGET=generic"
    cmake -S "$PROJECT_DIR" -B "$build_dir" $cmake_opts
    cmake --build "$build_dir"

    mkdir -p "$generic_dir"
    cp "$build_dir/src/guinea-mpeg" "$generic_dir/"
    if [ -f "$cargo_dir/$cargo_subdir/libguinea_mpeg_core.so" ]; then
        cp "$cargo_dir/$cargo_subdir/libguinea_mpeg_core.so" "$generic_dir/"
    fi
    cp "$PROJECT_DIR/default_profiles.toml" "$generic_dir/"
    strip_artifacts "$generic_dir"
    echo "=== Artifacts in $generic_dir ==="
}

_cleanup_docker() {
    local target="$1"
    for d in ".build-${target}" ".cargo-${target}"; do
        if [ -d "$OUT_DIR/$d" ]; then
            rm -rf "$OUT_DIR/$d" 2>/dev/null || sudo rm -rf "$OUT_DIR/$d" 2>/dev/null || echo "WARNING: Could not clean up $OUT_DIR/$d" >&2
        fi
    done
}

build_in_docker() {
    local target="$1"
    local dockerfile="$2"
    local image_name="guinea-mpeg-${target}-builder"
    local out_dir="$OUT_DIR/$target$ARCH_SUFFIX"
    local build_dir_name=".build-${target}${ARCH_SUFFIX}"
    local cargo_dir_name=".cargo-${target}${ARCH_SUFFIX}"
    local build_dir="$OUT_DIR/$build_dir_name"
    local cargo_dir="$OUT_DIR/$cargo_dir_name"

    if ! command -v docker &>/dev/null; then
        echo "ERROR: docker not found. Install Docker to build $target packages." >&2
        return 1
    fi

    echo "=== Building GuineaMPEG $VERSION in Docker container ($target, $ARCH) ==="

    if $CROSS_ARCH; then
        if ! docker buildx version &>/dev/null; then
            echo "ERROR: docker buildx is required to cross-build for $ARCH." >&2
            return 1
        fi
        if ! ls /proc/sys/fs/binfmt_misc/ 2>/dev/null | grep -q "qemu-${BINFMT_ARCH}"; then
            echo "ERROR: cannot run ${DOCKER_PLATFORM} containers on this ${HOST_ARCH} host:" >&2
            echo "       QEMU binfmt (qemu-${BINFMT_ARCH}) is not registered in binfmt_misc." >&2
            echo "  Docker: docker run --privileged --rm tonistiigi/binfmt --install ${BINFMT_ARCH}" >&2
            echo "  Podman: sudo podman run --privileged --rm docker.io/tonistiigi/binfmt --install ${BINFMT_ARCH}" >&2
            echo "  ...or run the build on a native ${ARCH} host (no --arch needed)." >&2
            return 1
        fi
        docker buildx build --platform "$DOCKER_PLATFORM" --load \
            -t "$image_name" -f "$dockerfile" "$SCRIPT_DIR/docker"
    else
        docker build -t "$image_name" -f "$dockerfile" "$SCRIPT_DIR/docker"
    fi

    mkdir -p "$out_dir" "$build_dir" "$cargo_dir" "$CARGO_HOME_DIR"

    local run_platform=()
    if $CROSS_ARCH; then
        run_platform=(--platform "$DOCKER_PLATFORM")
    fi

    local cmake_build_type="Debug"
    local cargo_subdir="debug"
    if $DO_RELEASE; then
        cmake_build_type="Release"
        cargo_subdir="release"
    fi

    docker run --rm --init "${run_platform[@]}" \
        -v "$PROJECT_DIR:/source" \
        -v "$CARGO_HOME_DIR:/tmp/home/.cargo" \
        -e CARGO_TARGET_DIR="/source/out/$cargo_dir_name" \
        -e CARGO_HOME="/tmp/home/.cargo" \
        -e HOME="/tmp/home" \
        "$image_name" \
        bash -c "
            set -euo pipefail
            trap 'echo \"=== Build interrupted ===\"; trap - INT TERM; kill 0 2>/dev/null || true; sleep 2; kill -9 0 2>/dev/null || true; exit 130' INT TERM
            mkdir -p /tmp/home
            cmake_opts='-DCMAKE_BUILD_TYPE=${cmake_build_type} -DPACKAGE_TARGET=${target}'
            cmake -S /source -B /source/out/$build_dir_name \$cmake_opts
            cmake --build /source/out/$build_dir_name
            cp /source/out/$build_dir_name/src/guinea-mpeg /source/out/$target$ARCH_SUFFIX/
            cp /source/out/$cargo_dir_name/${cargo_subdir}/libguinea_mpeg_core.so /source/out/$target$ARCH_SUFFIX/ || true
            $(if $DO_STRIP; then echo "strip /source/out/$target$ARCH_SUFFIX/guinea-mpeg 2>/dev/null || true; strip /source/out/$target$ARCH_SUFFIX/libguinea_mpeg_core.so 2>/dev/null || true"; fi)
            cp /source/default_profiles.toml /source/out/$target$ARCH_SUFFIX/
        " || {
            echo "WARNING: Docker build for $target failed" >&2
            if $CROSS_ARCH; then
                echo "HINT: for $ARCH cross-builds on an $HOST_ARCH host, register QEMU binfmt:" >&2
                echo "  docker run --privileged --rm tonistiigi/binfmt --install arm64" >&2
            fi
            return 1
        }

    # Fix ownership if running rootful Docker (no-op under rootless podman)
    chown -R "$(id -u):$(id -g)" "$out_dir" "$build_dir" "$cargo_dir" "$CARGO_HOME_DIR" 2>/dev/null || true
    echo "=== Docker build for $target complete ==="
}

build_appimage() {
    if ! command -v docker &>/dev/null; then
        echo "ERROR: docker not found. Install Docker to build AppImage packages." >&2
        exit 1
    fi

    local dockerfile="$SCRIPT_DIR/docker/debian-trixie.Dockerfile"
    local image_name="guinea-mpeg-appimage-builder"
    local out_dir="$OUT_DIR/appimage"
    local build_dir_name=".build-appimage"
    local cargo_dir_name=".cargo-appimage"
    local build_dir="$OUT_DIR/$build_dir_name"
    local cargo_dir="$OUT_DIR/$cargo_dir_name"
    local script="/source/build/docker/build-appimage.sh"

    echo "=== Building AppImage ==="

    docker build -t "$image_name" -f "$dockerfile" "$SCRIPT_DIR/docker"
    mkdir -p "$out_dir" "$build_dir" "$cargo_dir" "$CARGO_HOME_DIR"

    docker run --rm --init \
        -v "$PROJECT_DIR:/source" \
        -v "$CARGO_HOME_DIR:/tmp/home/.cargo" \
        -e CARGO_TARGET_DIR="/source/out/$cargo_dir_name" \
        -e CARGO_HOME="/tmp/home/.cargo" \
        -e HOME="/tmp/home" \
        -e GUINEA_CMAKE_BUILD_TYPE="$(if $DO_RELEASE; then echo Release; else echo Debug; fi)" \
        -e GUINEA_CARGO_SUBDIR="$(if $DO_RELEASE; then echo release; else echo debug; fi)" \
        "$image_name" \
        bash "$script" "/source/out/$build_dir_name" || {
            echo "WARNING: AppImage build failed" >&2
            return 1
        }

    chown -R "$(id -u):$(id -g)" "$out_dir" "$build_dir" "$cargo_dir" "$CARGO_HOME_DIR" 2>/dev/null || true
    echo "=== AppImage build complete ==="
}

# ---- Package Functions ----

stage_package() {
    local staging="$1"
    local artifacts="$2"
    mkdir -p "$staging/usr/bin" \
             "$staging/usr/lib/$PKGNAME" \
             "$staging/usr/share/applications" \
             "$staging/usr/share/icons" \
             "$staging/usr/share/$PKGNAME"
    install -m755 "$artifacts/guinea-mpeg" "$staging/usr/bin/$PKGNAME"
    if [ -f "$artifacts/libguinea_mpeg_core.so" ]; then
        install -m755 "$artifacts/libguinea_mpeg_core.so" "$staging/usr/lib/$PKGNAME/"
    fi
    patchelf --add-rpath '$ORIGIN/../lib/'"$PKGNAME" "$staging/usr/bin/$PKGNAME"
    install -m644 "$PROJECT_DIR/default_profiles.toml" "$staging/usr/share/$PKGNAME/"
    install -m644 "$PROJECT_DIR/build/linux/applications/$PKGNAME.desktop" "$staging/usr/share/applications/"
    cp -r "$PROJECT_DIR/build/linux/icons/hicolor" "$staging/usr/share/icons/"
}

DEB_DEPS=(
    --depends "ffmpeg"
    --depends "libmpv2"
    --depends "libqt6quickcontrols2-6 (>= 6.8.0)"
    --depends "libqt6quick6 (>= 6.8.0)"
    --depends "libqt6widgets6 (>= 6.8.0)"
    --depends "libqt6gui6 (>= 6.8.0)"
    --depends "libqt6qml6 (>= 6.8.0)"
    --depends "libqt6opengl6 (>= 6.8.0)"
    --depends "qml6-module-qtquick-controls (>= 6.8.0)"
    --depends "qml6-module-qtquick-layouts (>= 6.8.0)"
    --depends "qml6-module-qtquick-dialogs (>= 6.8.0)"
    --depends "qml6-module-qtmultimedia (>= 6.8.0)"
)
RPM_DEPS=(
    --depends "mpv-libs"
    --depends "qt6-qtquickcontrols2 >= 6.10.0-1"
    --depends "qt6-qtdeclarative >= 6.10.0-1"
    --depends "qt6-qtbase-gui >= 6.10.0-1"
    --depends "qt6-qtmultimedia >= 6.10.0-1"
)
PACMAN_DEPS=(
    --depends "ffmpeg"
    --depends "mpv"
    --depends "qt6-base>=6.11.0-1"
    --depends "qt6-declarative>=6.11.0-1"
    --depends "qt6-multimedia>=6.11.0-1"
)

FPM_BASE=(
    --force -s dir
    -n "$PKGNAME"
    -v "$VERSION"
    -a "$ARCH"
    --description "$DESCRIPTION"
    --license "BSD-3-Clause"
    --vendor "Skeletonek"
    --maintainer "Łukasz Plich <l.plich@skeletonek.com>"
    --url "https://gitlab.com/Skeletonek/guinea-mpeg-qt"
)

build_fpm_package() {
    local target="$1"
    shift
    local deps=("$@")
    local artifacts_dir="$OUT_DIR/$target$ARCH_SUFFIX"
    local staging; staging=$(mktemp -d)
    trap 'rm -rf "$staging"' RETURN

    if [ ! -f "$artifacts_dir/guinea-mpeg" ]; then
        echo "WARNING: Missing artifacts in $artifacts_dir, skipping .${target}" >&2
        return 1
    fi

    stage_package "$staging" "$artifacts_dir"

    local pkg_ext
    case "$target" in
        deb)    pkg_ext="deb" ;;
        rpm)    pkg_ext="rpm" ;;
        pacman) pkg_ext="pkg.tar.zst" ;;
    esac

    echo "=== Building .${pkg_ext} ==="
    fpm "${FPM_BASE[@]}" -t "$target" "${deps[@]}" \
        -C "$staging" \
        -p "$artifacts_dir/${PKGNAME}-${VERSION}-${ARCH}.${pkg_ext}" \
        usr/ || echo "WARNING: .${pkg_ext} build failed" >&2
}

build_generic_tar() {
    local generic_dir="$OUT_DIR/generic$ARCH_SUFFIX"
    local archive_name="${PKGNAME}-${VERSION}-${ARCH}"
    local archive_file="$generic_dir/${archive_name}.tar.gz"

    if [ ! -f "$generic_dir/guinea-mpeg" ]; then
        echo "WARNING: Missing artifacts in $generic_dir, skipping tar.gz" >&2
        return 1
    fi

    echo "=== Creating $archive_file ==="
    rm -f "$archive_file"
    tar -czf "$OUT_DIR/${archive_name}.tar.gz" -C "$generic_dir" .
    mv "$OUT_DIR/${archive_name}.tar.gz" "$archive_file"
    echo "Created: $archive_file"
}

build_flatpak() {
    if ! command -v flatpak-builder &>/dev/null; then
        echo "ERROR: flatpak-builder not found. Install it:"
        echo "  sudo apt install flatpak flatpak-builder"
        echo "  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
        return 1
    fi
    local manifest="$PROJECT_DIR/build/flatpak/guinea-mpeg.yaml"
    local build_dir="$OUT_DIR/.flatpak-build"
    local repo_dir="$OUT_DIR/.flatpak-repo"
    local bundle_dir="$OUT_DIR/flatpak"
    local bundle="$bundle_dir/${PKGNAME}-${VERSION}-${ARCH}.flatpak"
    mkdir -p "$bundle_dir"
    rm -rf "$repo_dir"
    echo "=== Building Flatpak ==="
    flatpak-builder --force-clean \
        --install-deps-from flathub \
        --repo="$repo_dir" \
        "$build_dir" "$manifest" || {
            rm -rf "$build_dir" "$repo_dir"
            echo "ERROR: Flatpak build failed" >&2
            return 1
        }
    flatpak build-bundle "$repo_dir" "$bundle" \
        com.skeletonek.guinea-mpeg master
    rm -rf "$build_dir"
    echo "Created: $bundle"
}

# ---- Pre-flight checks ----

if $NO_BUILD && $DO_APPIMAGE; then
    echo "ERROR: --no-build is not supported for appimage target (needs a fresh build inside Docker)" >&2
    exit 1
fi

# ---- Main ----

if ! $NO_BUILD; then
    $DO_GENERIC && {
        if $CROSS_ARCH; then
            build_in_docker "generic" "$SCRIPT_DIR/docker/debian-trixie.Dockerfile"
        else
            build_generic
        fi
    }
    $DO_DEB      && build_in_docker "deb"      "$SCRIPT_DIR/docker/debian-trixie.Dockerfile"
    $DO_RPM      && build_in_docker "rpm"      "$SCRIPT_DIR/docker/fedora-43.Dockerfile"
    $DO_PACMAN && {
        if $CROSS_ARCH; then
            echo "ERROR: aarch64 pacman is not supported (no official Arch ARM Docker image). Build pacman on a native $ARCH host." >&2
            exit 1
        fi
        build_in_docker "pacman" "$SCRIPT_DIR/docker/arch-latest.Dockerfile"
    }
    $DO_APPIMAGE && {
        if $CROSS_ARCH; then
            echo "ERROR: aarch64/appimage cross-build is not supported. Build AppImage on a native $ARCH host." >&2
            exit 1
        fi
        build_appimage
    }
    $DO_FLATPAK  && {
        if $CROSS_ARCH; then
            echo "ERROR: aarch64/flatpak cross-build is not supported (bundle arch = build host). Build Flatpak on a native $ARCH host." >&2
            exit 1
        fi
        build_flatpak
    }
fi

# Package phase (separate from build so --no-build can re-package existing artifacts)
if $DO_DEB || $DO_RPM || $DO_PACMAN; then
    if ! command -v fpm &>/dev/null; then
        echo "ERROR: fpm not found. Install it: gem install fpm"
        exit 1
    fi
    $DO_DEB    && build_fpm_package "deb"    "${DEB_DEPS[@]}"
    $DO_RPM    && build_fpm_package "rpm"    "${RPM_DEPS[@]}"
    $DO_PACMAN && build_fpm_package "pacman" "${PACMAN_DEPS[@]}"
fi

$DO_GENERIC && build_generic_tar

echo ""
echo "=== Output ==="
for d in "$OUT_DIR"/*/; do
    if [ -d "$d" ] && [ "$(basename "$d")" != ".flatpak-repo" ]; then
        echo "  $(basename "$d")/"
        ls -lh "$d" 2>/dev/null | sed 's/^/    /'
    fi
done
