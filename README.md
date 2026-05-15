# GuineaMPEG

A modern FFmpeg transcoding GUI with a Rust core library loaded at runtime via C FFI.

## Features

- **Video Preview with Playback**: Load any video, play/pause, seek with slider
- **Timeline Selection**: Drag start/end handles to select a segment for transcoding
- **Transcoding Profiles**: Built-in profiles for H.264, H.265, VP9, and SVT-AV1 (high quality + fast)
- **Profile Editor**: View and edit profiles (JSON) in-app
- **Live Transcode Output**: Non-modal dialog showing real-time ffmpeg stderr output
- **Audio Routing**: Volume slider (Qt6 requires explicit `AudioOutput`)
- **Output Options**: MP4, MKV, WebM containers; audio handled per-format (copy for MP4/MKV, libopus for WebM)

## Build Requirements

- Rust 1.94+ (Edition 2024)
- Qt 6.5+ (tested on 6.11.0)
- CMake 3.16+
- FFmpeg + ffprobe (with SVT-AV1, libx264, libx265, libvpx-vp9, libopus for full profile support)

## Building

```bash
cmake --build build     # also builds Rust via cargo
```

## Project Structure

- `rust/` — Rust core library: C FFI exports (`lib.rs`), TOML profile config (`config.rs`), ffmpeg command builder (`ffmpeg.rs`)
- `qml/` — Qt Quick QML UI: main window (`main.qml`), timeline handles (`TimelineControl.qml`), profile editor (`ProfileEditor.qml`)
- `main.cpp` — Qt C++ entry point, `GuineaMpegBackend` class with `Q_INVOKABLE` methods, dynamic `dlopen` of Rust `.so`
- `CMakeLists.txt` — CMake build, finds Qt6, builds Rust as custom target

## Configuration

Profiles are stored as human-editable TOML at `~/.config/guinea-mpeg/config.toml`.

### Built-in Profiles

| Profile | Codec | Quality |
|---|---|---|
| H.264 High Quality | libx264 | CRF 18, slow preset |
| H.265 Balanced | libx265 | CRF 23, medium preset |
| VP9 Web | libvpx-vp9 | CRF 30, row-mt |
| AV1 High Quality | libsvtav1 | Preset 8, VMAF tune, CRF 28 |
| AV1 Fast | libsvtav1 | Preset 4, PSNR tune, 5M bitrate |

## License

MIT License
