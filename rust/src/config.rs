use serde::{Serialize, Deserialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Mutex;

static CONFIG: Mutex<Option<AppConfig>> = Mutex::new(None);

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VideoProfile {
    pub name: String,
    pub codec: String,
    pub crf: Option<i32>,
    pub preset: Option<String>,
    pub bitrate: Option<String>,
    pub pixel_format: Option<String>,
    pub extra_args: Vec<String>,
    pub av1_params: Option<Av1Params>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Av1Params {
    pub preset: u8,
    pub crf: Option<u8>,
    pub tune: String,
    pub tile_rows: Option<u32>,
    pub tile_columns: Option<u32>,
    pub enable_qm: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct AppConfig {
    profiles: HashMap<String, VideoProfile>,
}

fn config_path() -> PathBuf {
    let mut path = dirs_or_fallback();
    path.push("guinea-mpeg");
    path.push("config.toml");
    path
}

fn dirs_or_fallback() -> PathBuf {
    if let Some(d) = dirs::config_dir() {
        d
    } else {
        PathBuf::from(".")
    }
}

fn load_config() -> AppConfig {
    let path = config_path();
    if let Ok(content) = std::fs::read_to_string(&path) {
        toml::from_str(&content).unwrap_or_else(|_| AppConfig {
            profiles: default_profiles(),
        })
    } else {
        AppConfig {
            profiles: default_profiles(),
        }
    }
}

fn save_config(config: &AppConfig) -> anyhow::Result<()> {
    let path = config_path();
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
    config.profiles.keys().cloned().collect()
}

pub fn load_profile(name: &str) -> Option<VideoProfile> {
    let config = get_config();
    config.profiles.get(name).cloned()
}

pub fn save_profile(name: &str, json: &str) -> anyhow::Result<()> {
    let profile: VideoProfile = serde_json::from_str(json)?;
    let mut config = get_config();
    config.profiles.insert(name.to_string(), profile);
    save_config(&config)?;
    set_config(config);
    Ok(())
}

pub fn delete_profile(name: &str) -> anyhow::Result<()> {
    let mut config = get_config();
    config.profiles.remove(name);
    save_config(&config)?;
    set_config(config);
    Ok(())
}

fn default_profiles() -> HashMap<String, VideoProfile> {
    let mut profiles = HashMap::new();
    profiles.insert(
        "h264_high".into(),
        VideoProfile {
            name: "H.264 High Quality".into(),
            codec: "libx264".into(),
            crf: Some(18),
            preset: Some("slow".into()),
            bitrate: None,
            pixel_format: None,
            extra_args: vec![],
            av1_params: None,
        },
    );
    profiles.insert(
        "h265_balanced".into(),
        VideoProfile {
            name: "H.265 Balanced".into(),
            codec: "libx265".into(),
            crf: Some(23),
            preset: Some("medium".into()),
            bitrate: None,
            pixel_format: None,
            extra_args: vec![],
            av1_params: None,
        },
    );
    profiles.insert(
        "vp9_web".into(),
        VideoProfile {
            name: "VP9 Web".into(),
            codec: "libvpx-vp9".into(),
            crf: Some(30),
            preset: None,
            bitrate: None,
            pixel_format: None,
            extra_args: vec!["-row-mt".into(), "1".into()],
            av1_params: None,
        },
    );
    profiles.insert(
        "av1_high".into(),
        VideoProfile {
            name: "AV1 (SVT-AV1) High Quality".into(),
            codec: "libsvtav1".into(),
            crf: None,
            preset: None,
            bitrate: None,
            pixel_format: None,
            extra_args: vec![],
            av1_params: Some(Av1Params {
                preset: 8,
                crf: Some(28),
                tune: "Vmaf".into(),
                tile_rows: Some(2),
                tile_columns: Some(3),
                enable_qm: true,
            }),
        },
    );
    profiles.insert(
        "av1_fast".into(),
        VideoProfile {
            name: "AV1 (SVT-AV1) Fast".into(),
            codec: "libsvtav1".into(),
            crf: None,
            preset: None,
            bitrate: Some("5M".into()),
            pixel_format: None,
            extra_args: vec![],
            av1_params: Some(Av1Params {
                preset: 4,
                crf: Some(35),
                tune: "Psnr".into(),
                tile_rows: Some(1),
                tile_columns: Some(2),
                enable_qm: false,
            }),
        },
    );
    profiles
}
