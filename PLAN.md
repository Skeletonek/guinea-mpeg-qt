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

## Phase 2 — DRY Fixes (Medium risk)

### C++
- [ ] Extract `launchFfmpeg()` from `src/backend.cpp:263` vs `302` (~80% clone `startTranscode`/`startPreview`)
- [ ] Extract `releaseAfterDeleteLater()` for `src/backend.cpp:332`+`396` duplicate `deleteLater+release`
- [ ] Unify `takeRustString()` `src/backend.cpp:21` vs `src/main.cpp:50` into `rust_string_utils.h`
- [ ] Helper for 8× `takeRustString(guinea_mpeg_X…)` at `src/backend.cpp:120-249`
- [ ] `makeVideoMap()`/`makeAudioMap()` for `src/backend.cpp:210-228`
- [ ] Table-drive `makeDarkPalette()`/`makeLightPalette()` `src/main.cpp:87-123`

### Rust
- [ ] Extract `parse_content()` deduping `rust/src/config.rs:166` vs `314`
- [ ] Unify `to_json`/`to_c_string` `rust/src/backend.rs:4` vs `rust/src/ffmpeg/util.rs:37`
- [ ] Extract `base_filter_parts()` for `rust/src/ffmpeg/args.rs:171` vs `245`
- [ ] Table-drive hwaccel `rust/src/ffmpeg/args.rs:311-347`
- [ ] Single `family`/`caps` compute (`args.rs:62`, `303`, `364`)
- [ ] `f64_to_ms` for `rust/src/mpv.rs:301` vs `331`, `cstr_ptr` helper for `mpv.rs:35-64`

### QML
- [ ] `SectionBase.qml` for 22× `if(!loading) changed()` (`RateControlSection.qml:56` etc.)
- [ ] Centralize `rebuildComboModel()` for `PresetTuneSection.qml:16+27` + `PixelFormatSection.qml:15`
- [ ] `BaseConfirmDialog.qml` for `DeleteProfileDialog.qml:12` + `RestoreDefaultsDialog.qml:10` + `ExitAdvancedDialog.qml:10` + `OverwriteConfirmDialog.qml:12`
- [ ] `WarningDialog.qml` for `FfmpegWarningDialog.qml:1` vs `MpvWarningDialog.qml:1`
- [ ] `adjustVolume()` for `qml/VideoPreview.qml:118+150+241`
- [ ] Use `Object.assign` / `DataUtils.buildProfileData` at `qml/ProfileEditor/VideoPanel.qml:68`

### Build
- [ ] Centralize version extraction 5× (`build/linux-build.sh:52`, `CMakeLists.txt:105`, etc.)
- [ ] Extract `build/common.sh` (`SCRIPT_DIR/PROJECT_DIR/OUT_DIR`)
- [ ] Unify Docker preamble (`build/linux-build.sh:216` vs `298`) + strip impls
- [ ] Matrix-ify `.gitlab-ci.yml:90` 8 package jobs

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
