# Agent Knowledge Base

## Architecture
- Rust library (`libguinea_mpeg_core.so`, cdylib/staticlib) loaded at runtime via `dlopen` from C++ (`src/main.cpp`).
- 7 C FFI exports: `init_core`, `free_rust_string`, `available_profiles`, `load_profile`, `save_profile`, `delete_profile`, `build_ffmpeg_command`.
- C++ `GuineaMpegBackend` class exposed as QML context property `backend`.
- CMake builds Rust via `cargo build --release` as custom target, copies `.so` into build dir.
- CLI argument (for MIME type opening) parsed in `src/main.cpp`: skips flags and flatpak `@@` markers, normalizes via `QUrl::toLocalFile()`, passed as `initialFilePath` context property to QML.
- QML `Component.onCompleted` calls `loadVideo(initialFilePath)` to auto-load the file.

## QML Patterns
- IDs inside a `Component` are NOT accessible from outside it. The reverse works (parent scope IDs accessible from within Component).
- `FileDialog.selectedFile` is a `file:///...` URL. Strip `file://` prefix only for C++ paths; QML `url` properties accept it directly.
- `Column` from `QtQuick` 2.15+ has `padding` support.
- `Q_PROPERTY` signals (`NOTIFY`) are the cleanest way to push streaming data (like ffmpeg output) from C++ to QML.
- `StackView.onActivated` on a page fires every time it becomes the current item — useful for refreshing data after popping back.
- Use `encodeURI()` on the file path when constructing `file://` URLs in QML (handles spaces/special chars).
- Directory imports (`import "dialogs"`, `import "../"`) are required to make QML types in subdirectories or parent directories discoverable. Types in the same directory are auto-discovered, but types in different directories need explicit `import`.
- Avoid property names that collide with parent scope IDs — `appWindow: appWindow` creates a binding loop because the property name and the id are the same. Use a different name like `hostWindow: appWindow`.
- Dialog components (AboutDialog, TranscodeDialog, etc.) use `property QtObject appWindow: null` to receive a reference to the ApplicationWindow, giving them access to its methods and state. Set via `appWindow: appWindow` in main.qml (no binding loop here since the property is on a different object).

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
- Compile flag `-mdirect-extern-access` needed for GCC 14+/Qt 6.11 compat (prevents copy relocation errors).
- `build/` is for source-controlled packaging scripts; `out/` is gitignored (cmake artifacts + packages).
- Version canonical source: `rust/Cargo.toml` — `update-version.sh` propagates to `CMakeLists.txt` (About dialog reads `buildInfo.version` from CMake `PROJECT_VERSION` at runtime).

## Build & Packaging
- `build/linux_build.sh` — builds the project and optionally produces packages.
- Flags: `--clean`, `--package <list>`, `--no-build`, `--version X.Y.Z`, `--help`.
- Default (no flags): cmake configure + build to `out/generic/` (no archive).
- `--clean` removes `out/` and `rust/target/` before building.
- `--package` accepts comma-separated: `deb`, `rpm`, `pacman`, `flatpak`, `appimage`, `generic`, `all`.
- `--no-build` skips building; errors if combined with `--package appimage`.
- `--version` delegates to `update-version.sh`, then continues.
- Output dirs: `out/generic/`, `out/deb/`, `out/rpm/`, `out/pacman/`, `out/flatpak/`, `out/appimage/`.
- Per-target cargo build dirs: `out/.build-{target}/` + `out/.cargo-{target}/` (auto-cleaned after pack).
- Docker-based builds (deb, rpm, pacman, appimage) use `build/docker/*.Dockerfile` with `build_in_docker()`.
- `--package generic` creates a flat `.tar.gz` (no `usr/` prefix, no version subdir).
- `--package flatpak` uses host `flatpak-builder` (not Docker), SDK `org.kde.Platform//6.10`.
- Version canonical source: `rust/Cargo.toml`.
- Flatpak post-install: installs SVG to `hicolor/scalable/apps/` + 256×256 PNG fallback.
- AppImage build: `AppRun` is created manually (not relying on linuxdeploy to generate it). `patchelf` explicitly sets the ELF interpreter to the bundled `ld-linux-x86-64.so.2` — linuxdeploy copies the lib but does NOT repoint `.interp`.
- AppImage plugin symlink: points directly to the binary (`usr/bin/linuxdeploy-plugin-qt`), not through `AppRun` (which is a symlink itself).
- CI pipeline: `.gitlab-ci.yml` — `package` stage with dind-based jobs + GitLab release on tags.

## Runtime
- Exit code 255 = QML load/parse failure.
- Exit code 143 = SIGTERM (normal kill).
- Qt version: 6.11.0 on Arch Linux x86_64, KDE Plasma 6, Wayland, AMD GPU.
- When QML fails with exit 255 but no error message on stderr, use `QT_FORCE_STDERR_LOGGING=1` (or deprecated `QT_LOGGING_TO_CONSOLE=1`) to force QML engine errors to the terminal. Without it, error output may be suppressed.

## MPV Integration Notes
- `MpvItem` (QQuickFramebufferObject) wraps libmpv via `mpv_handle*` (GUI thread) + `mpv_render_context*` (render thread).
- **Must** `setMirrorVertically(true)` on MpvItem AND `MPV_RENDER_PARAM_FLIP_Y = 1` — mpv renders upside-down into FBO, Qt flips on display.
- `MPV_RENDER_PARAM_OPENGL_FBO` requires full `mpv_opengl_fbo` struct (`fbo`, `w`, `h`, `internal_format`), not just an `int`.
- Options: `vo=libmpv`, `keep-open=yes`, `cache=yes`.
- `setlocale(LC_NUMERIC, "C")` after `QApplication` (QApplication overrides locale).
- Dangling pointer trap: `path.toUtf8().constData()` temp dies. Always store `QByteArray` in local var.
- `loadfile` MUST be deferred until `mpv_render_context*` exists — `setSource()` stores URL in `m_pendingSource`, and `MpvRenderer` constructor calls `loadPendingSource()` via `QMetaObject::invokeMethod` after creating the render context. Without this, the `vo=libmpv` driver stalls at `width=0 height=0`.
- `mpv_command` (synchronous) for `loadfile`; `mpv_command_async` only if the calling thread must not block.
- `MPV_FORMAT_FLAG` data is `int*`, NOT `bool*` — cast accordingly.
- `MPV_EVENT_PLAYBACK_RESTART` fires after seeking even in paused state — do NOT blindly set `m_playing = true`; check actual `pause` property via `mpv_get_property`.
- `m_renderReady` flag on MpvItem, set by renderer constructor, guards whether `setSource` can load immediately or must defer.
