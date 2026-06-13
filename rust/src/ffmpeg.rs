use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::process::Command;

use crate::config::VideoProfile;

#[derive(Debug, Clone, Copy, PartialEq)]
enum EncoderFamily {
    Software,
    Nvenc,
    Qsv,
    Vaapi,
    Amf,
    Vulkan,
    VideoToolbox,
}

#[derive(Debug, Clone, serde::Serialize)]
struct EncoderCapabilities {
    presets: Option<Vec<String>>,
    tunes: Option<Vec<String>>,
    pix_fmts: Option<Vec<String>>,
    uses_preset: bool,
    uses_tune: bool,
    crf_flag: String,
    vbr_flag: String,
    cbr_flag: String,
    rc_flag: Option<String>,
}

fn encoder_family(encoder: &str) -> EncoderFamily {
    if encoder.starts_with("libx26") || encoder.starts_with("libvpx") || encoder == "libsvtav1"
        || encoder == "libaom-av1" || encoder == "librav1e"
    {
        EncoderFamily::Software
    } else if encoder.ends_with("_nvenc") || encoder.ends_with("_nvenc_hybrid") {
        EncoderFamily::Nvenc
    } else if encoder.ends_with("_qsv") {
        EncoderFamily::Qsv
    } else if encoder.ends_with("_vaapi") {
        EncoderFamily::Vaapi
    } else if encoder.ends_with("_amf") {
        EncoderFamily::Amf
    } else if encoder.ends_with("_vulkan") {
        EncoderFamily::Vulkan
    } else if encoder.ends_with("_videotoolbox") {
        EncoderFamily::VideoToolbox
    } else {
        EncoderFamily::Software
    }
}

fn encoder_capabilities(encoder: &str) -> Option<EncoderCapabilities> {
    Some(match encoder_family(encoder) {
        EncoderFamily::Nvenc => EncoderCapabilities {
            presets: Some(vec!["p1","p2","p3","p4","p5","p6","p7"].into_iter().map(String::from).collect()),
            tunes: Some(vec!["hq","ll","ull","lossless"].into_iter().map(String::from).collect()),
            pix_fmts: Some(vec!["yuv420p","nv12","p010le","yuv444p"].into_iter().map(String::from).collect()),
            uses_preset: true,
            uses_tune: true,
            crf_flag: "-cq".into(),
            vbr_flag: "-b:v".into(),
            cbr_flag: "-b:v".into(),
            rc_flag: Some("-rc".into()),
        },
        EncoderFamily::Qsv => EncoderCapabilities {
            presets: Some(vec!["veryfast","faster","fast","medium","slow","slower"].into_iter().map(String::from).collect()),
            tunes: Some(vec!["film","animation","grain"].into_iter().map(String::from).collect()),
            pix_fmts: Some(vec!["nv12","yuv420p","p010le"].into_iter().map(String::from).collect()),
            uses_preset: true,
            uses_tune: true,
            crf_flag: "-global_quality".into(),
            vbr_flag: "-b:v".into(),
            cbr_flag: "-b:v".into(),
            rc_flag: Some("-rc".into()),
        },
        EncoderFamily::Vaapi => EncoderCapabilities {
            presets: None,
            tunes: None,
            pix_fmts: Some(vec!["nv12","vaapi_vld","p010le"].into_iter().map(String::from).collect()),
            uses_preset: false,
            uses_tune: false,
            crf_flag: "-qp".into(),
            vbr_flag: "-b:v".into(),
            cbr_flag: "-b:v".into(),
            rc_flag: Some("-rc_mode".into()),
        },
        EncoderFamily::Amf => EncoderCapabilities {
            presets: Some(vec!["speed","balanced","quality"].into_iter().map(String::from).collect()),
            tunes: Some(vec!["film","animation","grain"].into_iter().map(String::from).collect()),
            pix_fmts: Some(vec!["nv12","yuv420p"].into_iter().map(String::from).collect()),
            uses_preset: true,
            uses_tune: true,
            crf_flag: "-quality".into(),
            vbr_flag: "-b:v".into(),
            cbr_flag: "-b:v".into(),
            rc_flag: Some("-rc".into()),
        },
        EncoderFamily::Vulkan => EncoderCapabilities {
            presets: None,
            tunes: None,
            pix_fmts: Some(vec!["yuv420p","nv12","gbrp10le"].into_iter().map(String::from).collect()),
            uses_preset: false,
            uses_tune: false,
            crf_flag: "-crf".into(),
            vbr_flag: "-b:v".into(),
            cbr_flag: "-b:v".into(),
            rc_flag: None,
        },
        EncoderFamily::VideoToolbox => EncoderCapabilities {
            presets: None,
            tunes: None,
            pix_fmts: Some(vec!["nv12","yuv420p"].into_iter().map(String::from).collect()),
            uses_preset: false,
            uses_tune: false,
            crf_flag: "-quality".into(),
            vbr_flag: "-b:v".into(),
            cbr_flag: "-b:v".into(),
            rc_flag: Some("-rc".into()),
        },
        EncoderFamily::Software => return None,
    })
}

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

fn software_video_codec(codec: &str) -> &str {
    match codec {
        "h264" => "libx264",
        "hevc" => "libx265",
        "vp8" => "libvpx",
        "vp9" => "libvpx-vp9",
        "svtav1" => "libsvtav1",
        _ => "libx264",
    }
}

fn video_codec(profile: &VideoProfile) -> String {
    profile.encoder.clone().unwrap_or_else(|| software_video_codec(&profile.codec).to_string())
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
            "h264" | "hevc" => "aac",
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
    args.push(normalize_path(input));

    if end_time > start_time {
        args.push("-t".to_string());
        args.push(format!("{:.3}", end_time - start_time));
    }

    let video_enabled = profile.video_enabled.unwrap_or(true);
    let audio_enabled = profile.audio_enabled.unwrap_or(true);
    let rate_control = profile.rate_control.as_deref();

    let vs_idxs = &profile.video_stream_indices;
    let as_idxs = &profile.audio_stream_indices;
    if !vs_idxs.is_empty() || !as_idxs.is_empty() {
        if video_enabled {
            if vs_idxs.is_empty() {
                args.push("-map".to_string());
                args.push("0:v:0".to_string());
            } else {
                for idx in vs_idxs {
                    args.push("-map".to_string());
                    args.push(format!("0:v:{}", idx));
                }
            }
        }
        if audio_enabled {
            if as_idxs.is_empty() {
                args.push("-map".to_string());
                args.push("0:a:0".to_string());
            } else {
                for idx in as_idxs {
                    args.push("-map".to_string());
                    args.push(format!("0:a:{}", idx));
                }
            }
        }
    }

    if video_enabled {
        let enc = video_codec(profile);
        args.push("-c:v".to_string());
        args.push(enc.clone());

        let family = if profile.encoder.is_some() {
            encoder_family(&enc)
        } else {
            EncoderFamily::Software
        };

        let caps = encoder_capabilities(&enc);

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
                        if family == EncoderFamily::Vaapi {
                            args.push("-rc_mode".to_string());
                            args.push("CBR".to_string());
                        } else if let Some(ref caps) = caps {
                            if let Some(ref rc_flag) = caps.rc_flag {
                                if rc_flag == "-rc" {
                                    args.push("-rc".to_string());
                                    args.push("cbr".to_string());
                                } else if rc_flag == "-rc_mode" {
                                    args.push("-rc_mode".to_string());
                                    args.push("CBR".to_string());
                                }
                            }
                        }
                    }
                }
            }
            Some("vbr") | Some("bitrate") => {
                if let Some(bitrate) = &profile.bitrate {
                    if !bitrate.is_empty() {
                        args.push("-b:v".to_string());
                        args.push(bitrate.clone());
                        if family == EncoderFamily::Vaapi {
                            args.push("-rc_mode".to_string());
                            args.push("VBR".to_string());
                        } else if let Some(ref caps) = caps {
                            if let Some(ref rc_flag) = caps.rc_flag {
                                if rc_flag == "-rc" {
                                    args.push("-rc".to_string());
                                    args.push("vbr".to_string());
                                } else if rc_flag == "-rc_mode" {
                                    args.push("-rc_mode".to_string());
                                    args.push("VBR".to_string());
                                }
                            }
                        }
                    }
                }
            }
            _ => {
                if let Some(crf) = profile.crf {
                    let crf_flag = caps.as_ref()
                        .map(|c| c.crf_flag.as_str())
                        .unwrap_or("-crf");
                    args.push(crf_flag.to_string());
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

        if profile.codec == "hevc" || profile.codec == "h264" {
            if let Some(preset) = &profile.preset {
                args.push("-preset".to_string());
                args.push(preset.clone());
            }
        } else if profile.codec == "vp8" || profile.codec == "vp9" {
            if let Some(cpu) = profile.cpu_used {
                args.push("-cpu-used".to_string());
                args.push(cpu.to_string());
            }
            if let Some(preset) = &profile.preset {
                args.push("-deadline".to_string());
                args.push(preset.clone());
            }
        } else if let Some(preset) = &profile.preset {
            if profile.codec != "svtav1" {
                args.push("-preset".to_string());
                args.push(preset.clone());
            }
        }
        if let Some(pix_fmt) = &profile.pixel_format {
            args.push("-pix_fmt".to_string());
            args.push(pix_fmt.clone());
        }

        if let Some(tune) = &profile.tune {
            if profile.codec == "h264" || profile.codec == "hevc" || profile.codec == "svtav1" {
                args.push("-tune".to_string());
                args.push(tune.clone());
            } else if profile.codec == "vp8" || profile.codec == "vp9" {
                if tune == "psnr" || tune == "ssim" {
                    args.push("-tune".to_string());
                    args.push(tune.clone());
                }
            }
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
    args.push(normalize_path(output));

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
        // V....D libx264  ... (codec h264)
        let parts: Vec<&str> = trimmed.split_whitespace().collect();
        if parts.len() < 2 {
            continue;
        }
        let enc_name = parts[1].to_string();
        // Extract (codec xxx) suffix
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
    // Sort each list
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
