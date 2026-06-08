use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::process::Command;

use crate::config::VideoProfile;

fn normalize_path(path: &str) -> String {
    #[cfg(target_os = "windows")]
    {
        let bytes = path.as_bytes();
        if bytes.len() >= 3 && bytes[0] == b'/' && bytes[2] == b':' {
            return path[1..].to_string();
        }
    }
    path.to_string()
}

fn run_cmd(prog: &str, args: &[&str]) -> Option<String> {
    let output = Command::new(prog).args(args).output().ok()?;
    if output.status.success() {
        String::from_utf8(output.stdout).ok()
    } else {
        None
    }
}

fn video_codec(codec: &str) -> &str {
    match codec {
        "h264" => "libx264",
        "vp8" => "libvpx",
        "vp9" => "libvpx-vp9",
        "svtav1" => "libsvtav1",
        _ => "libx264",
    }
}

fn audio_codec_for_profile(profile: &VideoProfile) -> &str {
    if let Some(ref ac) = profile.audio_codec {
        match ac.to_lowercase().as_str() {
            "aac" => "aac",
            "opus" => "libopus",
            "mp3" => "libmp3lame",
            "flac" => "flac",
            "vorbis" => "libvorbis",
            _ => "aac",
        }
    } else {
        match profile.codec.as_str() {
            "h264" => "aac",
            _ => "libopus",
        }
    }
}

fn build_command(
    input: &str,
    output: &str,
    start_time: f64,
    end_time: f64,
    profile: &VideoProfile,
) -> Vec<String> {
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

    let video_enabled = profile.video_enabled.unwrap_or(true);
    let rate_control = profile.rate_control.as_deref();

    if video_enabled {
        args.push("-c:v".to_string());
        args.push(video_codec(&profile.codec).to_string());

        match rate_control {
            Some("cbr") => {
                if let Some(bitrate) = &profile.bitrate {
                    if !bitrate.is_empty() {
                        args.push("-b:v".to_string());
                        args.push(bitrate.clone());
                        args.push("-minrate".to_string());
                        args.push(bitrate.clone());
                        args.push("-maxrate".to_string());
                        args.push(bitrate.clone());
                        args.push("-bufsize".to_string());
                        args.push(bitrate.clone());
                    }
                }
            }
            Some("vbr") | Some("bitrate") => {
                if let Some(bitrate) = &profile.bitrate {
                    if !bitrate.is_empty() {
                        args.push("-b:v".to_string());
                        args.push(bitrate.clone());
                    }
                }
            }
            _ => {
                if let Some(crf) = profile.crf {
                    args.push("-crf".to_string());
                    args.push(crf.to_string());
                }
                if rate_control.is_none() {
                    if let Some(bitrate) = &profile.bitrate {
                        if !bitrate.is_empty() {
                            args.push("-b:v".to_string());
                            args.push(bitrate.clone());
                        }
                    }
                }
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

        if profile.codec == "svtav1" {
            let mut svt = Vec::new();
            if let Some(p) = &profile.preset {
                svt.push(format!("preset={}", p));
            }
            if profile.enable_qm.unwrap_or(false) {
                svt.push("enable-qm=1".to_string());
            }
            if let Some(tune) = &profile.tune {
                svt.push(format!("tune={}", match tune.to_lowercase().as_str() {
                    "psnr" => "0",
                    "ssim" => "1",
                    "vmaf" => "2",
                    _ => "0",
                }));
            }
            match rate_control {
                Some("cbr" | "vbr" | "bitrate") => {
                    if let Some(bitrate) = &profile.bitrate {
                        if !bitrate.is_empty() {
                            svt.push(format!("br={}", bitrate));
                        }
                    }
                }
                _ => {
                    if let Some(crf) = profile.crf {
                        svt.push(format!("crf={}", crf));
                    }
                }
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

        for arg in &profile.extra_args {
            args.push(arg.clone());
        }
    }

    let audio_enabled = profile.audio_enabled.unwrap_or(true);

    if !audio_enabled {
        args.push("-an".to_string());
    } else {
        args.push("-c:a".to_string());
        args.push(audio_codec_for_profile(profile).to_string());

        if !profile.audio_bitrate.is_empty() {
            args.push("-b:a".to_string());
            args.push(profile.audio_bitrate.clone());
        }
        if let Some(ch) = profile.audio_channels {
            args.push("-ac".to_string());
            args.push(ch.to_string());
        }
        if let Some(sr) = profile.audio_sample_rate {
            args.push("-ar".to_string());
            args.push(sr.to_string());
        }
    }

    args.push("-y".to_string());
    args.push(output.to_string());

    args
}

fn to_c_string(s: String) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}

unsafe fn cstr(ptr: *const c_char) -> &'static str {
    if ptr.is_null() { "" } else { CStr::from_ptr(ptr).to_str().unwrap_or("") }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_ffmpeg_available() -> bool {
    Command::new("ffmpeg").arg("-version").output().is_ok()
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_ffmpeg_version() -> *mut c_char {
    match run_cmd("ffmpeg", &["-version"]) {
        Some(out) => {
            let line = out.lines().next().unwrap_or("").to_string();
            to_c_string(line)
        }
        None => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_video_info(path: *const c_char) -> *mut c_char {
    let p = normalize_path(unsafe { cstr(path) });
    match run_cmd("ffprobe", &[
        "-v", "quiet", "-print_format", "json",
        "-show_format", "-show_streams", &p,
    ]) {
        Some(json) => to_c_string(json),
        None => to_c_string(r#"{"duration":0.0}"#.to_string()),
    }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_generate_preview(path: *const c_char, time_ms: i64) -> *mut c_char {
    let p = normalize_path(unsafe { cstr(path) });
    let tmp = std::env::temp_dir().join("guinea_mpeg_preview.png");
    let preview = tmp.to_string_lossy().to_string();

    let sec = format!("{}", time_ms as f64 / 1000.0);
    let ok = Command::new("ffmpeg")
        .args(&["-y", "-ss", &sec, "-i", &p, "-vframes", "1", "-q:v", "2", &preview])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);

    if ok { to_c_string(preview) } else { std::ptr::null_mut() }
}

fn build_preview(profile: &VideoProfile) -> Vec<String> {
    build_command("[input]", "[output]", 0.0, 0.0, profile)
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_preview_command(profile_json: *const c_char) -> *mut c_char {
    let json = unsafe { cstr(profile_json) };
    if json.is_empty() {
        return std::ptr::null_mut();
    }
    let profile: VideoProfile = match serde_json::from_str(json) {
        Ok(p) => p,
        Err(_) => return std::ptr::null_mut(),
    };
    let args = build_preview(&profile);
    to_c_string(serde_json::to_string(&args).unwrap_or_default())
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_build_ffmpeg_command(
    input: *const c_char,
    output: *const c_char,
    start_time: f64,
    end_time: f64,
    profile_json: *const c_char,
) -> *mut c_char {
    let inp = unsafe { cstr(input) };
    let out = unsafe { cstr(output) };
    let json = unsafe { cstr(profile_json) };

    if inp.is_empty() || out.is_empty() || json.is_empty() {
        return std::ptr::null_mut();
    }

    let profile: VideoProfile = match serde_json::from_str(json) {
        Ok(p) => p,
        Err(_) => return std::ptr::null_mut(),
    };

    let args = build_command(inp, out, start_time, end_time, &profile);
    to_c_string(serde_json::to_string(&args).unwrap_or_default())
}
