# Agent Knowledge Base

## Architecture
- Qt Quick app with a Rust core: UI is QML, C++ glue in `src/`, business logic in Rust compiled as a `cdylib` (`libguinea_mpeg_core.so`) shipped beside the binary.
- FFI: Rust exports plain `extern "C"` functions declared in `rust/include/guinea_mpeg_core.h` (added to include path). Raw `*mut c_void` crosses the boundary; Rust `const char*` results MUST be freed with `guinea_mpeg_free_string()`. No CXX/CXX-Qt/codegen.
- C++ registers `GuineaMpegBackendExt` and `MpvItem` into QML namespace `GuineaMpeg 1.0`; `backend` is also a root context property. QML consumes Rust data as JSON strings parsed in JS.
- CMake: Qt6 (Quick, QuickControls2, Widgets, Multimedia, DBus on Linux) + `pkg_check_modules(MPV REQUIRED mpv)` + cargo. Rust `libmpv2-sys` provides the mpv FFI; CMake's MPV pkg supplies only C++ headers (render API) — linker dedupes, no conflict. Windows finds mpv via `build/windows/.mpv-dev` or `MPV_DIR`.

## Project Structure
```
.
├── src/                       # C++ (QObject glue + renderer)
│   ├── main.cpp               # app setup, theme, context properties, QML load
│   ├── backend.{h,cpp}        # GuineaMpegBackendExt — profile/ffmpeg/mpv info to QML
│   └── mpvitem.{h,cpp}        # MpvItem (QQuickFramebufferObject) + MpvRenderer
├── qml/
│   ├── main.qml               # ApplicationWindow, StackView, loadVideo/startTranscoding
│   ├── VideoPreview.qml       # wraps MpvItem
│   ├── TimelineControl.qml    # trim handles (start/end time)
│   ├── ControlsPanel.qml      # right sidebar
│   ├── ProfileEditor.qml      # + ProfileEditor/{VideoPanel,AudioPanel,AdvancedPanel}.qml
│   ├── ProfileEditor/VideoPanel/   # Codec, PresetTune, PixelFormat, RateControl, Scaling, Animated, AV1, VP8VP9 sections
│   ├── Components/            # reusable controls (LabeledComboBox, SwitchRow, FormGroup, ...)
│   ├── Dialogs/               # Transcode, Options, About, EncoderCompat, warnings, ...
│   └── Utils/                 # Constants.js, DataUtils.js, FormatUtils.js, Centering.js
├── rust/
│   ├── Cargo.toml             # canonical version source
│   ├── include/guinea_mpeg_core.h
│   └── src/
│       ├── lib.rs
│       ├── backend.rs         # extern "C" wrappers for config
│       ├── config.rs          # profile load/save/merge (TOML)
│       ├── mpv.rs             # mpv handle lifecycle, commands, property cache
│       └── ffmpeg/            # args.rs, encoders.rs, codecs.rs, ffi.rs, types.rs, util.rs
├── build/                     # build scripts + Dockerfiles
├── translations/              # guinea-mpeg_<locale>.ts
├── default_profiles.toml
├── CMakeLists.txt
└── .gitlab-ci.yml             # dind package jobs + GitLab release on tags
```

## Key Components
### `GuineaMpegBackendExt` (src/backend.{h,cpp})
Plain `QObject`. Profile CRUD, options, video info, encoder detection/capabilities, ffmpeg command preview — all call Rust FFI. Transcode is the exception: `startTranscode()` builds args via `guinea_mpeg_build_ffmpeg_command()` then runs a real `QProcess` (QML needs `QProcess` signals to stream output live). Kills the previous process before starting a new one. Exposes `transcodeOutput` and `transcoding` as `Q_PROPERTY` + `transcodeFinished(bool)`.

### `MpvItem` + `MpvRenderer` (src/mpvitem.{h,cpp})
- `MpvItem` (QQuickFramebufferObject) owns `void* m_backend` from `guinea_mpeg_mpv_create()`; gets raw `mpv_handle*` via `guinea_mpeg_mpv_raw_handle()` for render context + wakeup. All mpv commands delegate to Rust.
- Event flow: mpv wakeup callback → Qt `onMpvEvents` signal → `handleMpvEvents()` → `guinea_mpeg_mpv_process_events()` bitmask → Qt signals (1=position, 2=duration, 4=playing).
- `MpvRenderer` stays in C++ (Renderer cannot be in Rust). Creates `mpv_render_context*` from the raw handle.

### Rust
- `config.rs` — `[[profiles]]` TOML; falls back to legacy `HashMap`, migrates `"svtav1"`→`"av1"`. User config overlays defaults by `p.name`.
- `mpv.rs` — options set on create: `vo=libmpv`, `keep-open=yes`, `cache=yes`.
- `ffmpeg/` — `args.rs` (`build_command()`, rate control per encoder family), `encoders.rs` (`encoder_family()`, software defaults), `ffi.rs` (`ffmpeg -hide_banner -encoders` parsing), `types.rs` (`EncoderCapabilities`).

## Common Mistakes & Solutions
### QML
- Never overwrite a bound property with `property = value` in JS — it **silently destroys the binding**. Debug with `QT_LOGGING_RULES="qt.qml.binding.removal.info=true"`.
- Propagate `var` props parent→child via `on_PropertyNameChanged` handlers (synchronous JS assignment), NOT `childProp: parent.prop` bindings — children that write their own value overwrite the binding. Example: `_capOverrides` in VideoPanel → sections.
- Encoder ComboBox one-step-behind bug: in `onCurrentIndexChanged`/`onAccepted` read the encoder via `_currentEncoderText()` (uses `textAt(currentIndex)`), never `combo.currentText` — it can lag one index change.
- `_loading` guard around model/list updates suppresses spurious `onCurrentTextChanged` → `loadProfile`. Set before populating combos in `Component.onCompleted`; defer `loadProfile` with `Qt.callLater` so child `Component.onCompleted` handlers run first.
- `Keys.onPressed` only works on `Item` — attach to a focused child `Item` (e.g. `keyCatcher`), never `Dialog`/`Popup`.
- `FileDialog.selectedFile` is a `file://` URL — strip prefix only for C++ paths; build `file://` URLs with `encodeURI()` for spaces/special chars.
- Avoid property names colliding with parent scope IDs (`appWindow: appWindow` → binding loop; rename to `hostWindow`).
- Prefer `Flickable` over `ScrollView` when a scrollbar must not reserve space.
- QML exit 255 with no stderr: rerun with `QT_FORCE_STDERR_LOGGING=1`.

### MPV
- **Must** `setMirrorVertically(true)` on MpvItem AND pass `MPV_RENDER_PARAM_FLIP_Y = 1` — mpv renders upside-down into the FBO.
- `MPV_RENDER_PARAM_OPENGL_FBO` requires the full `mpv_opengl_fbo` struct (`fbo`, `w`, `h`, `internal_format`), not just an int.
- Defer `loadfile` until `mpv_render_context*` exists: `setSource()` stores `m_pendingSource`; `MpvRenderer` ctor calls `loadPendingSource()` via `QMetaObject::invokeMethod`. `m_renderReady` gates immediate vs deferred load.
- `setlocale(LC_NUMERIC, "C")` after `QApplication` (it overrides the locale).

### Transcoding
- ffmpeg writes progress to **stderr**, not stdout — capture with `QProcess::readyReadStandardError`.
- `-c:a copy` works for MP4/MKV but NOT WebM — use `libopus` for `.webm`.

### TimelineControl
- Clamp handle x to `[0, track.width - width]`; never `clip: true` on the root (kills MouseArea events); guard programmatic `startTime`/`endTime` changes (e.g. on file load) so handlers don't seek the player.

### Encoder handling (ProfileEditor)
- VP8/VP9: emit `-deadline <preset>` + `-cpu-used <N>`, never `-preset`.
- Encoder ComboBox model is set in `rebuildEncoderModel()` (no binding) to avoid stale models when switching same-codec profiles; forced to default when loading via `setData`.
- Editable ComboBoxes (preset/tune/pixfmt) use a `"default"` sentinel at index 0 = `null` (omitted from ffmpeg command). Pixfmt always prepends the sentinel even when encoder capabilities override the list.
- `applyEncoderCapabilities()` must NOT be `_loading`-guarded (needs to run during profile load).
- Preset model is codec-aware (H.264/H.265 `ultrafast..placebo`, VP8/VP9 `good/best/realtime`, SVT-AV1 `0..13`), overridden by the encoder's own preset list when present.
- VAAPI encoders use `-compression_level` instead of `-preset`/`-tune` (`EncoderCapabilities.uses_compression_level`).

## Build
- Always use `build/linux-build.sh`, never manual cmake. Rust builds automatically via cargo.
- Flags: `--clean` (removes `out/` + `rust/target/`), `--package <deb,rpm,pacman,flatpak,appimage,generic,all>`, `--no-build`, `--version X.Y.Z` (delegates to `update-version.sh`), `--release`, `--no-strip`.
- Default (no flags): Debug build to `out/generic/` (the UpdateBanner always shows, gated by `buildInfo.debugBuild` ← `QT_NO_DEBUG`). `--release` or any `--package` produces a Release build (banner behaves normally) and strips binaries; `--no-strip` disables stripping. `--no-build` + `--package appimage` is an error (needs fresh in-Docker build).
- `crate-type = ["cdylib"]`; plain `extern "C"` symbols link without `--whole-archive`.
- deb/rpm/pacman: Docker builds (`build/docker/*.Dockerfile`) then fpm packaging; `stage_package()` runs `patchelf --add-rpath '$ORIGIN/../lib/$PKGNAME'` so the binary finds the Rust `.so`.
- flatpak: host `flatpak-builder`, SDK `org.kde.Platform//6.10`.

## Translations
- `.ts` sources live in `translations/`, listed in `qml/CMakeLists.txt` via `qt_add_translations` (compiled into `:/i18n/qml/`; `main.cpp` loads them).
- Update the source strings (add/modify `qsTr()` etc.) and refresh all `.ts` files:
  ```
  ./build/update-translations.sh     # runs cmake target guinea_mpeg_lupdate
  ```
- Then translate the new `<translation>` entries in each `translations/guinea-mpeg_<locale>.ts` (Linguist or by hand). `.qm` compilation happens during the normal build.
- Add a new locale: create `translations/guinea-mpeg_<locale>.ts` (via lupdate) and append it to the `TS_FILES` list in `qml/CMakeLists.txt`.
