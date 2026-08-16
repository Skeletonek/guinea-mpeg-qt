# Agent Knowledge Base

## Architecture
- Qt Quick UI (QML) + C++ glue (`src/`) + Rust business logic compiled as a `cdylib` (`libguinea_mpeg_core.so`) shipped beside the binary.
- FFI: Rust exports plain `extern "C"` functions declared in `rust/include/guinea_mpeg_core.h`. Raw `*mut c_void` crosses the boundary; Rust `const char*` results MUST be freed with `guinea_mpeg_free_string()`. No CXX/codegen. QML consumes Rust data as JSON strings parsed in JS.
- C++ registers `GuineaMpegBackendExt` + `MpvItem` into QML namespace `GuineaMpeg 1.0`; `backend` is also a root context property.
- CMake: Qt6 (Quick, QuickControls2, Widgets, Multimedia, DBus on Linux) + `pkg_check_modules(MPV REQUIRED mpv)` + cargo. Rust `libmpv2-sys` gives the mpv FFI; CMake's MPV pkg supplies only C++ render headers — linker dedupes, no conflict. Windows finds mpv via `build/windows/.mpv-dev` or `MPV_DIR`.

## Layout
```
src/                  C++ glue + renderer
  backend.{h,cpp}       GuineaMpegBackendExt — profile/options/info to QML
  mpvitem.{h,cpp}       MpvItem (QQuickFramebufferObject) + MpvRenderer
  main.cpp              app setup, theme, context properties, QML load
qml/
  main.qml              ApplicationWindow, StackView, loadVideo/startTranscoding
  VideoPreview.qml      wraps MpvItem
  TimelineControl.qml   trim handles (start/end time)
  ControlsPanel.qml     right sidebar
  ProfileEditor.qml     + VideoPanel/AudioPanel/AdvancedPanel + VideoPanel/*Section.qml
  Components/           reusable controls (LabeledComboBox, SwitchRow, FormGroup, ...)
  Dialogs/              Transcode, Options, About, Export/Import, warnings, ...
  Utils/                Constants.js, DataUtils.js, FormatUtils.js, Centering.js
rust/                   Rust core (cdylib)
  include/guinea_mpeg_core.h
  src/                  lib, backend, config, mpv + ffmpeg/{args,encoders,codecs,ffi,types,util}
  Cargo.toml            canonical version source
build/                  linux-build.sh + Dockerfiles
translations/           guinea-mpeg_<locale>.ts
default_profiles.toml
.gitlab-ci.yml          lint on push + dind packages + tag release
```

## Key Components
- `GuineaMpegBackendExt` (plain QObject): profile CRUD, options, video info, encoder detection — all Rust FFI. Transcode is the exception: `startTranscode()` builds args via `guinea_mpeg_build_ffmpeg_command()` then runs a real `QProcess` (QML needs its signals to stream output live). Kills the previous process first. Exposes `transcodeOutput`/`transcoding` Q_PROPERTYs + `transcodeFinished(bool)`.
- `MpvItem` owns `void* m_backend` from `guinea_mpeg_mpv_create()`; raw `mpv_handle*` via `guinea_mpeg_mpv_raw_handle()` for render context + wakeup; all mpv commands delegate to Rust. Events: wakeup → `onMpvEvents` → `handleMpvEvents()` → `guinea_mpeg_mpv_process_events()` bitmask → Qt signals (1=position, 2=duration, 4=playing). `MpvRenderer` stays in C++ (Renderer cannot be Rust).
- Rust: `config.rs` = `[[profiles]]` TOML, legacy HashMap fallback, `"svtav1"`→`"av1"` migration, user overlays defaults by name, export only user profiles, import warns on conflicts. `mpv.rs` options: `vo=libmpv`, `keep-open=yes`, `cache=yes`. `ffmpeg/`: `build_command()` rate control per encoder family, `ffmpeg -hide_banner -encoders` parsing, `EncoderCapabilities`.

## Gotchas
- **QML binding rule**: never `property = value` in JS — it silently destroys the binding. Debug with `QT_LOGGING_RULES="qt.qml.binding.removal.info=true"`.
- Propagate `var` props parent→child via `on_*Changed` handlers (sync JS), NOT bindings — children that write their own value overwrite the binding (e.g. `_capOverrides` VideoPanel → sections).
- Encoder ComboBox one-step-behind: in `onCurrentIndexChanged`/`onAccepted` read via `_currentEncoderText()` (`textAt(currentIndex)`), never `combo.currentText`.
- `_loading` guard around model/list updates suppresses spurious `onCurrentTextChanged` → `loadProfile`; set before populating combos in `Component.onCompleted`, defer `loadProfile` via `Qt.callLater`. `applyEncoderCapabilities()` must NOT be `_loading`-guarded.
- `FileDialog.selectedFile` is `file://` — strip prefix only for C++ paths, build URLs with `encodeURI()`. `folder` is unset on first open — never build `currentFile` from it; only set it to an absolute path when the folder is known.
- `Keys.onPressed` only works on a focused `Item` (e.g. `keyCatcher`), never `Dialog`/`Popup`. `import QtQuick.Dialogs` must be unversioned on Qt 6.
- Custom `Dialog` header/footer need `implicitHeight` or the popup doesn't reserve space.
- **UI spacing**: margins/paddings/spacings may only be `4`/`8`/`16` (round up: `6`→`8`, `10`→`8`, `20`→`16`). Dialog gutters on the `Dialog` via `padding`/`topPadding`, never on child `anchors.fill`+`margins` (double-inset). `8` form spacing, `16` dialog gutters, `4` tight groups. Spacing-derived width math must reference the variable, not a hard-coded leftover.
- **MPV**: `setMirrorVertically(true)` on MpvItem AND `MPV_RENDER_PARAM_FLIP_Y = 1` (mpv renders upside-down into the FBO). `MPV_RENDER_PARAM_OPENGL_FBO` needs the full `mpv_opengl_fbo` struct, not an int. Defer `loadfile` until `mpv_render_context*` exists (`m_pendingSource` + `loadPendingSource()` via `QMetaObject::invokeMethod`; `m_renderReady` gates). `setlocale(LC_NUMERIC, "C")` after `QApplication`.
- **Transcoding**: ffmpeg progress goes to **stderr** (`readyReadStandardError`). `-c:a copy` works for MP4/MKV but NOT WebM — use `libopus`.
- **TimelineControl**: clamp handle x to `[0, track.width - width]`; never `clip: true` on root (kills MouseArea events); guard programmatic `startTime`/`endTime` changes so handlers don't seek.
- **Encoders**: VP8/VP9 use `-deadline` + `-cpu-used`, never `-preset`. VAAPI uses `-compression_level` instead of `-preset`/`-tune`. Editable combos (preset/tune/pixfmt) use a `"default"` sentinel at index 0 = `null` (omitted from command). Encoder combo model set in `rebuildEncoderModel()` (no binding). Preset model is codec-aware (H.264/H.265 `ultrafast..placebo`, VP8/VP9 `good/best/realtime`, SVT-AV1 `0..13`), overridden by the encoder's own list.

## Build
- Always use `build/linux-build.sh`, never manual cmake (Rust builds via cargo). Flags: `--clean`, `--package <deb,rpm,pacman,flatpak,appimage,generic,all>`, `--arch <x86_64|aarch64>`, `--no-build`, `--version`, `--release`, `--no-strip`.
- Default = Debug to `out/generic/`; Release only with `--release` (banner gated by `buildInfo.debugBuild`). Rust follows: `--release` only when `CMAKE_BUILD_TYPE=Release`.
- aarch64 `generic`/`deb`/`rpm` via `docker buildx --platform linux/arm64` + QEMU binfmt; aarch64 pacman/appimage/flatpak cross-builds rejected; flatpak arch = host. Docker mounts `out/.cargo-home` as `CARGO_HOME` (persistent registry). `stage_package()` runs `patchelf --add-rpath '$ORIGIN/../lib/$PKGNAME'` for the Rust `.so`.
- flatpak: host `flatpak-builder`, SDK `org.kde.Platform//6.10`. appimage: bundle `libqxdgdesktopportal.so` into `platformthemes/`; AppRun sets `QT_QPA_PLATFORMTHEME=xdgdesktopportal`.
- Windows: `windows-build.ps1`/`download-vendor.ps1` with `-Arch x86_64|arm64`; arm64 needs mpv-dev-aarch64 + BtbN winarm64 ffmpeg + Qt `msvc2022_arm64`, runs only on WoA.
- `-mdirect-extern-access` is x86-64-only GCC — keep the `CMAKE_SYSTEM_PROCESSOR` guard.

## Tests
- Run everything with `./build/run-tests.sh` (Rust cargo, then QML + C++ FFI via ctest into `out/.build-tests`). `--clean` for a fully fresh run. Local-only (CI untouched).
- Rust: `rust/src/tests/` (`#[cfg(test)] mod tests;`); `with_config_dir()` overrides `GUINEA_MPEG_CONFIG_DIR` (Mutex-serialized, fixtures in `<dir>/guinea-mpeg/`). Test-only helpers must be `#[cfg(test)]`.
- QML: `tests/qml/tst_*.qml` via `tests/tst_qml_main.cpp` (`QUICK_TEST_MAIN` + `QUICK_TEST_SOURCE_DIR` compile definition — Qt 6.11 lacks the `qt_add_executable` keyword). Imports app JS from `../../qml/Utils/`.
- C++ FFI: `tests/cpp/tst_backend_ffi.cpp` links `${RUST_LIB}`; `initTestCase()` calls `setlocale(LC_NUMERIC, "C")`; every returned `const char*` must be `guinea_mpeg_free_string()`-ed.
- Headless: ctest sets `QT_QPA_PLATFORM=offscreen`; no display/mpv GL/real ffmpeg pipeline in tests.

## Lint & Format
- `./build/run-lint.sh` (checks, fails on violations). Flags: `--fix` (cargo fmt, cargo clippy --fix, qmlformat -i -f, clang-format -i), `--only <rust|cpp|qml>`, `--cpp-tidy` (also clang-tidy, configures `out/.build-lint` with clang++), `--help`.
- Rust: `cargo fmt --all -- --check` + `cargo clippy --all-targets -- -D warnings`. QML: `qmllint -I qml` over everything + per-file `qmlformat` equality on `.qml` only (Qt 6.11 qmlformat exits 1 on standalone `.js` even when valid). C++: `clang-format --dry-run --Werror` over `src/` + `tests/cpp/`; clang-tidy only `src/*.cpp` (headers standalone flag `MpvItem::position`, an intentional QML property name).
- Styles: `.clang-format` is K&R (Attach braces, 4-space, 120 cols). `.clang-tidy` = `bugprone-*,clang-analyzer-*,performance-*`, `WarningsAsErrors: '*'`; `m_currentTranscode.release()` carries `// NOLINT` (ownership moves to `deleteLater`).
- CI: `lint` stage on every push, `allow_failure: true` (never blocks packages/releases); package jobs skip pushes via `.skip-on-push`. clang-tidy is local-only.

## Translations
- `.ts` in `translations/`, listed in `qml/CMakeLists.txt` (`qt_add_translations` → `:/i18n/qml/`). Refresh with `./build/update-translations.sh` (lupdate), translate new entries, add new locales via `TS_FILES`.
