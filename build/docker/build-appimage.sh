#!/bin/bash
set -euo pipefail

# Runs inside Docker. Usage: build-appimage.sh <cmake-build-dir>
# $CARGO_TARGET_DIR must be set (by docker run -e).

BUILD_DIR="$1"
CARGO_DIR="${CARGO_TARGET_DIR:-/source/rust/target}"
VERSION=$(grep "^version = " /source/rust/Cargo.toml | head -1 | sed 's/version = "\(.*\)"/\1/')
APPDIR="/source/out/appimage/AppDir"

echo "=== Building AppImage (version $VERSION) ==="

mkdir -p /tmp/home "$APPDIR/usr/bin" /source/out/appimage

CMAKE_OPTS="-DCMAKE_BUILD_TYPE=Release -DPACKAGE_TARGET=appimage"
cmake -S /source -B "$BUILD_DIR" $CMAKE_OPTS
cmake --build "$BUILD_DIR"

cp "$BUILD_DIR/guinea-mpeg" "$APPDIR/usr/bin/"
cp /source/default_profiles.toml "$APPDIR/usr/bin/"
if [ -f "$CARGO_DIR/release/libguinea_mpeg_core.so" ]; then
    mkdir -p "$APPDIR/usr/lib"
    cp "$CARGO_DIR/release/libguinea_mpeg_core.so" "$APPDIR/usr/lib/"
fi
strip "$APPDIR/usr/bin/guinea-mpeg" 2>/dev/null || true
[ -f "$APPDIR/usr/lib/libguinea_mpeg_core.so" ] && strip "$APPDIR/usr/lib/libguinea_mpeg_core.so" 2>/dev/null || true
cp /source/build/linux/applications/guinea-mpeg.desktop "$APPDIR/"
cp /source/build/linux/icons/hicolor/256x256/apps/guinea-mpeg.png "$APPDIR/"

# Bundle static ffmpeg and ffprobe for self-contained transcoding
echo "=== Downloading static ffmpeg ==="
wget -q -c "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz" -O /tmp/ffmpeg-static.tar.xz
tar xf /tmp/ffmpeg-static.tar.xz -C /tmp/
FFMPEG_DIR=$(ls -d /tmp/ffmpeg-*-static 2>/dev/null | head -1)
if [ -n "$FFMPEG_DIR" ]; then
    cp "$FFMPEG_DIR/ffmpeg" "$APPDIR/usr/bin/"
    cp "$FFMPEG_DIR/ffprobe" "$APPDIR/usr/bin/"
    strip "$APPDIR/usr/bin/ffmpeg" "$APPDIR/usr/bin/ffprobe" 2>/dev/null || true
else
    echo "  WARNING: static ffmpeg download failed!"
fi

# linuxdeploy-plugin-qt scans QML files for imports — copy temporarily
mkdir -p "$APPDIR/qml"
cp /source/qml/*.qml "$APPDIR/qml/"

echo "=== Downloading linuxdeploy ==="
wget -q -c "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage" -O /tmp/linuxdeploy.AppImage
chmod +x /tmp/linuxdeploy.AppImage
/tmp/linuxdeploy.AppImage --appimage-extract
mv squashfs-root /tmp/linuxdeploy-root
rm /tmp/linuxdeploy.AppImage

echo "=== Downloading linuxdeploy-plugin-qt ==="
wget -q -c "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage" -O /tmp/linuxdeploy-plugin-qt.AppImage
chmod +x /tmp/linuxdeploy-plugin-qt.AppImage
/tmp/linuxdeploy-plugin-qt.AppImage --appimage-extract
mv squashfs-root /tmp/linuxdeploy-plugin-qt-root
rm /tmp/linuxdeploy-plugin-qt.AppImage

# Symlink directly to binary, not AppRun (which is a symlink itself)
ln -s /tmp/linuxdeploy-plugin-qt-root/usr/bin/linuxdeploy-plugin-qt /tmp/linuxdeploy-root/usr/bin/linuxdeploy-plugin-qt

# linuxdeploy-plugin-qt expects the SVG icon engine plugin to exist when it
# discovers the svg module. Debian Trixie's libqt6svg6 doesn't ship it, so
# create a minimal stub to satisfy the file existence check.
mkdir -p /usr/lib/x86_64-linux-gnu/qt6/plugins/iconengines
echo 'void qsvgicon_stub(){}' | gcc -x c - -shared \
    -o /usr/lib/x86_64-linux-gnu/qt6/plugins/iconengines/libqsvgicon.so \
    -fPIC 2>/dev/null || touch /usr/lib/x86_64-linux-gnu/qt6/plugins/iconengines/libqsvgicon.so

echo "=== Bundling dependencies ==="
export QML_SOURCES_PATHS="$APPDIR/qml"
export EXTRA_QT_MODULES="quick;quickcontrols2"
/tmp/linuxdeploy-root/AppRun --appdir "$APPDIR" --plugin qt

# Manually bundle the SVG image format plugin (runtime decode, no linked dep)
mkdir -p "$APPDIR/usr/plugins/imageformats"
SVG_PLUGIN=""
for dir in /usr/lib/qt6/plugins/imageformats /usr/lib/*/qt6/plugins/imageformats; do
    [ -f "$dir/qsvg.so" ] && SVG_PLUGIN="$dir/qsvg.so" && break
done
if [ -n "$SVG_PLUGIN" ]; then
    cp -a "$SVG_PLUGIN" "$APPDIR/usr/plugins/imageformats/"
    echo "  -> bundled SVG plugin from $SVG_PLUGIN"
fi

rm -rf "$APPDIR/qml"

echo "=== Fixing ELF interpreter ==="
INTERP=""
for candidate in "$APPDIR/lib64/ld-linux-x86-64.so.2" "$APPDIR/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2"; do
    if [ -f "$candidate" ]; then
        INTERP="$candidate"
        break
    fi
done
if [ -n "$INTERP" ]; then
    REL_INTERP="${INTERP#$APPDIR}"
    patchelf --set-interpreter ".$REL_INTERP" "$APPDIR/usr/bin/guinea-mpeg"
    echo "  -> interpreter set to .$REL_INTERP"
else
    echo "  WARNING: no bundled ld-linux found in AppDir!"
fi

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

echo "=== AppDir structure ==="
find "$APPDIR" -type f | sort

echo "=== Downloading appimagetool ==="
wget -q -c "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" -O /tmp/appimagetool.AppImage
chmod +x /tmp/appimagetool.AppImage
/tmp/appimagetool.AppImage --appimage-extract
mv squashfs-root /tmp/appimagetool-root
rm /tmp/appimagetool.AppImage

echo "=== Creating AppImage ==="
cd /source/out/appimage
/tmp/appimagetool-root/AppRun --no-appstream "$APPDIR" "guinea-mpeg-${VERSION}-x86_64.AppImage"

rm -rf "$APPDIR"

echo "=== AppImage created: /source/out/appimage/guinea-mpeg-${VERSION}-x86_64.AppImage ==="
