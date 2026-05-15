# Agent Knowledge Base

## Architecture
- Rust library (`libguinea_mpeg_core.so`, cdylib/staticlib) loaded at runtime via `dlopen` from C++ (`main.cpp`).
- 8 C FFI exports: `init_core`, `free_rust_string`, `available_profiles`, `load_profile`, `save_profile`, `delete_profile`, `build_ffmpeg_command`, `parse_video_info`.
- C++ `GuineaMpegBackend` class exposed as QML context property `backend`.
- CMake builds Rust via `cargo build --release` as custom target, copies `.so` into build dir.

## QML Patterns
- Use `Component.onCompleted: player.videoOutput = videoOutput` to connect `MediaPlayer` to `VideoOutput` when they're in different scope hierarchies (MediaPlayer at ApplicationWindow level, VideoOutput inside a Component used by StackView).
- IDs inside a `Component` are NOT accessible from outside it. The reverse works (parent scope IDs accessible from within Component).
- `FileDialog.selectedFile` is a `file:///...` URL. Use it directly as `MediaPlayer.source` (which is a `url` property). Strip `file://` prefix only for C++ paths.
- `Column` from `QtQuick` 2.15+ has `padding` support.
- `Q_PROPERTY` signals (`NOTIFY`) are the cleanest way to push streaming data (like ffmpeg output) from C++ to QML.

## Qt6 Multimedia Notes
- Requires explicit `AudioOutput` element connected to `MediaPlayer` (no automatic audio routing like Qt5).
- `VideoOutput` in Qt 6.11 does NOT have a `source` property. Connect via `Component.onCompleted: player.videoOutput = videoOutput` or `MediaPlayer.videoOutput: videoOutput` (if both in same scope).
- `MediaPlayer` pauses/showing first frame works if `play()` was called at least once.

## TimelineControl Patterns
- Handle x positions MUST be clamped to `[0, track.width - handle.width]` with `Math.max(0, Math.min(x, track.width - width))` to keep handles within the clickable area.
- Do NOT use `clip: true` on the timeline root — it clips MouseArea events, making handles unclickable.

## Transcoding Output
- ffmpeg writes progress to stderr, not stdout.
- Capture via `QProcess::readyReadStandardError` in C++.
- Expose to QML as `Q_PROPERTY(QString transcodeOutput NOTIFY transcodeOutputUpdated)`.
- Track current QProcess; kill old one if user starts another transcode.
- Audio stream copy (`-c:a copy`) works for MP4/MKV but NOT for WebM — use `libopus` for `.webm` output.

## Build
- `cmake --build build` in project root. Rust is built automatically.
- `#include "main.moc"` at end of `main.cpp` is required since the Q_OBJECT class is defined in the cpp file.

## Runtime
- Exit code 255 = QML load/parse failure.
- Exit code 143 = SIGTERM (normal kill).
- Qt version: 6.11.0 on Arch Linux x86_64, KDE Plasma 6, Wayland, AMD GPU.
