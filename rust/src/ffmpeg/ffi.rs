use std::collections::HashMap;
use std::os::raw::c_char;

use crate::config::VideoProfile;
use crate::ffmpeg::{build_command, build_preview, cstr, encoder_capabilities, normalize_path, run_cmd, to_c_string};

#[no_mangle]
pub extern "C" fn guinea_mpeg_ffmpeg_available() -> bool {
    std::process::Command::new("ffmpeg")
        .arg("-version")
        .output()
        .is_ok()
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
    let ok = std::process::Command::new("ffmpeg")
        .args(&["-y", "-ss", &sec, "-i", &p, "-vframes", "1", "-q:v", "2", &preview])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);

    if ok { to_c_string(preview) } else { std::ptr::null_mut() }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_encoder_capabilities(encoder_name: *const c_char) -> *mut c_char {
    let name = unsafe { cstr(encoder_name) };
    if name.is_empty() {
        return to_c_string("null".to_string());
    }
    match encoder_capabilities(name) {
        Some(ref caps) => to_c_string(serde_json::to_string(caps).unwrap_or_default()),
        None => to_c_string("null".to_string()),
    }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_available_encoders() -> *mut c_char {
    let output = match run_cmd("ffmpeg", &["-hide_banner", "-encoders"]) {
        Some(o) => o,
        None => return to_c_string("null".to_string()),
    };
    let mut by_codec: HashMap<String, Vec<String>> = HashMap::new();
    for line in output.lines() {
        let trimmed = line.trim();
        if !trimmed.starts_with('V') {
            continue;
        }
        let parts: Vec<&str> = trimmed.split_whitespace().collect();
        if parts.len() < 2 {
            continue;
        }
        let enc_name = parts[1].to_string();
        let codec = if let Some(start) = trimmed.rfind("(codec ") {
            let after = &trimmed[start + 7..];
            if let Some(end) = after.find(')') {
                after[..end].trim().to_string()
            } else {
                continue;
            }
        } else {
            continue;
        };
        by_codec.entry(codec).or_default().push(enc_name);
    }
    for list in by_codec.values_mut() {
        list.sort();
    }
    to_c_string(serde_json::to_string(&by_codec).unwrap_or_default())
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
