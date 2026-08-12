# GuineaMPEG

A modern FFmpeg transcoding GUI with a Rust core library dynamically linked via C FFI.

## Features

- **Video Preview with Playback**: Load any video via embedded libmpv
- **Timeline Selection**: Drag start/end handles to select a segment for transcoding
- **Transcoding Profiles**: Built-in profiles for H.264, H.265/HEVC, VP9, AV1, GIF, and WebP
- **Hardware Encoding**: Runtime detection of NVENC, QSV, VAAPI, AMF, Vulkan encoders via ffmpeg
- **Profile Editor**: Create, edit, and delete profiles in-app; per-encoder preset/tune/pixfmt filtering
- **Live Transcode Output**: Non-modal dialog showing real-time ffmpeg stderr output with autoscroll
- **MIME type integration**: Open video files directly from your file manager
- **Drag & Drop**: Drop a video file anywhere on the window to load it

## Build Requirements

### Linux
- CMake 3.16+
- GCC 10+ (C++20 required)
- Rust 1.56+ (use your distro's `cargo`/`rustc` packages)
- Qt 6.5+ (tested on 6.11.0)
- libmpv (development headers, `pkg-config` findable)
- OpenGL / GLX development headers
- FFmpeg + ffprobe (runtime, for transcoding — with SVT-AV1, libx264, libvpx(-vp9), libwebp, libopus for full profile support)

### Windows
- CMake 3.16+
- Visual Studio 2022 (Build Tools or full IDE) with **Desktop development with C++** workload
- Rust 1.56+ with MSVC toolchain:
  ```powershell
  rustup toolchain install stable-msvc
  rustup default stable-msvc
  rustup target add x86_64-pc-windows-msvc
  ```
- Qt 6.5+ for MSVC 2022 (tested on 6.11.1) — required components:
  - `Qt 6.x / MSVC 2022 64-bit`
  - `Qt Quick`
  - `Qt QuickControls2`
- [mpv-dev bundle](https://github.com/zhongfly/mpv-winbuild) (auto-downloaded by the build script to `build/vendor/mpv-dev-x86_64/`)
- FFmpeg & ffprobe (auto-downloaded by the build script, gyan.dev full build)
- 7-Zip (required by the mpv-dev download script): `winget install 7zip.7zip`
- Ninja (optional, auto-detected): `winget install Ninja-build.Ninja`
- InnoSetup 6 (optional, for installer) — download from [jrsoftware.org](https://jrsoftware.org/isdl.php)

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

### Linux
```bash
./build/linux-build.sh                              # build to out/generic/
```

#### Packaging (Linux)

The `build/linux-build.sh` script supports Docker-based cross-distro packaging:

```bash
./build/linux-build.sh --package generic            # build + .tar.gz
./build/linux-build.sh --package deb                # Docker build + .deb
./build/linux-build.sh --package rpm                # Docker build + .rpm
./build/linux-build.sh --package pacman             # Docker build + .pkg.tar.zst
./build/linux-build.sh --package flatpak            # flatpak-builder build
./build/linux-build.sh --package appimage           # Docker build + .AppImage
./build/linux-build.sh --package deb,rpm,pacman     # multiple targets
./build/linux-build.sh --package all                # all targets
./build/linux-build.sh --clean --package deb        # clean + rebuild + .deb
```

Output goes to `out/{target}/` — e.g. `out/deb/`, `out/appimage/`.

### Windows

Open **x64 Native Tools Command Prompt for VS 2022** (or any PowerShell where `cl.exe` and `nmake` are available from PATH), then:

```powershell
.\build\windows-build.ps1                           # build to out/windows/
.\build\windows-build.ps1 -Package                  # build + ZIP + InnoSetup installer
.\build\windows-build.ps1 -Clean                    # full rebuild
.\build\windows-build.ps1 -Console                  # build with visible console (for debugging)
.\build\windows-build.ps1 -Config RelWithDebInfo    # debug symbols enabled
```

The script will:
1. Auto-detect Visual Studio 2022 (via vswhere)
2. Download the mpv-dev bundle and ffmpeg/ffprobe if missing
3. Build the Rust library with `cargo`
4. Configure and build with CMake + Ninja (MSVC)
5. Run `windeployqt` to collect Qt DLLs
6. Copy `mpv-2.dll` to the output directory
7. Create a portable ZIP archive
8. Build an InnoSetup installer (if ISCC.exe is available)

Additional flags:

| Flag | Description |
|------|-------------|
| `-SkipPackage` | Build only, skip packaging |
| `-SkipMpv` | Skip mpv-dev download (use existing) |
| `-QtDir C:\Qt\6.8.0\msvc2022_64` | Specify Qt path manually |
| `-NoClean` | Rebuild without cleaning |

Artifacts:

| Artifact | Path |
|----------|------|
| Executable | `out/windows/guinea-mpeg.exe` |
| Portable ZIP | `out/guinea-mpeg-{version}-x86_64.zip` |
| Installer (exe) | `out/guinea-mpeg-{version}-x86_64.exe` |

Output: `out/windows/guinea-mpeg.exe` (no console window by default).

### Version

Version is read from `rust/Cargo.toml` automatically. Bump with:

```bash
./update-version.sh 0.2.1
```

## CI/CD

A GitLab CI pipeline (`.gitlab-ci.yml`) builds and releases all packages on tag pushes using Docker-in-Docker.

## Project Structure

- `rust/` — Rust core library: `backend.rs` (profile management FFI), `config.rs` (TOML profile config), `ffmpeg/` (ffmpeg subprocess calls and command building — `args.rs`, `encoders.rs`, `codecs.rs`, `ffi.rs`, `types.rs`, `util.rs`), `mpv.rs` (mpv handle/events/commands)
- `rust/include/guinea_mpeg_core.h` — Hand-written C header declaring all `extern "C"` FFI functions
- `qml/` — Qt Quick QML UI: main window (`main.qml`), video preview (`VideoPreview.qml`), control panel (`ControlsPanel.qml`), timeline handles (`TimelineControl.qml`), profile editor (`ProfileEditor.qml` + sub-panels in `ProfileEditor/`), and `Dialogs/` subdirectory for modal dialogs
- `src/main.cpp` — Qt C++ entry point, `GuineaMpegBackendExt` class with `Q_INVOKABLE` methods
- `src/backend.h` / `src/backend.cpp` — Plain `QObject` wrapping Rust `extern "C"` calls; only transcode QProcess lifecycle stays in C++
- `src/mpvitem.h` / `src/mpvitem.cpp` — `MpvItem` (QQuickFramebufferObject) + `MpvRenderer` delegating mpv commands to Rust via `extern "C"`
- `CMakeLists.txt` — CMake build, links `libguinea_mpeg_core.so` (built via cargo), finds Qt6 + mpv

## Configuration

Profiles are stored as human-editable TOML at `~/.config/guinea-mpeg/config.toml`.
Format: `[[profiles]]` array-of-tables (auto-migrated from the legacy `[profiles."name"]` format).

Built-in defaults are bundled at `default_profiles.toml` (next to the binary or at `/usr/share/guinea-mpeg/default_profiles.toml`) and loaded at startup.
User profiles merge over defaults (same name = user override).

### Built-in Profiles

| Profile | Codec | Quality |
|---------|-------|---------|
| H.264 High | libx264 | CRF 18, slow preset, film tune, 1080p |
| H.265 High | libx265 | CRF 22, slow preset, film tune, 1080p |
| H.265 Medium | libx265 | CRF 28, medium preset, film tune, 720p |
| VP9 Low | libvpx-vp9 | CRF 40, deadline=good, cpu-used=3, ssim tune, 720p |
| VP9 Medium | libvpx-vp9 | CRF 32, deadline=good, cpu-used=2, ssim tune, 720p |
| AV1 High | libsvtav1 | CRF 28, preset 6, VMAF tune, native res, tiles 2x3 |
| AV1 Medium | libsvtav1 | CRF 35, preset 6, VMAF tune, 720p, tiles 1x2 |
| AV1 Low | libsvtav1 | CRF 42, preset 6, VMAF tune, 720p |
| Animated GIF | gif | 480p, 10 fps, quality 75, loop |
| Animated WebP | libwebp_anim | 480p, 10 fps, quality 75, loop |
