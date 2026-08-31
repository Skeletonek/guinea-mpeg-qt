use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

static CONFIG: Mutex<Option<AppConfig>> = Mutex::new(None);

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VideoProfile {
    #[serde(default)]
    pub name: String,
    pub codec: String,
    pub container: Option<String>,
    pub crf: Option<i32>,
    pub bitrate: Option<String>,
    pub preset: Option<String>,
    pub tune: Option<String>,
    pub pixel_format: Option<String>,
    pub resolution: Option<String>,
    pub framerate: Option<f64>,
    pub encoder: Option<String>,
    pub tile_rows: Option<u32>,
    pub tile_columns: Option<u32>,
    pub enable_qm: Option<bool>,
    pub cpu_used: Option<i32>,
    pub compression_level: Option<String>,
    #[serde(default = "default_audio_bitrate")]
    pub audio_bitrate: String,
    pub audio_channels: Option<u32>,
    pub audio_sample_rate: Option<u32>,
    #[serde(default)]
    pub extra_args: Vec<String>,
    pub quality: Option<u32>,
    pub loop_enabled: Option<bool>,
    pub video_enabled: Option<bool>,
    pub audio_enabled: Option<bool>,
    pub audio_codec: Option<String>,
    pub rate_control: Option<String>,
    #[serde(default)]
    pub video_stream_indices: Vec<u32>,
    #[serde(default)]
    pub audio_stream_indices: Vec<u32>,
    #[serde(default)]
    pub custom_command: Option<String>,
}

fn default_audio_bitrate() -> String {
    "128k".into()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppOptions {
    #[serde(default = "default_language")]
    pub language: String,
    #[serde(default = "default_theme")]
    pub theme: String,
    #[serde(default = "default_color_scheme")]
    pub color_scheme: String,
    #[serde(default = "default_hwdec")]
    pub hwdec: String,
    #[serde(default = "default_preview_volume")]
    pub preview_volume: f64,
    #[serde(default = "default_check_for_updates")]
    pub check_for_updates: bool,
}

fn default_language() -> String {
    "system".into()
}

fn default_theme() -> String {
    "system".into()
}

fn default_color_scheme() -> String {
    "system".into()
}

fn default_hwdec() -> String {
    "auto-copy".into()
}

fn default_preview_volume() -> f64 {
    100.0
}

fn default_check_for_updates() -> bool {
    true
}

impl Default for AppOptions {
    fn default() -> Self {
        Self {
            language: default_language(),
            theme: default_theme(),
            color_scheme: default_color_scheme(),
            hwdec: default_hwdec(),
            preview_volume: default_preview_volume(),
            check_for_updates: default_check_for_updates(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub(crate) struct AppConfig {
    #[serde(default)]
    pub(crate) profiles: Vec<VideoProfile>,
    #[serde(default)]
    pub(crate) options: AppOptions,
}

// Base directory for the app's config. Tests (and power users) can redirect it
// with GUINEA_MPEG_CONFIG_DIR; otherwise dirs::config_dir() is used.
pub(crate) fn config_dir() -> PathBuf {
    if let Ok(dir) = std::env::var("GUINEA_MPEG_CONFIG_DIR") {
        if !dir.trim().is_empty() {
            return PathBuf::from(dir);
        }
    }
    dirs_or_fallback()
}

fn user_config_path() -> PathBuf {
    let mut path = config_dir();
    path.push("guinea-mpeg");
    path.push("config.toml");
    path
}

fn defaults_path() -> PathBuf {
    // Override lookup so tests can point defaults at a fixture (GUINEA_MPEG_CONFIG_DIR).
    let override_defaults = config_dir()
        .join("guinea-mpeg")
        .join("default_profiles.toml");
    if override_defaults.exists() {
        return override_defaults;
    }
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            let p = dir.join("default_profiles.toml");
            if p.exists() {
                return p;
            }
            let p = dir.join("../share/guinea-mpeg/default_profiles.toml");
            if p.exists() {
                return p.canonicalize().unwrap_or(p);
            }
        }
    }
    PathBuf::from("/usr/share/guinea-mpeg/default_profiles.toml")
}

fn dirs_or_fallback() -> PathBuf {
    dirs::config_dir().unwrap_or_else(|| PathBuf::from("."))
}

fn migrate_codec_key(profiles: &mut [VideoProfile]) {
    // migrate old "svtav1" codec key to "av1"
    for p in profiles {
        if p.codec == "svtav1" {
            p.codec = "av1".to_string();
        }
    }
}

fn parse_profiles_from_content(content: &str) -> Option<Vec<VideoProfile>> {
    #[derive(Deserialize)]
    struct MapConfig {
        profiles: HashMap<String, VideoProfile>,
    }
    if let Ok(mut cfg) = toml::from_str::<AppConfig>(content) {
        migrate_codec_key(&mut cfg.profiles);
        return Some(cfg.profiles);
    }
    if let Ok(cfg) = toml::from_str::<MapConfig>(content) {
        let mut profiles: Vec<VideoProfile> = cfg.profiles.into_values().collect();
        migrate_codec_key(&mut profiles);
        return Some(profiles);
    }
    None
}

fn sorted_names(profiles: Vec<VideoProfile>) -> Vec<String> {
    let mut names: Vec<String> = profiles.into_iter().map(|p| p.name).collect();
    names.sort();
    names
}

fn sorted_names_ref(profiles: &[VideoProfile]) -> Vec<String> {
    let mut names: Vec<String> = profiles.iter().map(|p| p.name.clone()).collect();
    names.sort();
    names
}

pub(crate) fn load_config_from_file(path: &Path) -> AppConfig {
    let content = std::fs::read_to_string(path).unwrap_or_default();
    if let Ok(mut cfg) = toml::from_str::<AppConfig>(&content) {
        migrate_codec_key(&mut cfg.profiles);
        return cfg;
    }
    if let Some(profiles) = parse_profiles_from_content(&content) {
        return AppConfig {
            profiles,
            options: AppOptions::default(),
        };
    }
    AppConfig::default()
}

fn load_defaults() -> AppConfig {
    load_config_from_file(&defaults_path())
}

fn load_user_config() -> AppConfig {
    load_config_from_file(&user_config_path())
}

pub(crate) fn merge_configs() -> AppConfig {
    let defaults = load_defaults();
    let user = load_user_config();
    let mut map: HashMap<String, VideoProfile> = HashMap::new();
    for p in defaults.profiles {
        map.insert(p.name.clone(), p);
    }
    for p in user.profiles {
        map.insert(p.name.clone(), p);
    }
    AppConfig {
        profiles: map.into_values().collect(),
        options: user.options,
    }
}

pub(crate) fn get_config() -> AppConfig {
    let mut guard = CONFIG.lock().unwrap();
    guard.get_or_insert_with(merge_configs).clone()
}

pub(crate) fn set_config(config: AppConfig) {
    let mut guard = CONFIG.lock().unwrap();
    *guard = Some(config);
}

pub fn default_profile_names() -> Vec<String> {
    sorted_names(load_defaults().profiles)
}

pub fn available_profiles() -> Vec<String> {
    sorted_names_ref(&get_config().profiles)
}

pub fn load_profile(name: &str) -> Option<VideoProfile> {
    let config = get_config();
    config.profiles.iter().find(|p| p.name == name).cloned()
}

pub fn user_profile_names() -> Vec<String> {
    sorted_names(load_user_config().profiles)
}

pub fn save_profile(name: &str, json: &str) -> anyhow::Result<()> {
    let mut profile: VideoProfile = serde_json::from_str(json)?;
    profile.name = name.to_string();
    let mut cfg = load_user_config();
    if let Some(pos) = cfg.profiles.iter().position(|p| p.name == name) {
        cfg.profiles[pos] = profile;
    } else {
        cfg.profiles.push(profile);
    }
    save_user_config(&cfg)?;
    set_config(merge_configs());
    Ok(())
}

pub fn restore_defaults() -> anyhow::Result<()> {
    let default_names: Vec<String> = load_defaults()
        .profiles
        .into_iter()
        .map(|p| p.name.clone())
        .collect();
    let mut cfg = load_user_config();
    cfg.profiles.retain(|p| !default_names.contains(&p.name));
    save_user_config(&cfg)?;
    set_config(merge_configs());
    Ok(())
}

pub fn delete_profile(name: &str) -> anyhow::Result<()> {
    let mut cfg = load_user_config();
    cfg.profiles.retain(|p| p.name != name);
    save_user_config(&cfg)?;
    set_config(merge_configs());
    Ok(())
}

#[derive(Serialize)]
struct ExportFile {
    profiles: Vec<VideoProfile>,
}

pub fn export_profiles(path: &str, names: &[String]) -> anyhow::Result<()> {
    let config = get_config();
    let selected: Vec<VideoProfile> = config
        .profiles
        .iter()
        .filter(|p| names.contains(&p.name))
        .cloned()
        .collect();
    let content = toml::to_string(&ExportFile { profiles: selected })?;
    Ok(std::fs::write(path, content)?)
}

fn parse_profiles_file(path: &Path) -> anyhow::Result<Vec<VideoProfile>> {
    let content = std::fs::read_to_string(path)?;
    parse_profiles_from_content(&content)
        .ok_or_else(|| anyhow::anyhow!("not a valid profiles file"))
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct ImportPreview {
    pub conflicts: Vec<String>,
    pub error: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct ImportSummary {
    pub imported: Vec<String>,
    pub skipped: Vec<String>,
    pub overwritten: Vec<String>,
    pub error: Option<String>,
}

fn existing_profile_names() -> Vec<String> {
    get_config()
        .profiles
        .iter()
        .map(|p| p.name.clone())
        .collect()
}

pub fn import_profiles_preview(path: &str) -> ImportPreview {
    let profiles = match parse_profiles_file(Path::new(path)) {
        Ok(p) => p,
        Err(e) => {
            return ImportPreview {
                error: Some(e.to_string()),
                ..Default::default()
            };
        }
    };
    let existing = existing_profile_names();
    ImportPreview {
        conflicts: profiles
            .iter()
            .map(|p| p.name.clone())
            .filter(|n| existing.contains(n))
            .collect(),
        error: None,
    }
}

pub fn import_profiles(path: &str, overwrite: bool) -> ImportSummary {
    let profiles = match parse_profiles_file(Path::new(path)) {
        Ok(p) => p,
        Err(e) => {
            return ImportSummary {
                error: Some(e.to_string()),
                ..Default::default()
            };
        }
    };
    let existing = existing_profile_names();
    let mut summary = ImportSummary::default();
    let mut cfg = load_user_config();
    for p in profiles {
        if existing.contains(&p.name) {
            if !overwrite {
                summary.skipped.push(p.name.clone());
                continue;
            }
            if let Some(pos) = cfg.profiles.iter().position(|c| c.name == p.name) {
                cfg.profiles[pos] = p.clone();
            } else {
                cfg.profiles.push(p.clone());
            }
            summary.overwritten.push(p.name);
        } else {
            cfg.profiles.push(p.clone());
            summary.imported.push(p.name);
        }
    }
    match save_user_config(&cfg) {
        Ok(()) => {
            set_config(merge_configs());
            summary
        }
        Err(e) => {
            summary.error = Some(e.to_string());
            summary
        }
    }
}

pub fn get_options() -> AppOptions {
    get_config().options
}

pub fn set_option(key: &str, value: &str) -> anyhow::Result<()> {
    let mut cfg = load_user_config();
    match key {
        "language" => cfg.options.language = value.to_string(),
        "theme" => cfg.options.theme = value.to_string(),
        "colorScheme" => cfg.options.color_scheme = value.to_string(),
        "hwdec" => cfg.options.hwdec = value.to_string(),
        "previewVolume" => {
            let v: f64 = value
                .parse()
                .map_err(|_| anyhow::anyhow!("invalid numeric value"))?;
            cfg.options.preview_volume = v.clamp(0.0, 100.0);
        }
        "checkForUpdates" => {
            let v: bool = value
                .parse()
                .map_err(|_| anyhow::anyhow!("invalid boolean value"))?;
            cfg.options.check_for_updates = v;
        }
        _ => return Err(anyhow::anyhow!("unknown option key")),
    }
    save_user_config(&cfg)?;
    set_config(merge_configs());
    Ok(())
}

fn save_user_config(config: &AppConfig) -> anyhow::Result<()> {
    let path = user_config_path();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let content = toml::to_string(config)?;
    Ok(std::fs::write(&path, content)?)
}
