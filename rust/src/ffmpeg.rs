use serde::Serialize;

use crate::config::VideoProfile;

#[derive(Debug, Clone, Serialize)]
pub struct VideoInfo {
    pub duration: f64,
    pub width: u32,
    pub height: u32,
    pub fps: f64,
    pub codec: String,
    pub bitrate: u64,
}

pub fn build_command(
    input: &str,
    output: &str,
    start_time: f64,
    end_time: f64,
    profile_json: &str,
) -> Vec<String> {
    let profile: VideoProfile = match serde_json::from_str(profile_json) {
        Ok(p) => p,
        Err(_) => return vec![],
    };

    let mut args = Vec::new();

    if start_time > 0.0 {
        args.push("-ss".to_string());
        args.push(format!("{}", start_time));
    }
    args.push("-i".to_string());
    args.push(input.to_string());

    if end_time > start_time {
        args.push("-t".to_string());
        args.push(format!("{:.3}", end_time - start_time));
    }

    args.push("-c:v".to_string());
    args.push(video_codec(&profile.codec).to_string());

    if let Some(crf) = profile.crf {
        args.push("-crf".to_string());
        args.push(crf.to_string());
    }
    if let Some(bitrate) = &profile.bitrate {
        if !bitrate.is_empty() {
            args.push("-b:v".to_string());
            args.push(bitrate.clone());
        }
    }
    if let Some(preset) = &profile.preset {
        if profile.codec != "svtav1" {
            args.push("-preset".to_string());
            args.push(preset.clone());
        }
    }
    if let Some(pix_fmt) = &profile.pixel_format {
        args.push("-pix_fmt".to_string());
        args.push(pix_fmt.clone());
    }

    // Video filter chain: fps and scale
    let mut filter_parts = Vec::new();
    if let Some(fps) = profile.framerate {
        if fps > 0.0 {
            filter_parts.push(format!("fps={}", fps));
        }
    }
    if let Some(res) = &profile.resolution {
        if let Some(height) = res.strip_suffix('p') {
            if height != "native" {
                filter_parts.push(format!("scale=-2:{}", height));
            }
        }
    }
    if !filter_parts.is_empty() {
        args.push("-vf".to_string());
        args.push(filter_parts.join(","));
    }

    // AV1-specific params via -svtav1-params
    if profile.codec == "svtav1" {
        let mut svt = Vec::new();
        if let Some(p) = &profile.preset {
            svt.push(format!("preset={}", p));
        }
        if profile.enable_qm.unwrap_or(false) {
            svt.push("enable-qm=1".to_string());
        }
        if let Some(tune) = &profile.tune {
            let val = match tune.to_lowercase().as_str() {
                "psnr" => "0",
                "ssim" => "1",
                "vmaf" => "2",
                _ => "0",
            };
            svt.push(format!("tune={}", val));
        }
        if let Some(crf) = profile.crf {
            svt.push(format!("crf={}", crf));
        }
        if let Some(tr) = profile.tile_rows {
            svt.push(format!("tile-rows={}", tr));
        }
        if let Some(tc) = profile.tile_columns {
            svt.push(format!("tile-columns={}", tc));
        }
        if !svt.is_empty() {
            args.push("-svtav1-params".to_string());
            args.push(svt.join(":"));
        }
    }

    // Extra user args
    for arg in &profile.extra_args {
        args.push(arg.clone());
    }

    // Audio
    args.push("-c:a".to_string());
    args.push(audio_codec(&profile.codec).to_string());

    if !profile.audio_bitrate.is_empty() {
        args.push("-b:a".to_string());
        args.push(profile.audio_bitrate);
    }
    if let Some(ch) = profile.audio_channels {
        args.push("-ac".to_string());
        args.push(ch.to_string());
    }
    if let Some(sr) = profile.audio_sample_rate {
        args.push("-ar".to_string());
        args.push(sr.to_string());
    }

    args.push("-y".to_string());
    args.push(output.to_string());

    args
}

pub fn video_codec(codec: &str) -> &str {
    match codec {
        "h264" => "libx264",
        "vp8" => "libvpx",
        "vp9" => "libvpx-vp9",
        "svtav1" => "libsvtav1",
        _ => "libx264",
    }
}

pub fn audio_codec(codec: &str) -> &str {
    match codec {
        "h264" => "aac",
        _ => "libopus",
    }
}

#[allow(unused_variables)]
pub fn parse_ffprobe_output(json: &str) -> VideoInfo {
    VideoInfo {
        duration: 0.0,
        width: 0,
        height: 0,
        fps: 0.0,
        codec: "unknown".to_string(),
        bitrate: 0,
    }
}

#[allow(dead_code)]
pub fn container_extension(codec: &str) -> &str {
    match codec {
        "h264" => "mp4",
        _ => "webm",
    }
}
