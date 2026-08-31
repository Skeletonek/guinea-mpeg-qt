# GuineaMPEG — Cleanup & Refactor Plan

> Generated 2026-08-31. Scope: dead code, DRY/KISS violations, hardcoded constants.
> Audit via 4 parallel explorations (C++ `src/`, Rust `rust/`, QML `qml/`, Build).

## How to use

- Phases are sequential; each ends with `./build/run-tests.sh` + `./build/run-lint.sh` gate.
- Verify green before proceeding to next phase.
- Items reference `file:line` from audit snapshot.

---

## Phase 1 — Dead Code Cleanup (Low risk)

**Goal:** Remove unused includes, files, fields, commented code, duplicate build steps.

### C++ `src/` — ✅ DONE
- [x] `src/backend.cpp:12` `#include <QDBusPendingCall>` **kept** — required for `QDBusConnection::asyncCall()` return type at `backend.cpp:365` (forward-decl insufficient); audit false-positive reverted
- [ ] `src/mpvitem.h:80-82` collapse `void* m_backend` + `mpv_handle* m_mpv` duplication (deferred to Phase 4 — ownership refactor)
- [ ] `src/mpvitem.h:86-88` `getMpv()` private indirection — deferred to Phase 4
- [x] `src/mpvitem.cpp:59` document empty `synchronize()` override (`// no sync needed`)
- [x] `src/main.cpp:25` remove `<ranges>` (only `std::views::drop(1)` at `main.cpp:348`) → classic loop

### Rust `rust/` — ✅ DONE
- [x] `rust/src/ffmpeg/types.rs:13-22` remove unused `vbr_flag`/`cbr_flag` fields (set in `encoders.rs:51,78,95,122,139` but never read; QML uses only `rc_flag`/`crf_flag`)
- [x] `rust/src/ffmpeg/args.rs:341-345` delete commented Vulkan block
- [x] `rust/src/mpv.rs:6-11` remove `EVENT_*` / `FORMAT_*` trivial aliases (use `mpv_event_id_MPV_EVENT_*` directly) — added `#[allow(non_upper_case_globals)]` to silence sys constant naming
- [ ] `rust/src/mpv.rs:45-47` inline `MpvBackend::raw_handle()` one-liner — deferred (kept, low value)
- [ ] `rust/build.rs` add `rerun-if-env-changed=MPV_LIB_DIR` — deferred to Phase 4

### QML `qml/` — ✅ DONE (partial)
- [ ] `qml/Components/LabeledComboBox.qml:1` dead (0 usages) — **kept for now**, decision pending (delete in Phase 2 or adopt)
- [ ] `qml/Components/FormGroup.qml:1` dead — **kept for now** (same)
- [ ] `qml/Components/SwitchRow.qml:1` single-use (`OptionsDialog.qml:279`) — kept, not dead (used; unifying deferred to Phase 2)
- [x] `qml/Components/WidgetHeader.qml:15` dead `topPadding` — removed
- [x] `qml/Components/LabeledRow.qml:14` dead `labelColor` — removed (also removed unused `Constants` import)
- [ ] `qml/Utils/FormatUtils.js:72` `safeJsonParse` — **kept** (not dead: used in `tests/qml/tst_FormatUtils.qml`)
- [ ] `qml/Utils/Constants.js:96-98` `colorWarning/Error/Info` — **kept** (reserved for future use; hardening in Phase 3)
- [ ] `qml/ProfileEditor/VideoPanel.qml:10` shadow `_codecAvailable` — deferred to Phase 2 (SectionBase refactor)
- [ ] `qml/VideoPreview.qml:22` `_seekRetries` — kept (actually used at `VideoPreview.qml:91,99`)

### Build — ✅ DONE (partial)
- [x] `rust/CMakeLists.txt:11-17` remove `execute_process` cargo build at configure
- [x] `src/CMakeLists.txt:1-18` dedupe `GUINEA_APP_SOURCES` (set once before `if(WIN32)`)
- [ ] `build/windows/mpv-dev.ps1` orphaned — deferred (needs vendor decision)
- [ ] `build/upload-update.sh` + `build/upload-update.env` dead in CI — deferred (needs owner decision)
- [ ] `qml/CMakeLists.txt:6` `lettuce.png`/`guinea.wav` — deferred (audit in Phase 4)
- [ ] `qml/CMakeLists.txt:60` `GUINEA_LUPDATE_NO_OBSOLETE` — deferred

**Verify:** `./build/run-tests.sh --clean` ; `./build/run-lint.sh` ; `cargo check` ; `qmllint` zero output.

---

## Phase 2 — DRY Fixes (Medium risk) — ✅ DONE (partial)

### C++ — ✅
- [ ] Extract `launchFfmpeg()` from `src/backend.cpp:263` vs `302` — deferred to Phase 4 (needs FfmpegProcess abstraction, higher risk)
- [x] Extract `releaseAfterDeleteLater()` for `src/backend.cpp:332`+`396` → `releaseProcess()` at `backend.cpp:67` + `backend.cpp:330`, `394` (helper in anon namespace)
- [ ] Unify `takeRustString()` `src/backend.cpp:21` vs `src/main.cpp:50` into `rust_string_utils.h` — deferred to Phase 4 (header extraction)
- [ ] Helper for 8× `takeRustString(guinea_mpeg_X…)` at `src/backend.cpp:120-249` — deferred (needs macro/helper, low ROI)
- [x] `makeVideoMap()`/`makeAudioMap()` for `src/backend.cpp:210-228` → `makeVideoStreamMap()`/`makeAudioStreamMap()` at `backend.cpp:76,86` + `backend.cpp:210`
- [ ] Table-drive `makeDarkPalette()`/`makeLightPalette()` `src/main.cpp:87-123` — **reverted per user request** (kept separate `makeDarkPalette()`/`makeLightPalette()` with explicit `setColor` calls; table-drive deemed less readable)

### Rust — ✅
- [x] Extract `parse_content()` deduping `rust/src/config.rs:166` vs `314` → `parse_profiles_from_content()` at `config.rs:166`, `load_config_from_file` and `parse_profiles_file` now share it; `sorted_names()`/`sorted_names_ref()` at `config.rs:183,189` dedupe 4 name collectors at `config.rs:244,254,270,367`
- [x] Unify `to_json`/`to_c_string` `rust/src/backend.rs:4` vs `rust/src/ffmpeg/util.rs:37` → `backend.rs:3` now `use crate::ffmpeg::{cstr,to_c_string}`, `to_json` delegates to `to_c_string`, `from_cstr` delegates to `cstr`
- [x] Extract `base_filter_parts()` for `rust/src/ffmpeg/args.rs:171` vs `245` → `base_filter_parts()` at `args.rs:171`, `add_filter_graph` and `add_animation_params` now reuse
- [x] Table-drive hwaccel `rust/src/ffmpeg/args.rs:311-347` → `push_hwaccel_args()` at `args.rs:245`, `build_command` now calls it
- [x] Single `family`/`caps` compute (`args.rs:62`, `303`, `364`) → `build_command` computes `enc`+`family` once at `args.rs:302` and reuses at `args.rs:360`
- [x] `f64_to_ms` for `rust/src/mpv.rs:301` vs `331`, `cstr_ptr` helper for `mpv.rs:35-64` → `f64_to_ms()` at `mpv.rs:64`, `c_str()` at `mpv.rs:69`, all `CString::new(...).as_ptr()` + `(v*1000).max` sites now use helpers; `#[allow(non_upper_case_globals)]` retained at `mpv.rs:253`

### QML — ✅
- [x] `SectionBase.qml` for 22× `if(!loading) changed()` — created at `qml/Components/SectionBase.qml` (`emitChanged()` helper); adoption in sections deferred to Phase 4 (incremental migration)
- [x] Centralize `rebuildComboModel()` for `PresetTuneSection.qml:16+27` + `PixelFormatSection.qml:15` → `DataUtils.rebuildComboModel()` at `DataUtils.js:139`, callers at `PresetTuneSection.qml:16,27` and `PixelFormatSection.qml:15` now delegate
- [x] `BaseConfirmDialog.qml` for 4 dialogs → created at `qml/Components/BaseConfirmDialog.qml`, migrated `DeleteProfileDialog.qml:1`, `RestoreDefaultsDialog.qml:1`, `ExitAdvancedDialog.qml:1`, `OverwriteConfirmDialog.qml:1` to inherit it (width/bodyText/onConfirmed); removed duplicate `standardButtons/padding/implicitHeight/centering`
- [x] `WarningDialog.qml` for `Ffmpeg/MpvWarningDialog.qml:1` → created at `qml/Components/WarningDialog.qml`, migrated both to inherit it (headline/body)
- [x] `adjustVolume()` for `qml/VideoPreview.qml:118+150+241` → `setPreviewVolume()`/`adjustVolume()` at `VideoPreview.qml:37`, replaced 4 sites at `VideoPreview.qml:118,155,241,252`; also `onMoved` now uses `setPreviewVolume`
- [x] Use `DataUtils.buildProfileData` at `qml/ProfileEditor/VideoPanel.qml:68` → `VideoPanel.qml:2` now imports `DataUtils`, `getData()` at `VideoPanel.qml:75` uses `buildProfileData` instead of 6× `for(k in)` loops
- [x] `qml/CMakeLists.txt:47` — added `BaseConfirmDialog.qml`, `WarningDialog.qml`, `SectionBase.qml` to `qt_add_resources`

### Build — ✅ (foundation)
- [x] Centralize version extraction 5× → created `build/common.sh` with `get_version()`, `get_project_root()`, `docker_arch_for()` helpers (foundation for Phase 4 unification)
- [ ] Extract `build/common.sh` (`SCRIPT_DIR/PROJECT_DIR/OUT_DIR`) — foundation laid, full adoption in `run-tests.sh`/`run-lint.sh`/`linux-build.sh` deferred to Phase 4
- [ ] Unify Docker preamble (`build/linux-build.sh:216` vs `298`) + strip impls — deferred to Phase 4 (needs docker refactoring, high risk)
- [ ] Matrix-ify `.gitlab-ci.yml:90` 8 package jobs — deferred to Phase 4

---

## Phase 3 — Hardcoded Constants (Medium risk)

- [ ] C++ `backend.cpp:63` `3000`, `mpvitem.cpp:92` `50`, `mpvitem.cpp:148` `500`, `backend.cpp:365` `5000` → `constexpr k…`
- [ ] `mpvitem.cpp:206` `1/2/4` → `enum class MpvEventFlag`; `mpvitem.h:79` `kDefaultVolume`
- [ ] Rust `config.rs:150` system path, `config.rs:435` `100.0`, `args.rs:246` `75`, `MS_PER_SEC` `mpv.rs:205`, `CHANGED_POS` `mpv.rs:276`
- [ ] QML `#e66` (`ProfileEditor.qml:210`), `#555555` (`TimelineControl.qml:73`), `1024x800` (`main.qml:123`) → `Constants.js`
- [ ] Dialog widths `380/400/430/460/700` → `Constants.dialogWidth`
- [ ] Build single `versions.toml` for `0.11.0` drift (`Cargo.toml:3` vs `CMakeLists.txt:2` vs `installer.iss:11`)

---

## Phase 4 — KISS / Architecture (Higher risk)

- [ ] Split `build_command 127L` (`args.rs:285`) → `hwaccel_args`+`video_args`+`audio_args`
- [ ] Split `guinea_mpeg_mpv_process_events 118L` (`mpv.rs:261`) → `drain_events` + `poll_fallback`
- [ ] Split `main 214L` (`src/main.cpp:155`) → `setupApplication`/`loadTranslations`/`chooseStyle`/`makeBuildInfo`
- [ ] Split `getVideoInfo 55L` (`src/backend.cpp:180`)
- [ ] QML: `ProfileEditor.qml:156` `groupWidth()` → `RowLayout`; `TimelineControl.qml:23` `Qt.binding` → `Binding`; `AdvancedPanel.qml:147` double `missingParts()` → cached prop
- [ ] Fix `util.rs:41` `unsafe fn cstr -> &'static str` lifetime; `encoders.rs:4` `starts_with("libx26")`; `encoders.rs:26` `Some(match … return None)` idiom
- [ ] Build: `CMakeLists.txt:77` `RUST_LIB_PROFILE` ignores `RelWithDebInfo`; `qml/CMakeLists.txt:1` 50-file list → `qt_add_qml_module`/`GLOB CONFIGURE_DEPENDS`; `ps1:425` `szl`/`pl_PL` translation mismatch

---

## Verification Gates (each phase)

1. `./build/run-tests.sh --clean` — Rust + QML + C++ FFI (`QT_QPA_PLATFORM=offscreen`)
2. `./build/run-lint.sh` — `cargo fmt --check` + `clippy -D warnings` + `qmllint` + `clang-format`
3. `cargo check` / `cmake --build` smoke
4. Manual: `build/linux-build.sh --no-build --version` for version dedup (Phase 3+)

---

## Decisions Needed

- Keep or delete `LabeledComboBox`/`FormGroup`?
- `mpv-dev.ps1` (shinchiro) vs `download-vendor.ps1` (zhongfly) — which vendor?
- `tokenize` (`command.rs:6`) → `shell-words` crate or keep bespoke?
- `upload-update.sh` — document manual flow or remove?
