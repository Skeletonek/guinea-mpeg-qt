# GuineaMPEG

A modern FFmpeg transcoding GUI with a Rust core library loaded at runtime via C FFI.

## Features

- **Video Preview with Playback**: Load any video via embedded libmpv (no Qt Multimedia dependency)
- **Timeline Selection**: Drag start/end handles to select a segment for transcoding
- **Transcoding Profiles**: Built-in profiles for H.264, VP8, VP9, and SVT-AV1
- **Profile Editor**: Create, edit, and delete profiles in-app
- **Live Transcode Output**: Non-modal dialog showing real-time ffmpeg stderr output with autoscroll
- **Cancel Transcode**: Kill running ffmpeg process mid-transcode
- **Output Options**: MP4 (H.264) and WebM (VP8/VP9/AV1); AAC for H.264, Opus for everything else
- **MIME type integration**: Open video files directly from your file manager

## Build Requirements

- CMake 3.16+
- Rust 1.83+ (use your distro's `cargo`/`rustc` packages)
- Qt 6.5+ (tested on 6.11.0)
- libmpv (development headers, `pkg-config` findable)
- OpenGL / GLX development headers
- FFmpeg + ffprobe (runtime, for transcoding — with SVT-AV1, libx264, libvpx(-vp9), libopus for full profile support)

### Per-Distro Package Lists

**Debian / Ubuntu**
```bash
sudo apt install cmake g++ pkg-config \
                 qt6-base-dev qt6-declarative-dev \
                 libmpv-dev libgl1-mesa-dev \
                 cargo
```

**Fedora**
```bash
sudo dnf install cmake gcc-c++ pkgconf-pkg-config \
                 qt6-qtbase-devel qt6-qtdeclarative-devel \
                 mpv-libs-devel mesa-libGL-devel \
                 cargo rust
```

**Arch Linux**
```bash
sudo pacman -S --needed base-devel cmake \
                       qt6-base qt6-declarative \
                       mpv rust cargo
```

## Building

```bash
cmake -S . -B out && cmake --build out   # also builds Rust via cargo
```

Or use the build script (recommended for packaging):

```bash
./build/linux_build.sh                              # build to out/generic/
```

### Packaging

The `build/linux_build.sh` script supports Docker-based cross-distro packaging:

```bash
./build/linux_build.sh --package generic            # build + .tar.gz
./build/linux_build.sh --package deb                # Docker build + .deb
./build/linux_build.sh --package rpm                # Docker build + .rpm
./build/linux_build.sh --package pacman             # Docker build + .pkg.tar.zst
./build/linux_build.sh --package flatpak            # flatpak-builder build
./build/linux_build.sh --package appimage           # Docker build + .AppImage
./build/linux_build.sh --package deb,rpm,pacman     # multiple targets
./build/linux_build.sh --package all                # all targets
./build/linux_build.sh --clean --package deb        # clean + rebuild + .deb
```

Output goes to `out/{target}/` — e.g. `out/deb/`, `out/appimage/`.

Version is read from `rust/Cargo.toml` automatically. Bump with:

```bash
./update-version.sh 0.2.1
```

### CI/CD

A GitLab CI pipeline (`.gitlab-ci.yml`) builds and releases all packages on tag pushes using Docker-in-Docker.

## Project Structure

- `rust/` — Rust core library: C FFI exports (`lib.rs`), TOML profile config (`config.rs`), ffmpeg command builder (`ffmpeg.rs`)
- `qml/` — Qt Quick QML UI: main window (`main.qml`), timeline handles (`TimelineControl.qml`), profile editor (`ProfileEditor.qml`)
- `src/main.cpp` — Qt C++ entry point, `GuineaMpegBackend` class with `Q_INVOKABLE` methods, dynamic `dlopen` of Rust `.so`
- `src/mpvitem.h` / `src/mpvitem.cpp` — `MpvItem` (QQuickFramebufferObject) wrapping libmpv for video playback
- `CMakeLists.txt` — CMake build, finds Qt6 + mpv, builds Rust as custom target

## Configuration

Profiles are stored as human-editable TOML at `~/.config/guinea-mpeg/config.toml`.
Format: `[[profiles]]` array-of-tables (auto-migrated from the legacy `[profiles."name"]` format).

Built-in defaults are bundled at `default_profiles.toml` (next to the binary or at `/usr/share/guinea-mpeg/default_profiles.toml`) and loaded at startup.
User profiles merge over defaults (same name = user override).

### Built-in Profiles

| Profile | Codec | Quality |
|---------|-------|---------|
| H.264 1080p | libx264 | CRF 18, slow preset, film tune |
| H.264 720p | libx264 | CRF 23, medium preset |
| VP8 Web | libvpx | 2M bitrate, 720p |
| VP9 1080p | libvpx-vp9 | CRF 30, medium preset |
| VP9 720p | libvpx-vp9 | CRF 32, medium preset |
| AV1 1080p | libsvtav1 | CRF 28, preset 8, VMAF tune |
| AV1 720p Fast | libsvtav1 | CRF 35, preset 4, PSNR tune |
