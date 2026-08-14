#!/bin/bash
set -euo pipefail

# Runs inside Docker. Usage: build-appimage.sh <cmake-build-dir>
# $CARGO_TARGET_DIR must be set (by docker run -e).

# CTRL+C from the host only reaches this container's PID 1, so forward the
# signal to the whole build process group and escalate to SIGKILL for any
# process that ignores SIGINT.
interrupt_cleanup() {
    echo "=== Build interrupted ==="
    trap - INT TERM
    kill 0 2>/dev/null || true
    sleep 2
    kill -9 0 2>/dev/null || true
    exit 130
}
trap interrupt_cleanup INT TERM

BUILD_DIR="${1:?usage: build-appimage.sh <cmake-build-dir>}"
CARGO_DIR="${CARGO_TARGET_DIR:-/source/rust/target}"
VERSION=$(grep "^version = " /source/rust/Cargo.toml | head -1 | sed 's/version = "\(.*\)"/\1/')
APPDIR="/source/out/appimage/AppDir"

fetch_tool() {
    local name="$1" url="$2" dest="$3"
    echo "=== Downloading $name ==="
    wget -q -c "$url" -O "/tmp/$name.AppImage"
    chmod +x "/tmp/$name.AppImage"
    "/tmp/$name.AppImage" --appimage-extract
    mv squashfs-root "$dest"
    rm -f "/tmp/$name.AppImage"
}

copy_stripped() {
    cp "$1" "$2"
    strip "$2" 2>/dev/null || true
}

build_binary() {
    echo "=== Building AppImage (version $VERSION) ==="
    mkdir -p /tmp/home "$APPDIR/usr/bin" /source/out/appimage
    cmake -S /source -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release -DPACKAGE_TARGET=appimage
    cmake --build "$BUILD_DIR"

    copy_stripped "$BUILD_DIR/src/guinea-mpeg" "$APPDIR/usr/bin/"
    cp /source/default_profiles.toml "$APPDIR/usr/bin/"
    if [ -f "$CARGO_DIR/release/libguinea_mpeg_core.so" ]; then
        mkdir -p "$APPDIR/usr/lib"
        copy_stripped "$CARGO_DIR/release/libguinea_mpeg_core.so" "$APPDIR/usr/lib/"
    fi
    cp /source/build/linux/applications/guinea-mpeg.desktop "$APPDIR/"
    cp /source/build/linux/icons/hicolor/256x256/apps/guinea-mpeg.png "$APPDIR/"
}

bundle_ffmpeg() {
    echo "=== Bundling static ffmpeg ==="
    wget -q -c "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz" -O /tmp/ffmpeg-static.tar.xz
    tar xf /tmp/ffmpeg-static.tar.xz -C /tmp/
    local ffmpeg_dir
    ffmpeg_dir=$(ls -d /tmp/ffmpeg-*-static 2>/dev/null | head -1 || true)
    if [ -n "$ffmpeg_dir" ]; then
        copy_stripped "$ffmpeg_dir/ffmpeg" "$APPDIR/usr/bin/"
        copy_stripped "$ffmpeg_dir/ffprobe" "$APPDIR/usr/bin/"
    else
        echo "  WARNING: static ffmpeg download failed!"
    fi
}

bundle_qml() {
    # linuxdeploy-plugin-qt scans QML files for imports, so stage them under
    # the AppDir first; run_linuxdeploy removes them again afterwards.
    mkdir -p "$APPDIR/qml"
    cp -r /source/qml/. "$APPDIR/qml/"
}

run_linuxdeploy() {
    fetch_tool linuxdeploy \
        "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage" \
        /tmp/linuxdeploy-root
    fetch_tool linuxdeploy-plugin-qt \
        "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage" \
        /tmp/linuxdeploy-plugin-qt-root

    # Symlink the plugin binary (AppRun itself is a symlink) into linuxdeploy.
    ln -s /tmp/linuxdeploy-plugin-qt-root/usr/bin/linuxdeploy-plugin-qt /tmp/linuxdeploy-root/usr/bin/linuxdeploy-plugin-qt

    echo "=== Bundling dependencies ==="
    export QML_SOURCES_PATHS="$APPDIR/qml"
    export EXTRA_QT_MODULES="quick;quickcontrols2;multimedia"
    /tmp/linuxdeploy-root/AppRun --appdir "$APPDIR" --plugin qt

    rm -rf "$APPDIR/qml"
}

fix_interpreter() {
    echo "=== Fixing ELF interpreter ==="
    local interp=""
    for candidate in "$APPDIR/lib64/ld-linux-x86-64.so.2" "$APPDIR/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2"; do
        if [ -f "$candidate" ]; then
            interp="$candidate"
            break
        fi
    done
    if [ -n "$interp" ]; then
        patchelf --set-interpreter ".${interp#$APPDIR}" "$APPDIR/usr/bin/guinea-mpeg"
        echo "  -> interpreter set to .${interp#$APPDIR}"
    else
        echo "  WARNING: no bundled ld-linux found in AppDir!"
    fi
}

write_apprun() {
    echo "=== Creating AppRun ==="
    cat > "$APPDIR/AppRun" << 'APPRUN'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
export PATH="$HERE/usr/bin:$PATH"
export LD_LIBRARY_PATH="$HERE/usr/lib:$HERE/lib:$LD_LIBRARY_PATH"
export QT_PLUGIN_PATH="$HERE/usr/plugins"
exec "$HERE/usr/bin/guinea-mpeg" "$@"
APPRUN
    chmod +x "$APPDIR/AppRun"
}

package_appimage() {
    echo "=== AppDir structure ==="
    find "$APPDIR" -type f | sort
    fetch_tool appimagetool \
        "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" \
        /tmp/appimagetool-root
    echo "=== Creating AppImage ==="
    (cd /source/out/appimage && /tmp/appimagetool-root/AppRun --no-appstream "$APPDIR" "guinea-mpeg-${VERSION}-x86_64.AppImage")
}

build_binary
bundle_ffmpeg
bundle_qml
run_linuxdeploy
fix_interpreter
write_apprun
package_appimage

rm -rf "$APPDIR"

echo "=== AppImage created: /source/out/appimage/guinea-mpeg-${VERSION}-x86_64.AppImage ==="