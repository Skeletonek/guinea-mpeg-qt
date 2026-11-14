use std::collections::HashMap;
use std::os::raw::c_char;
use std::sync::OnceLock;

use crate::config::VideoProfile;
use crate::ffmpeg::{
    auto_pixel_format, build_command, build_preview, compute_normalize_gain, cstr,
    encoder_capabilities, normalize_path, quiet_command, run_cmd, to_c_string, video_codec,
};

// Cached so the availability and version queries share one spawn.
struct FfmpegProbe {
    spawned: bool,
    version: Option<String>,
}

fn ffmpeg_probe() -> &'static FfmpegProbe {
    static PROBE: OnceLock<FfmpegProbe> = OnceLock::new();
    PROBE.get_or_init(|| match quiet_command("ffmpeg").arg("-version").output() {
        Ok(out) => FfmpegProbe {
            spawned: true,
            version: if out.status.success() {
                String::from_utf8(out.stdout).ok()
            } else {
                None
            },
        },
        Err(_) => FfmpegProbe {
            spawned: false,
            version: None,
        },
    })
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_ffmpeg_available() -> bool {
    ffmpeg_probe().spawned
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_ffmpeg_version() -> *mut c_char {
    match &ffmpeg_probe().version {
        Some(out) => {
            let lines: Vec<String> = out.lines().take(2).map(|l| l.to_string()).collect();
            to_c_string(lines.join("\n"))
        }
        None => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_video_info(path: *const c_char) -> *mut c_char {
    let p = normalize_path(unsafe { cstr(path) });
    match run_cmd(
        "ffprobe",
        &[
            "-v",
            "quiet",
            "-print_format",
            "json",
            "-show_format",
            "-show_streams",
            &p,
        ],
    ) {
        Some(json) => to_c_string(drop_attached_pictures(&json)),
        None => to_c_string(r#"{"duration":0.0}"#.to_string()),
    }
}

/// Embedded cover art is muxed as an attached-picture *video* stream. ffprobe
/// reports a fake frame rate for it (e.g. the time base 90000/1), which used to
/// poison fps-derived UI like precise time formatting. Cover art is not playable
/// video, so it is dropped from the stream lists.
pub(crate) fn drop_attached_pictures(json: &str) -> String {
    let mut root: serde_json::Value = match serde_json::from_str(json) {
        Ok(root) => root,
        Err(_) => return json.to_string(),
    };
    if let Some(streams) = root.get_mut("streams").and_then(|s| s.as_array_mut()) {
        streams.retain(|s| {
            s.get("disposition")
                .and_then(|d| d.get("attached_pic"))
                .and_then(|v| v.as_i64())
                != Some(1)
        });
    }
    serde_json::to_string(&root).unwrap_or_else(|_| json.to_string())
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_generate_preview(path: *const c_char, time_ms: i64) -> *mut c_char {
    let p = normalize_path(unsafe { cstr(path) });
    let tmp = std::env::temp_dir().join("guinea_mpeg_preview.png");
    let preview = tmp.to_string_lossy().to_string();

    let sec = format!("{}", time_ms as f64 / 1000.0);
    let ok = quiet_command("ffmpeg")
        .args([
            "-y", "-ss", &sec, "-i", &p, "-vframes", "1", "-q:v", "2", &preview,
        ])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);

    if ok {
        to_c_string(preview)
    } else {
        std::ptr::null_mut()
    }
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

pub(crate) fn parse_encoders(output: &str) -> HashMap<String, Vec<String>> {
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
        if enc_name.ends_with("_v4l2m2m")
            || enc_name.ends_with("_videotoolbox")
            || enc_name.ends_with("_vulkan")
        {
            continue;
        }
        let codec = if let Some(start) = trimmed.rfind("(codec") {
            let after = &trimmed[start + 6..];
            let Some(end) = after.find(')') else {
                continue;
            };
            let codec = after[..end].trim().to_string();
            if codec.is_empty() {
                continue;
            }
            codec
        } else if enc_name == "=" {
            // legend row ("V..... = Video"), not an encoder
            continue;
        } else {
            // untagged when the encoder name is the codec name (ffv1, mjpeg, gif, ...)
            enc_name.clone()
        };
        by_codec.entry(codec).or_default().push(enc_name);
    }
    for list in by_codec.values_mut() {
        list.sort();
    }
    by_codec
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_available_encoders() -> *mut c_char {
    let output = match run_cmd("ffmpeg", &["-hide_banner", "-encoders"]) {
        Some(o) => o,
        None => return to_c_string("null".to_string()),
    };
    to_c_string(serde_json::to_string(&parse_encoders(&output)).unwrap_or_default())
}

/// True for HDR transfer characteristics (PQ, HLG) — the only ones the tonemap
/// filter can meaningfully convert.
pub(crate) fn is_hdr_transfer(transfer: &str) -> bool {
    matches!(transfer, "smpte2084" | "arib-std-b67")
}

/// Pixel format and transfer characteristic of the first video stream, used to
/// match the output depth and to detect HDR sources.
fn probe_video_color(input: &str) -> Option<(String, String)> {
    let p = normalize_path(input);
    let output = run_cmd(
        "ffprobe",
        &[
            "-v",
            "quiet",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=pix_fmt,color_transfer",
            "-of",
            "json",
            &p,
        ],
    )?;
    let root: serde_json::Value = serde_json::from_str(&output).ok()?;
    let stream = root.get("streams")?.get(0)?;
    let pix_fmt = stream.get("pix_fmt")?.as_str()?.to_string();
    let transfer = stream
        .get("color_transfer")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();
    (!pix_fmt.is_empty()).then_some((pix_fmt, transfer))
}

/// Source-dependent tweaks applied before building the command: auto-selects a
/// 10-bit output format for a high-bit-depth source (skipped when the user
/// picked a format or when tone mapping, which makes the output SDR), and drops
/// the tone map when the source is already SDR — nothing to convert there.
/// Skipped when the source can't be probed (e.g. the "[input]" preview
/// placeholder).
fn apply_auto_settings(profile: &mut VideoProfile, input: &str) {
    let wants_tonemap = profile
        .video_filters
        .as_ref()
        .is_some_and(|f| f.tonemap.is_some());
    let needs_probe = profile.pixel_format.is_none() || wants_tonemap;
    let source = if needs_probe {
        probe_video_color(input)
    } else {
        None
    };
    let Some((pix_fmt, transfer)) = source else {
        return;
    };
    if wants_tonemap && !is_hdr_transfer(&transfer) {
        if let Some(filters) = profile.video_filters.as_mut() {
            filters.tonemap = None;
        }
    }
    let tonemap_active = profile
        .video_filters
        .as_ref()
        .is_some_and(|f| f.tonemap.is_some());
    if profile.pixel_format.is_none() && !tonemap_active {
        if let Some(fmt) = auto_pixel_format(&video_codec(profile), &pix_fmt) {
            profile.pixel_format = Some(fmt);
        }
    }
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

    let mut profile: VideoProfile = match serde_json::from_str(json) {
        Ok(p) => p,
        Err(_) => return std::ptr::null_mut(),
    };

    apply_auto_settings(&mut profile, inp);
    let args = build_command(inp, out, start_time, end_time, &profile);
    to_c_string(serde_json::to_string(&args).unwrap_or_default())
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_compute_normalize_gain(
    input: *const c_char,
    start_time: f64,
    end_time: f64,
    profile_json: *const c_char,
) -> *mut c_char {
    let inp = unsafe { cstr(input) };
    let json = unsafe { cstr(profile_json) };
    if inp.is_empty() || json.is_empty() {
        return std::ptr::null_mut();
    }
    let profile: VideoProfile = match serde_json::from_str(json) {
        Ok(p) => p,
        Err(_) => return std::ptr::null_mut(),
    };

    let result = match compute_normalize_gain(inp, start_time, end_time, &profile) {
        Ok(gain) => serde_json::json!({"gain": gain}),
        Err(e) => serde_json::json!({"error": e.to_string()}),
    };
    to_c_string(result.to_string())
}
