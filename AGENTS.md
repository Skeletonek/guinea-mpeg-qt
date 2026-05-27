# Agent Knowledge Base

## Architecture
- Rust library (`libguinea_mpeg_core.so`, cdylib/staticlib) loaded at runtime via `dlopen` from C++ (`main.cpp`).
- 8 C FFI exports: `init_core`, `free_rust_string`, `available_profiles`, `load_profile`, `save_profile`, `delete_profile`, `build_ffmpeg_command`, `parse_video_info`.
- C++ `GuineaMpegBackend` class exposed as QML context property `backend`.
- CMake builds Rust via `cargo build --release` as custom target, copies `.so` into build dir.

## QML Patterns
- IDs inside a `Component` are NOT accessible from outside it. The reverse works (parent scope IDs accessible from within Component).
- `FileDialog.selectedFile` is a `file:///...` URL. Strip `file://` prefix only for C++ paths; QML `url` properties accept it directly.
- `Column` from `QtQuick` 2.15+ has `padding` support.
- `Q_PROPERTY` signals (`NOTIFY`) are the cleanest way to push streaming data (like ffmpeg output) from C++ to QML.
- `StackView.onActivated` on a page fires every time it becomes the current item — useful for refreshing data after popping back.

## TimelineControl Patterns
- Handle x positions MUST be clamped to `[0, track.width - handle.width]` with `Math.max(0, Math.min(x, track.width - width))` to keep handles within the clickable area.
- Do NOT use `clip: true` on the timeline root — it clips MouseArea events, making handles unclickable.
- Programmatic changes to `startTime`/`endTime` (e.g. on file load) MUST be guarded with a flag to prevent `onStartTimeChanged`/`onEndTimeChanged` handlers from seeking the player.

## Transcoding Output
- ffmpeg writes progress to stderr, not stdout.
- Capture via `QProcess::readyReadStandardError` in C++.
- Expose to QML as `Q_PROPERTY(QString transcodeOutput NOTIFY transcodeOutputUpdated)`.
- Track current QProcess; kill old one if user starts another transcode.
- Audio stream copy (`-c:a copy`) works for MP4/MKV but NOT for WebM — use `libopus` for `.webm` output.

## Profile Config (Rust)
- `AppConfig.profiles` is `Vec<VideoProfile>` (matches TOML `[[profiles]]` array format).
- `load_profiles_from_file()` tries `Vec` format first, falls back to legacy `HashMap` (`[profiles."name"]`) for backwards compat.
- `save_user_config()` writes in `[[profiles]]` format (the canonical form).
- Merging: defaults loaded first, then user config overlays by `p.name`. Same name = user profile wins.

## Build
- `cmake -S . -B out && cmake --build out` in project root. Rust builds automatically via cargo.
- `#include "main.moc"` at end of `main.cpp` is required since the `Q_OBJECT` class is defined in the cpp file.
- CMake requires `pkg_check_modules(MPV REQUIRED mpv)` for libmpv.
- `build/` is for source-controlled packaging scripts; `out/` is gitignored (cmake artifacts + fpm packages).

## Runtime
- Exit code 255 = QML load/parse failure.
- Exit code 143 = SIGTERM (normal kill).
- Qt version: 6.11.0 on Arch Linux x86_64, KDE Plasma 6, Wayland, AMD GPU.

## MPV Integration Notes
- `MpvItem` (QQuickFramebufferObject) wraps libmpv via `mpv_handle*` (GUI thread) + `mpv_render_context*` (render thread).
- **Must** `setMirrorVertically(true)` on MpvItem AND `MPV_RENDER_PARAM_FLIP_Y = 1` — mpv renders upside-down into FBO, Qt flips on display.
- `MPV_RENDER_PARAM_OPENGL_FBO` requires full `mpv_opengl_fbo` struct (`fbo`, `w`, `h`, `internal_format`), not just an `int`.
- Options: `vo=libmpv`, `keep-open=yes`, `hwdec=auto-safe`, `cache=yes`.
- `setlocale(LC_NUMERIC, "C")` after `QApplication` (QApplication overrides locale).
- Dangling pointer trap: `path.toUtf8().constData()` temp dies. Always store `QByteArray` in local var.
- `loadfile` then `play()` both called from C++ `setSource`, NOT from QML `onSourceChanged`.
- `mpv_command_async` vs `mpv_command`: use `mpv_command` (synchronous) for `loadfile` to ensure ordering; `mpv_command_async` only if the calling thread must not block.
- `MPV_FORMAT_FLAG` data is `int*`, NOT `bool*` — cast accordingly.
- `MPV_EVENT_PLAYBACK_RESTART` fires after seeking even in paused state — do NOT blindly set `m_playing = true`; check actual `pause` property via `mpv_get_property`.
