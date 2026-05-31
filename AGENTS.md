# Agent Knowledge Base

## Architecture
- Rust compiled as `cdylib` (`libguinea_mpeg_core.so`) linked dynamically at runtime. Rust exports plain `extern "C"` functions — no CXX, no CXX-Qt, no code generation.
- C header `rust/include/guinea_mpeg_core.h` declares all FFI functions. CMake adds `rust/include/` as an include path.
- Profile management lives in `rust/src/config.rs` (serde + toml). `rust/src/backend.rs` wraps it in `extern "C"` functions.
- mpv handle creation/destruction/commands/event-property-caching lives in `rust/src/mpv.rs`, exposed via `extern "C"` functions. Raw `*mut c_void` is passed through FFI.
- `GuineaMpegBackendExt` (`src/backend.h`, `src/backend.cpp`) is a plain `QObject` (no generated base class). Profile and ffmpeg invokables call Rust `extern "C"` functions. Only transcode process lifecycle (start/kill/capture output) is pure C++/Qt (needs QProcess signals for real-time streaming to QML).
- `MpvItem` (QQuickFramebufferObject) owns a `void* m_backend` pointer from `guinea_mpeg_mpv_create()`. Gets raw `mpv_handle*` via `guinea_mpeg_mpv_raw_handle()` for render context creation and wakeup callback. Delegates all mpv commands to Rust `extern "C"` functions.
- Event processing: mpv wakeup callback → Qt signal → `handleMpvEvents()` calls `guinea_mpeg_mpv_process_events()` → emits Qt signals based on returned bitmask (1=position, 2=duration, 4=playing).
- `MpvRenderer` stays in C++ (QQuickFramebufferObject::Renderer cannot be in Rust). Creates `mpv_render_context*` from the raw handle.

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
- `Dialog` content can be clipped behind the footer (OK button). Fix: set `implicitHeight` explicitly (e.g. 350) and use `anchors.left/right/top` instead of `anchors.fill` on the inner layout.
- Center a `Dialog` via `onOpened: centerInParent()` calling a function that sets `x` and `y` using `parent.width/height`.
- `QQuickStyle::setStyle("Fusion")` is required to customize control backgrounds on Windows (native QML style forbids background overrides).
- `QPalette` dark/light colors are set on `QApplication` but may be ignored by the native QML style; Fusion QML style respects them.

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
- CMake runs `cargo build --release` at configure time via `execute_process`. Rust is always built as `cdylib` (`.so`/`.dylib`/`.dll`) and linked dynamically.
- `crate-type = ["cdylib"]` in `rust/Cargo.toml`.
- No `--whole-archive` needed — plain `extern "C"` symbols are found by the linker without static initializer tricks.
- No CXX/CXX-Qt generated code or discovery. C header at `rust/include/guinea_mpeg_core.h` is included via `target_include_directories`.
- CMake requires `pkg_check_modules(MPV REQUIRED mpv)` for libmpv (needed by C++ mpvitem.cpp for render context).

## Build & Packaging (Linux)
- `build/linux_build.sh` — builds the project and optionally produces packages.
- Flags: `--clean`, `--package <list>`, `--no-build`, `--version X.Y.Z`, `--help`.
- Default (no flags): cmake configure + build to `out/generic/` (no archive).
- `--clean` removes `out/` and `rust/target/` before building.
- `--package` accepts comma-separated: `deb`, `rpm`, `pacman`, `flatpak`, `appimage`, `generic`, `all`.
- `--no-build` skips building; errors if combined with `--package appimage`.
- `--version` delegates to `update-version.sh`, then continues.
- Output dirs: `out/generic/`, `out/deb/`, `out/rpm/`, `out/pacman/`, `out/flatpak/`, `out/appimage/`.
- Per-target cargo build dirs: `out/.build-{target}/` + `out/.cargo-{target}/` (auto-cleaned after pack).
- Rust is built as a shared library (`.so` shipped alongside the binary).
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
- Exit code 124 = timeout (normal for offscreen test).
- Qt version: 6.11.0 on Arch Linux x86_64, KDE Plasma 6, Wayland, AMD GPU.
- Qt version: 6.11.1 on Windows 11 x86_64, MSVC 2022, Fusion QML style.
- When QML fails with exit 255 but no error message on stderr, use `QT_FORCE_STDERR_LOGGING=1` to force QML engine errors to the terminal.
- Dark mode detection reads Windows registry `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\AppsUseLightTheme`. A `theme` context property with color keys is exported to QML.

## MPV Integration Notes
- `MpvItem` (QQuickFramebufferObject) wraps libmpv via Rust's `extern "C"` backend (`void* m_backend`). The raw `mpv_handle*` is extracted from Rust for render context + wakeup setup.
- Bitmask from `guinea_mpeg_mpv_process_events()`: 1=position, 2=duration, 4=playing.
- **Must** `setMirrorVertically(true)` on MpvItem AND `MPV_RENDER_PARAM_FLIP_Y = 1` — mpv renders upside-down into FBO, Qt flips on display.
- `MPV_RENDER_PARAM_OPENGL_FBO` requires full `mpv_opengl_fbo` struct (`fbo`, `w`, `h`, `internal_format`), not just an `int`.
- Options (set by Rust on create): `vo=libmpv`, `keep-open=yes`, `cache=yes`.
- `setlocale(LC_NUMERIC, "C")` after `QApplication` (QApplication overrides locale).
- `loadfile` MUST be deferred until `mpv_render_context*` exists — `setSource()` stores URL in `m_pendingSource`, and `MpvRenderer` constructor calls `loadPendingSource()` via `QMetaObject::invokeMethod` after creating the render context.
- `m_renderReady` flag on MpvItem, set by renderer constructor, guards whether `setSource` can load immediately or must defer.
- Rust's `libmpv2-sys` crate provides mpv FFI. CMake also links `PkgConfig::MPV` for C++ mpv header includes (render context API). Linker deduplicates, no conflict.
