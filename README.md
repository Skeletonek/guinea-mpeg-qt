# GuineaMPEG

A modern FFmpeg transcoding GUI with a Rust core library dynamically linked via C FFI.

## Features

- **Video Preview with Playback**: Load any video via embedded libmpv
- **Timeline Selection**: Drag start/end handles to select a segment for transcoding
- **Transcoding Profiles**: Built-in profiles for H.264, H.265/HEVC, VP9, AV1, GIF, and WebP
- **Hardware Encoding**: Runtime detection of NVENC, QSV, VAAPI, AMF, Vulkan encoders via ffmpeg
- **Profile Editor**: Create, edit, and delete profiles in-app
- **Profile Export/Import**: Share profiles between machines as `.toml` files from the Profile Editor
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
- [mpv-dev bundle](https://github.com/zhongfly/mpv-winbuild) (zhongfly winbuild, auto-downloaded by the build script)
- [FFmpeg & ffprobe](https://github.com/BtbN/FFmpeg-Builds) (BtbN build, auto-downloaded by the build script)
- 7-Zip (required by the mpv-dev download script): `winget install 7zip.7zip`
- Ninja (optional, auto-detected): `winget install Ninja-build.Ninja`
- InnoSetup 6 (optional, for installer) — download from [jrsoftware.org](https://jrsoftware.org/isdl.php)

For **Windows on ARM (ARM64)** additionally install:
- The `MSVC v143 - VS 2022 C++ ARM64 build tools` component in the VS 2022 installer
- The Qt **`win64_msvc2022_arm64`** package (Qt 6.x for MSVC 2022 ARM64)
- `rustup target add aarch64-pc-windows-msvc`

> ARM64 binaries only run on Windows-on-ARM (WoA) devices; an x64 host can build
> them but cannot execute them.

### Per-Distro Package Lists

**Debian / Ubuntu**
```bash
sudo apt install cmake g++ pkg-config cargo \
                 qt6-base-dev qt6-declarative-dev qt6-multimedia-dev qt6-tools-dev \
                 qml6-module-qtmultimedia qml6-module-qtquickcontrols2 \
                 libmpv-dev libgl1-mesa-dev
```

**Fedora**
```bash
sudo dnf install cmake gcc-c++ pkgconf-pkg-config cargo rust \
                 qt6-qtbase-devel qt6-qtdeclarative-devel \
                 qt6-qtquickcontrols2-devel qt6-qtmultimedia-devel qt6-qttools-devel \
                 mpv-libs-devel mesa-libGL-devel
```

**Arch Linux**
```bash
sudo pacman -S --needed base-devel cmake \
                       qt6-base qt6-declarative qt6-multimedia qt6-tools \
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
./build/linux-build.sh --release --package deb      # optimized Release build (strips debug info)
```

Output goes to `out/{target}/` — e.g. `out/deb/`, `out/appimage/`.

#### ARM64 (Linux)

Pass `--arch aarch64` to build for ARM64. `generic`, `deb` and `rpm` build in
Docker with `--platform linux/arm64` and emit artifacts to `out/<target>-aarch64/`.
On an `x86_64` host this needs Docker **buildx** and QEMU binfmt registration:

```bash
docker run --privileged --rm tonistiigi/binfmt --install arm64
./build/linux-build.sh --arch aarch64 --package deb,rpm
```

`pacman`, `appimage` and `flatpak` are not supported for aarch64 cross-builds —
build those on a native ARM64 host (`--arch` is then unnecessary, the arch is
detected automatically).

### Windows

Open **x64 Native Tools Command Prompt for VS 2022** (or any PowerShell where `cl.exe` and `nmake` are available from PATH), then:

```powershell
.\build\windows-build.ps1                           # build to out/windows/
.\build\windows-build.ps1 -Package                  # build + ZIP + InnoSetup installer
.\build\windows-build.ps1 -Arch arm64               # build for Windows on ARM
.\build\windows-build.ps1 -Arch arm64 -Package      # arm64 ZIP + installer
.\build\windows-build.ps1 -Clean                    # full rebuild
.\build\windows-build.ps1 -Console                  # build with visible console (for debugging)
.\build\windows-build.ps1 -Config RelWithDebInfo    # debug symbols enabled
```

Run `.\build\download-vendor.ps1 -Arch arm64` first to fetch the arm64 mpv-dev
bundle and winarm64 ffmpeg (the build script does this automatically too).

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
| `-Arch x86_64` | Target architecture: `x86_64` (default) or `arm64` |
| `-Config Release` | Build config: `Debug` (default), `Release`, `RelWithDebInfo` |
| `-Clean` | Remove output dir and Rust artifacts before building |
| `-QtDir C:\Qt\6.11.1\msvc2022_64` | Specify Qt path manually |

Artifacts:

| Artifact | Path |
|----------|------|
| Executable | `out/windows/guinea-mpeg.exe` |
| Portable ZIP | `out/guinea-mpeg-{version}-x86_64.zip` (or `-arm64`) |
| Installer (exe) | `out/guinea-mpeg-{version}-x86_64.exe` (or `-arm64`) |

### Version

Version is read from `rust/Cargo.toml` automatically. Bump with:

```bash
./update-version.sh 1.2.3
```

## CI/CD

A GitLab CI pipeline (`.gitlab-ci.yml`) builds and releases all linux packages (except Appimage) on tag pushes using Docker-in-Docker.

## Project Structure

```
.
├── rust/                    # Rust core library (cdylib)
│   ├── include/guinea_mpeg_core.h    # hand-written C FFI header
│   └── src/                 # backend FFI, TOML config, mpv, ffmpeg
├── src/                     # C++ glue (QObjects exposed to QML)
│   ├── main.cpp
│   ├── backend.{h,cpp}
│   └── mpvitem.{h,cpp}
├── qml/                     # Qt Quick UI
│   ├── main.qml
│   ├── VideoPreview.qml, TimelineControl.qml, ControlsPanel.qml
│   ├── ProfileEditor.qml (+ ProfileEditor/)
│   ├── Components/          # reusable controls
│   ├── Dialogs/             # modal dialogs
│   └── Utils/               # JS helpers
├── build/                   # build scripts + Dockerfiles
├── translations/            # .ts locale files
├── default_profiles.toml
├── CMakeLists.txt
└── .gitlab-ci.yml
```

- **Rust core** (`rust/`): all business logic, compiled to `libguinea_mpeg_core.so` — profile config/merge, mpv control, ffmpeg command building and encoder detection. Exposes a hand-written C API (`rust/include/guinea_mpeg_core.h`); data crosses the FFI boundary as JSON strings.
- **C++ glue** (`src/`): thin `QObject`s (`GuineaMpegBackendExt`, `MpvItem` + renderer) registering into QML as `GuineaMpeg 1.0`. Only the transcode `QProcess` lifecycle lives in C++ — everything else delegates to Rust.
- **QML** (`qml/`): the entire UI — main window, video preview, timeline trimming, profile editor and dialogs.

## Configuration

All user settings live in `~/.config/guinea-mpeg/config.toml`, editable in-app and directly as human-editable TOML. It holds:

- **Profiles** — the `[[profiles]]` array-of-tables (auto-migrated from the legacy `[profiles."name"]` format), managed via the Profile Editor.
- **Options** — an `[options]` table (language, Qt Quick Controls style, color scheme, hardware acceleration, preview volume, update checks), managed via the Settings button.

Built-in defaults are bundled at `default_profiles.toml` (next to the binary or at `/usr/share/guinea-mpeg/default_profiles.toml`) and loaded at startup.
User profiles merge over defaults (same name = user override).

Profiles can be shared across machines by exporting them to `.toml` files and importing them (from the Profile Editor).

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
