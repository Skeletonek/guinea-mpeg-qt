use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

static CONFIG: Mutex<Option<AppConfig>> = Mutex::new(None);

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VideoProfile {
    pub name: String,
    pub codec: String,
    pub crf: Option<i32>,
    pub bitrate: Option<String>,
    pub preset: Option<String>,
    pub tune: Option<String>,
    pub pixel_format: Option<String>,
    pub resolution: Option<String>,
    pub framerate: Option<f64>,
    pub tile_rows: Option<u32>,
    pub tile_columns: Option<u32>,
    pub enable_qm: Option<bool>,
    #[serde(default = "default_audio_bitrate")]
    pub audio_bitrate: String,
    pub audio_channels: Option<u32>,
    pub audio_sample_rate: Option<u32>,
    #[serde(default)]
    pub extra_args: Vec<String>,
}

fn default_audio_bitrate() -> String {
    "128k".into()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct AppConfig {
    profiles: Vec<VideoProfile>,
}

fn user_config_path() -> PathBuf {
    let mut path = dirs_or_fallback();
    path.push("guinea-mpeg");
    path.push("config.toml");
    path
}

fn defaults_path() -> PathBuf {
    // Try beside the executable first
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            let p = dir.join("default_profiles.toml");
            if p.exists() {
                return p;
            }
        }
    }
    // Fall back to system-wide install path
    PathBuf::from("/usr/share/guinea-mpeg/default_profiles.toml")
}

fn dirs_or_fallback() -> PathBuf {
    dirs::config_dir().unwrap_or_else(|| PathBuf::from("."))
}

fn load_profiles_from_file(path: &Path) -> Vec<VideoProfile> {
    let content = match std::fs::read_to_string(path) {
        Ok(c) => c,
        Err(_) => return Vec::new(),
    };

    // Try new format: [[profiles]] -> Vec<VideoProfile>
    #[derive(Deserialize)]
    struct VecConfig {
        profiles: Vec<VideoProfile>,
    }
    if let Ok(cfg) = toml::from_str::<VecConfig>(&content) {
        return cfg.profiles;
    }

    // Fall back to old format: [profiles."name"] -> HashMap<String, VideoProfile>
    #[derive(Deserialize)]
    struct MapConfig {
        profiles: HashMap<String, VideoProfile>,
    }
    if let Ok(cfg) = toml::from_str::<MapConfig>(&content) {
        return cfg.profiles.into_values().collect();
    }

    Vec::new()
}

fn load_defaults() -> Vec<VideoProfile> {
    load_profiles_from_file(&defaults_path())
}

fn load_user_config() -> Vec<VideoProfile> {
    load_profiles_from_file(&user_config_path())
}

fn merge_configs() -> AppConfig {
    let mut map: HashMap<String, VideoProfile> = HashMap::new();
    for p in load_defaults() {
        map.insert(p.name.clone(), p);
    }
    for p in load_user_config() {
        map.insert(p.name.clone(), p);
    }
    AppConfig {
        profiles: map.into_values().collect(),
    }
}

fn load_config() -> AppConfig {
    merge_configs()
}

fn save_user_config(config: &AppConfig) -> anyhow::Result<()> {
    let path = user_config_path();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let content = toml::to_string(config)?;
    std::fs::write(&path, content)?;
    Ok(())
}

fn get_config() -> AppConfig {
    let mut guard = CONFIG.lock().unwrap();
    if guard.is_none() {
        *guard = Some(load_config());
    }
    guard.as_ref().unwrap().clone()
}

fn set_config(config: AppConfig) {
    let mut guard = CONFIG.lock().unwrap();
    *guard = Some(config);
}

pub fn available_profiles() -> Vec<String> {
    let config = get_config();
    let mut names: Vec<String> = config.profiles.iter().map(|p| p.name.clone()).collect();
    names.sort();
    names
}

pub fn load_profile(name: &str) -> Option<VideoProfile> {
    let config = get_config();
    config.profiles.iter().find(|p| p.name == name).cloned()
}

pub fn save_profile(name: &str, json: &str) -> anyhow::Result<()> {
    let mut profile: VideoProfile = serde_json::from_str(json)?;
    profile.name = name.to_string();
    let mut user_profiles = load_user_config();
    if let Some(pos) = user_profiles.iter().position(|p| p.name == name) {
        user_profiles[pos] = profile;
    } else {
        user_profiles.push(profile);
    }
    let user_config = AppConfig {
        profiles: user_profiles,
    };
    save_user_config(&user_config)?;
    set_config(merge_configs());
    Ok(())
}

pub fn delete_profile(name: &str) -> anyhow::Result<()> {
    let mut user_profiles = load_user_config();
    user_profiles.retain(|p| p.name != name);
    let user_config = AppConfig {
        profiles: user_profiles,
    };
    save_user_config(&user_config)?;
    set_config(merge_configs());
    Ok(())
}
