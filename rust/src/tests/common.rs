use std::path::Path;
use std::sync::Mutex;

// Config tests share the process-global CONFIG cache and the
// GUINEA_MPEG_CONFIG_DIR env var, so they must not run concurrently.
static CONFIG_TEST_LOCK: Mutex<()> = Mutex::new(());

pub(crate) const DEFAULT_PROFILES_TOML: &str = r#"
[[profiles]]
name = "H.264 High"
codec = "h264"
encoder = "libx264"
crf = 18
preset = "slow"
audio_bitrate = "256k"

[[profiles]]
name = "VP9 Low"
codec = "vp9"
encoder = "libvpx-vp9"
crf = 40
preset = "good"
"#;

// Points the config layer at `dir` for the duration of `f`, then restores the
// real user config dir. `f` receives `dir` so it can write fixtures.
pub(crate) fn with_config_dir(dir: &Path, f: impl FnOnce(&Path)) {
    let _guard = CONFIG_TEST_LOCK.lock().unwrap();
    std::env::set_var("GUINEA_MPEG_CONFIG_DIR", dir);
    crate::config::set_config(crate::config::merge_configs());

    struct Reset;
    impl Drop for Reset {
        fn drop(&mut self) {
            std::env::remove_var("GUINEA_MPEG_CONFIG_DIR");
            crate::config::set_config(crate::config::merge_configs());
        }
    }
    let _reset = Reset;

    f(dir);
}

pub(crate) fn write_default_profiles(dir: &Path, content: &str) {
    let sub = dir.join("guinea-mpeg");
    std::fs::create_dir_all(&sub).unwrap();
    std::fs::write(sub.join("default_profiles.toml"), content).unwrap();
}