use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

const DEFAULT_SYSTEM_PROFILES_PATH: &str = "/usr/share/guinea-mpeg/default_profiles.toml";
const MAX_VOLUME: f64 = 100.0;
const MIN_VOLUME: f64 = 0.0;
const MAX_PREVIEW_DURATION: f64 = 60.0;
const MIN_PREVIEW_DURATION: f64 = 1.0;

static CONFIG: Mutex<Option<AppConfig>> = Mutex::new(None);

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct VideoFilters {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub deinterlace: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub denoise: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub crop_top: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub crop_right: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub crop_bottom: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub crop_left: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub hflip: Option<bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub vflip: Option<bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub rotate: Option<u32>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AudioFilters {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub rate_control: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub quality: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub gain_db: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub loudnorm: Option<bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub loudnorm_i: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub loudnorm_tp: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub loudnorm_lra: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub normalize: Option<bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub normalize_target_i: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub normalize_target_tp: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VideoProfile {
    #[serde(default)]
    pub name: String,
    // Picker grouping; uncategorized profiles land in a trailing "Custom" group.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub category: Option<String>,
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
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub video_filters: Option<VideoFilters>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub audio_filters: Option<AudioFilters>,
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
    #[serde(default = "default_preview_duration")]
    pub preview_duration: f64,
    #[serde(default = "default_check_for_updates")]
    pub check_for_updates: bool,
    #[serde(default = "default_autoplay_on_load")]
    pub autoplay_on_load: bool,
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

fn default_preview_duration() -> f64 {
    5.0
}

fn default_check_for_updates() -> bool {
    true
}

fn default_autoplay_on_load() -> bool {
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
            preview_duration: default_preview_duration(),
            check_for_updates: default_check_for_updates(),
            autoplay_on_load: default_autoplay_on_load(),
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

// GUINEA_MPEG_CONFIG_DIR redirects config for tests (and power users).
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
    PathBuf::from(DEFAULT_SYSTEM_PROFILES_PATH)
}

fn dirs_or_fallback() -> PathBuf {
    dirs::config_dir().unwrap_or_else(|| PathBuf::from("."))
}

fn migrate_codec_key(profiles: &mut [VideoProfile]) {
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

pub fn load_profile(name: &str) -> Option<VideoProfile> {
    let config = get_config();
    config.profiles.iter().find(|p| p.name == name).cloned()
}

#[derive(Debug, Clone, Serialize)]
pub struct ProfileGroup {
    pub category: String,
    pub names: Vec<String>,
}

const CUSTOM_CATEGORY: &str = "Custom";

pub fn profile_groups() -> Vec<ProfileGroup> {
    // Order: first appearance in defaults, then user-only categories (user file order).
    let mut order: Vec<String> = Vec::new();
    for source in [load_defaults().profiles, load_user_config().profiles] {
        for p in source {
            if let Some(category) = &p.category {
                if !order.contains(category) {
                    order.push(category.clone());
                }
            }
        }
    }

    let config = get_config();
    let mut by_category: HashMap<String, Vec<String>> = HashMap::new();
    let mut uncategorized: Vec<String> = Vec::new();
    for p in &config.profiles {
        match &p.category {
            Some(category) => by_category
                .entry(category.clone())
                .or_default()
                .push(p.name.clone()),
            None => uncategorized.push(p.name.clone()),
        }
    }

    let mut groups: Vec<ProfileGroup> = Vec::new();
    for category in order {
        if let Some(mut names) = by_category.remove(&category) {
            names.sort();
            groups.push(ProfileGroup { category, names });
        }
    }
    // Sorted spot for categories missing from `order`, so nothing vanishes from the picker.
    let mut leftover: Vec<(String, Vec<String>)> = by_category.into_iter().collect();
    leftover.sort();
    for (category, mut names) in leftover {
        names.sort();
        groups.push(ProfileGroup { category, names });
    }
    uncategorized.sort();
    if !uncategorized.is_empty() {
        groups.push(ProfileGroup {
            category: CUSTOM_CATEGORY.to_string(),
            names: uncategorized,
        });
    }
    groups
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

fn parse_f64(value: &str) -> anyhow::Result<f64> {
    value
        .parse()
        .map_err(|_| anyhow::anyhow!("invalid numeric value"))
}

fn parse_bool(value: &str) -> anyhow::Result<bool> {
    value
        .parse()
        .map_err(|_| anyhow::anyhow!("invalid boolean value"))
}

pub fn set_option(key: &str, value: &str) -> anyhow::Result<()> {
    let mut cfg = load_user_config();
    match key {
        "language" => cfg.options.language = value.to_string(),
        "theme" => cfg.options.theme = value.to_string(),
        "colorScheme" => cfg.options.color_scheme = value.to_string(),
        "hwdec" => cfg.options.hwdec = value.to_string(),
        "previewVolume" => {
            cfg.options.preview_volume = parse_f64(value)?.clamp(MIN_VOLUME, MAX_VOLUME);
        }
        "previewDuration" => {
            cfg.options.preview_duration =
                parse_f64(value)?.clamp(MIN_PREVIEW_DURATION, MAX_PREVIEW_DURATION);
        }
        "checkForUpdates" => {
            cfg.options.check_for_updates = parse_bool(value)?;
        }
        "autoplayOnLoad" => {
            cfg.options.autoplay_on_load = parse_bool(value)?;
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
