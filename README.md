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

## Build Requirements

- Rust 1.83+ (pinned via `rust-toolchain.toml`)
- Qt 6.5+ (tested on 6.11.0)
- CMake 3.16+
- libmpv (development headers, `pkg-config` findable)
- FFmpeg + ffprobe (with SVT-AV1, libx264, libvpx(-vp9), libopus for full profile support)

## Building

```bash
cmake --build build     # also builds Rust via cargo
```

## Project Structure

- `rust/` — Rust core library: C FFI exports (`lib.rs`), TOML profile config (`config.rs`), ffmpeg command builder (`ffmpeg.rs`)
- `qml/` — Qt Quick QML UI: main window (`main.qml`), timeline handles (`TimelineControl.qml`), profile editor (`ProfileEditor.qml`)
- `main.cpp` — Qt C++ entry point, `GuineaMpegBackend` class with `Q_INVOKABLE` methods, dynamic `dlopen` of Rust `.so`
- `mpvitem.h` / `mpvitem.cpp` — `MpvItem` (QQuickFramebufferObject) wrapping libmpv for video playback
- `CMakeLists.txt` — CMake build, finds Qt6 + mpv, builds Rust as custom target

## Configuration

Profiles are stored as human-editable TOML at `~/.config/guinea-mpeg/config.toml`.
Format: `[[profiles]]` array-of-tables (auto-migrated from the legacy `[profiles."name"]` format).

Built-in defaults are bundled at `build/default_profiles.toml` and loaded at startup.
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

## License

MIT License
