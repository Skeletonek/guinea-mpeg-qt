use crate::config::{VideoFilters, VideoProfile};
use crate::ffmpeg::{
    audio_codec_for_profile, detect_vaapi_device, encoder_capabilities, encoder_family,
    normalize_path, quiet_command, video_codec, EncoderFamily,
};
use anyhow::Context;

const DEFAULT_QUALITY: u32 = 75;

fn push_rc_flag(
    args: &mut Vec<String>,
    family: EncoderFamily,
    caps: &Option<super::EncoderCapabilities>,
    mode: &str,
) {
    if family == EncoderFamily::Vaapi {
        args.push("-rc_mode".to_string());
        args.push(mode.to_uppercase());
    } else if let Some(ref caps) = caps {
        if let Some(ref rc_flag) = caps.rc_flag {
            let mut rc_mode = if rc_flag == "-rc" {
                mode.to_lowercase()
            } else {
                mode.to_uppercase()
            };
            // AMF has no plain "vbr": peak-constrained VBR is the equivalent
            if family == EncoderFamily::Amf && rc_mode == "vbr" {
                rc_mode = "vbr_peak".to_string();
            }
            args.push(rc_flag.clone());
            args.push(rc_mode);
        }
    }
}

/// AMF has no CRF mode: map the profile's CRF (x264 0-51 scale) to constant-QP.
fn push_amf_cqp(args: &mut Vec<String>, crf: i32, enc: &str) {
    let qp = crf.clamp(0, 51).to_string();
    args.push("-rc".to_string());
    args.push("cqp".to_string());
    args.push("-qp_i".to_string());
    args.push(qp.clone());
    args.push("-qp_p".to_string());
    args.push(qp.clone());
    if enc != "hevc_amf" {
        args.push("-qp_b".to_string());
        args.push(qp);
    }
}

fn add_audio_stream_mapping(args: &mut Vec<String>, profile: &VideoProfile) {
    if profile.video_stream_indices.is_empty() && profile.audio_stream_indices.is_empty() {
        return;
    }
    if profile.audio_stream_indices.is_empty() {
        args.push("-map".to_string());
        args.push("0:a:0".to_string());
    } else {
        for idx in &profile.audio_stream_indices {
            args.push("-map".to_string());
            args.push(format!("0:a:{}", idx));
        }
    }
}

fn add_stream_mapping(args: &mut Vec<String>, profile: &VideoProfile) {
    let video_enabled = profile.video_enabled.unwrap_or(true);
    let audio_enabled = profile.audio_enabled.unwrap_or(true);
    let vs_idxs = &profile.video_stream_indices;
    if vs_idxs.is_empty() && profile.audio_stream_indices.is_empty() {
        return;
    }
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
        add_audio_stream_mapping(args, profile);
    }
}

fn push_bitrate(args: &mut Vec<String>, bitrate: &str) {
    args.push("-b:v".to_string());
    args.push(bitrate.to_string());
}

fn add_rate_control(args: &mut Vec<String>, profile: &VideoProfile, enc: &str) {
    let family = if profile.encoder.is_some() {
        encoder_family(enc)
    } else {
        EncoderFamily::Software
    };
    let caps = encoder_capabilities(enc);
    let bitrate = profile.bitrate.as_deref().filter(|b| !b.is_empty());

    match profile.rate_control.as_deref() {
        Some("cbr") => {
            if let Some(bitrate) = bitrate {
                push_bitrate(args, bitrate);
                args.push("-minrate".to_string());
                args.push(bitrate.to_string());
                args.push("-maxrate".to_string());
                args.push(bitrate.to_string());
                args.push("-bufsize".to_string());
                args.push(bitrate.to_string());
                push_rc_flag(args, family, &caps, "cbr");
            }
        }
        Some("vbr") | Some("bitrate") => {
            if let Some(bitrate) = bitrate {
                push_bitrate(args, bitrate);
                push_rc_flag(args, family, &caps, "vbr");
            }
        }
        _ => {
            if let Some(crf) = profile.crf {
                if family == EncoderFamily::Amf {
                    push_amf_cqp(args, crf, enc);
                } else {
                    let crf_flag = caps.as_ref().map(|c| c.crf_flag.as_str()).unwrap_or("-crf");
                    // empty crf_flag = encoder without a quality knob (e.g. ffv1)
                    if !crf_flag.is_empty() {
                        let mut value = crf;
                        if let Some(ref c) = caps {
                            if let (Some(lo), Some(hi)) = (c.crf_min, c.crf_max) {
                                value = crf.clamp(lo, hi);
                            }
                        }
                        args.push(crf_flag.to_string());
                        args.push(value.to_string());
                    }
                }
            }
            if profile.rate_control.is_none() {
                if let Some(bitrate) = bitrate {
                    push_bitrate(args, bitrate);
                }
            }
        }
    }
}

fn add_codec_specific(args: &mut Vec<String>, profile: &VideoProfile, enc: &str) {
    let caps = encoder_capabilities(enc);
    let family = encoder_family(enc);

    match profile.codec.as_str() {
        "vp8" | "vp9" => {
            if let Some(cpu) = profile.cpu_used {
                args.push("-cpu-used".to_string());
                args.push(cpu.to_string());
            }
            if let Some(preset) = &profile.preset {
                args.push("-deadline".to_string());
                args.push(preset.clone());
            }
        }
        _ => {
            if let Some(preset) = &profile.preset {
                let can_preset = caps.as_ref().map(|c| c.uses_preset).unwrap_or(true);
                if can_preset {
                    // AMF takes the preset via -quality ("-preset" is only a recent alias)
                    if family == EncoderFamily::Amf {
                        args.push("-quality".to_string());
                    } else {
                        args.push("-preset".to_string());
                    }
                    args.push(preset.clone());
                }
            }
        }
    }
    if let Some(level) = &profile.compression_level {
        let can_compress = caps
            .as_ref()
            .map(|c| c.uses_compression_level)
            .unwrap_or(true);
        if !level.is_empty() && can_compress {
            args.push("-compression_level".to_string());
            args.push(level.clone());
        }
    }
    if let Some(pix_fmt) = &profile.pixel_format {
        args.push("-pix_fmt".to_string());
        args.push(pix_fmt.clone());
    }
    if let Some(tune) = &profile.tune {
        let can_tune = match profile.codec.as_str() {
            "vp8" | "vp9" => tune == "psnr" || tune == "ssim",
            _ => caps.as_ref().map(|c| c.uses_tune).unwrap_or(true),
        };
        if can_tune {
            args.push("-tune".to_string());
            args.push(tune.clone());
        }
    }
}

fn is_animated_codec(codec: &str) -> bool {
    codec == "gif" || codec == "webp"
}

fn resolution_scale(res: &str) -> Option<String> {
    if let Some(height) = res.strip_suffix('p') {
        if height != "native" {
            return Some(format!("scale=-2:{}", height));
        }
    }
    None
}

fn build_crop_filter(filters: &VideoFilters) -> Option<String> {
    let top = filters.crop_top.unwrap_or(0);
    let right = filters.crop_right.unwrap_or(0);
    let bottom = filters.crop_bottom.unwrap_or(0);
    let left = filters.crop_left.unwrap_or(0);
    if top == 0 && right == 0 && bottom == 0 && left == 0 {
        return None;
    }
    // Input-relative expressions keep the filter valid anywhere in the chain.
    Some(format!(
        "crop=iw-{}-{}:ih-{}-{}:{}:{}",
        left, right, top, bottom, left, top
    ))
}

fn base_filter_parts(profile: &VideoProfile) -> Vec<String> {
    let mut parts = Vec::new();
    let filters = profile.video_filters.as_ref();

    // Tone map first: subsequent filters work on the SDR result
    if let Some(algo) = filters.and_then(|f| f.tonemap.as_deref()) {
        parts.push(format!("tonemap=tonemap={}:desat=0", algo));
    }
    if let Some(mode) = filters.and_then(|f| f.deinterlace.as_deref()) {
        match mode {
            "yadif" => parts.push("yadif".to_string()),
            "bwdif" => parts.push("bwdif".to_string()),
            "nnedi" => parts.push("nnedi".to_string()),
            _ => {}
        }
    }
    if let Some(mode) = filters.and_then(|f| f.denoise.as_deref()) {
        match mode {
            "hqdn3d" => parts.push("hqdn3d".to_string()),
            "nlmeans" => parts.push("nlmeans".to_string()),
            "atadenoise" => parts.push("atadenoise".to_string()),
            _ => {}
        }
    }
    if let Some(crop) = filters.and_then(build_crop_filter) {
        parts.push(crop);
    }
    if let Some(res) = &profile.resolution {
        if let Some(scale) = resolution_scale(res) {
            parts.push(scale);
        }
    }
    if let Some(fps) = profile.framerate {
        if fps > 0.0 {
            parts.push(format!("fps={}", fps));
        }
    }
    if filters.is_some_and(|f| f.hflip.unwrap_or(false)) {
        parts.push("hflip".to_string());
    }
    if filters.is_some_and(|f| f.vflip.unwrap_or(false)) {
        parts.push("vflip".to_string());
    }
    if let Some(deg) = filters.and_then(|f| f.rotate) {
        let transpose = match deg {
            90 => "transpose=1",
            180 => "transpose=2",
            270 => "transpose=3",
            _ => "",
        };
        if !transpose.is_empty() {
            parts.push(transpose.to_string());
        }
    }
    parts
}

fn add_filter_graph(args: &mut Vec<String>, profile: &VideoProfile, family: EncoderFamily) {
    let mut filter_parts = base_filter_parts(profile);
    if let Some(seg) = color_setparams_filter(profile) {
        filter_parts.push(seg);
    }
    // Keep the selected depth across hwdownload/hwupload: hardcoding nv12 here
    // silently crushed 10-bit/HDR frames to 8-bit whenever a filter was active.
    let sw_fmt = profile.pixel_format.as_deref().unwrap_or("nv12");
    if family == EncoderFamily::Vulkan {
        filter_parts.insert(0, format!("format={}", sw_fmt));
        filter_parts.push("hwupload".to_string());
    } else if !filter_parts.is_empty() && family == EncoderFamily::Vaapi {
        filter_parts.insert(0, format!("format={}", sw_fmt));
        filter_parts.insert(0, "hwdownload".to_string());
        filter_parts.push("hwupload".to_string());
    }
    if !filter_parts.is_empty() {
        args.push("-vf".to_string());
        args.push(filter_parts.join(","));
    }
}

fn push_hwaccel_args(args: &mut Vec<String>, family: EncoderFamily) {
    // AMF/NVENC/QSV: software decode — the encoder uploads system-memory frames itself
    if family != EncoderFamily::Vaapi {
        return;
    }
    args.push("-hwaccel".to_string());
    args.push("vaapi".to_string());
    args.push("-hwaccel_output_format".to_string());
    args.push("vaapi".to_string());
    if let Some(dev) = detect_vaapi_device() {
        args.push("-vaapi_device".to_string());
        args.push(dev);
    }
}

fn add_av1_params(args: &mut Vec<String>, profile: &VideoProfile, enc: &str) {
    // -svtav1-params is libsvtav1-only
    if profile.codec != "av1" || enc != "libsvtav1" {
        return;
    }
    let mut svt = Vec::new();
    if let Some(p) = &profile.preset {
        svt.push(format!("preset={}", p));
    }
    if profile.enable_qm.unwrap_or(false) {
        svt.push("enable-qm=1".to_string());
    }
    if let Some(tune) = &profile.tune {
        svt.push(format!(
            "tune={}",
            match tune.to_lowercase().as_str() {
                "psnr" => "0",
                "ssim" => "1",
                "vmaf" => "2",
                _ => "0",
            }
        ));
    }
    match profile.rate_control.as_deref() {
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

fn add_animation_params(args: &mut Vec<String>, profile: &VideoProfile) {
    let q = profile.quality.unwrap_or(DEFAULT_QUALITY).clamp(0, 100);
    let looping = profile.loop_enabled.unwrap_or(true);

    let mut parts = base_filter_parts(profile);

    if profile.codec == "gif" {
        let colors = (((q as f32 / 100.0) * 256.0).round() as u32).clamp(2, 256);
        parts.push(format!(
            "split[s0][s1];[s0]palettegen=max_colors={}[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5",
            colors
        ));
        args.push("-vf".to_string());
        args.push(parts.join(","));
        args.push("-loop".to_string());
        args.push(if looping { "0" } else { "-1" }.to_string());
    } else {
        if !parts.is_empty() {
            args.push("-vf".to_string());
            args.push(parts.join(","));
        }
        args.push("-quality".to_string());
        args.push(q.to_string());
        args.push("-loop".to_string());
        args.push(if looping { "0" } else { "1" }.to_string());
    }
}

fn add_input_and_trim(args: &mut Vec<String>, input: &str, start_time: f64, end_time: f64) {
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
}

/// Resolved output color metadata: explicit profile values win; tone mapping
/// without explicit tags forces SDR (bt709/tv) so the output doesn't claim HDR
/// (the tonemap filter leaves the HDR tags on the frames it converts).
fn color_metadata(profile: &VideoProfile) -> [Option<&str>; 4] {
    let toned = profile
        .video_filters
        .as_ref()
        .is_some_and(|f| f.tonemap.is_some());
    let sdr = if toned { Some("bt709") } else { None };
    let range_default = if toned { Some("tv") } else { None };
    [
        profile.color_primaries.as_deref().or(sdr),
        profile.color_trc.as_deref().or(sdr),
        profile.colorspace.as_deref().or(sdr),
        profile.color_range.as_deref().or(range_default),
    ]
}

/// -color_* output flags: honored by older ffmpeg versions.
fn add_color_flags(args: &mut Vec<String>, profile: &VideoProfile) {
    let [primaries, trc, space, range] = color_metadata(profile);
    for (flag, value) in [
        ("-color_primaries", primaries),
        ("-color_trc", trc),
        ("-colorspace", space),
        ("-color_range", range),
    ] {
        if let Some(value) = value {
            args.push(flag.to_string());
            args.push(value.to_string());
        }
    }
}

/// setparams filter: forces the same metadata onto the frames themselves,
/// which is what ffmpeg 9+ derives the encoder's color info from (it ignores
/// -color_primaries/-color_trc).
fn color_setparams_filter(profile: &VideoProfile) -> Option<String> {
    let [primaries, trc, space, range] = color_metadata(profile);
    let mut parts = Vec::new();
    for (name, value) in [
        ("color_primaries", primaries),
        ("color_trc", trc),
        ("colorspace", space),
        ("range", range),
    ] {
        if let Some(value) = value {
            parts.push(format!("{}={}", name, value));
        }
    }
    (!parts.is_empty()).then(|| format!("setparams={}", parts.join(":")))
}

fn add_video_branch(
    args: &mut Vec<String>,
    profile: &VideoProfile,
    enc: &str,
    family: EncoderFamily,
) {
    args.push("-c:v".to_string());
    args.push(enc.to_string());
    if enc == "copy" {
        // stream copy: no re-encode params, no filters
    } else if is_animated_codec(&profile.codec) {
        add_animation_params(args, profile);
    } else {
        add_rate_control(args, profile, enc);
        add_codec_specific(args, profile, enc);
        add_filter_graph(args, profile, family);
        add_av1_params(args, profile, enc);
        add_color_flags(args, profile);
    }
    for arg in &profile.extra_args {
        args.push(arg.clone());
    }
}

fn add_audio_filter_chain(args: &mut Vec<String>, profile: &VideoProfile) {
    let filters = profile.audio_filters.as_ref();
    let mut parts = Vec::new();
    if filters.is_some_and(|f| f.normalize.unwrap_or(false)) {
        // Two-pass normalization: real gain comes in via gain_db; previews show a placeholder
        let volume = filters.and_then(|f| f.gain_db).map_or_else(
            || "volume=<computed>dB".to_string(),
            |g| format!("volume={}dB", g),
        );
        parts.push(volume);
    } else {
        if let Some(gain) = filters.and_then(|f| f.gain_db) {
            parts.push(format!("volume={}dB", gain));
        }
        if filters.is_some_and(|f| f.loudnorm.unwrap_or(false)) {
            let i = filters.and_then(|f| f.loudnorm_i).unwrap_or(-14.0);
            let tp = filters.and_then(|f| f.loudnorm_tp).unwrap_or(-1.5);
            let lra = filters.and_then(|f| f.loudnorm_lra).unwrap_or(11.0);
            parts.push(format!("loudnorm=I={}:TP={}:LRA={}", i, tp, lra));
        }
    }
    if !parts.is_empty() {
        args.push("-af".to_string());
        args.push(parts.join(","));
    }
}

fn default_audio_quality(codec: &str) -> &'static str {
    match codec {
        "libopus" => "10",
        "flac" => "5",
        "libmp3lame" => "4",
        "libvorbis" => "3",
        _ => "4",
    }
}

fn add_audio_rate_control(args: &mut Vec<String>, profile: &VideoProfile, audio_codec: &str) {
    // PCM is uncompressed: bitrate and quality knobs do not apply
    if audio_codec.starts_with("pcm") {
        return;
    }
    let rate_control = profile
        .audio_filters
        .as_ref()
        .and_then(|f| f.rate_control.as_deref());
    let quality = profile
        .audio_filters
        .as_ref()
        .and_then(|f| f.quality.as_ref())
        .map(|s| s.as_str())
        .unwrap_or_else(|| default_audio_quality(audio_codec));
    // FLAC is lossless-compressed by level: no bitrate argument, whatever the mode
    let emit_bitrate = !profile.audio_bitrate.is_empty() && audio_codec != "flac";

    match rate_control {
        Some("vbr") => match audio_codec {
            "libopus" => {
                args.push("-vbr".to_string());
                args.push("on".to_string());
                if emit_bitrate {
                    args.push("-b:a".to_string());
                    args.push(profile.audio_bitrate.clone());
                }
            }
            "libmp3lame" | "libvorbis" => {
                args.push("-q:a".to_string());
                args.push(quality.to_string());
            }
            _ => {
                if emit_bitrate {
                    args.push("-b:a".to_string());
                    args.push(profile.audio_bitrate.clone());
                }
            }
        },
        Some("quality") => match audio_codec {
            "libopus" | "flac" => {
                args.push("-compression_level".to_string());
                args.push(quality.to_string());
            }
            "libmp3lame" | "libvorbis" => {
                args.push("-q:a".to_string());
                args.push(quality.to_string());
            }
            _ => {}
        },
        _ => {
            // CBR / default
            if audio_codec == "libopus" {
                args.push("-vbr".to_string());
                args.push("off".to_string());
            }
            if emit_bitrate {
                args.push("-b:a".to_string());
                args.push(profile.audio_bitrate.clone());
            }
        }
    }
}

fn add_audio_branch(args: &mut Vec<String>, profile: &VideoProfile) {
    if is_animated_codec(&profile.codec) || !profile.audio_enabled.unwrap_or(true) {
        args.push("-an".to_string());
    } else {
        let audio_codec = audio_codec_for_profile(profile);
        args.push("-c:a".to_string());
        args.push(audio_codec.to_string());
        if audio_codec == "copy" {
            // stream copy: no bitrate/channels/rate overrides
        } else {
            add_audio_filter_chain(args, profile);
            add_audio_rate_control(args, profile, audio_codec);
            if audio_codec != "flac" {
                if let Some(ch) = profile.audio_channels {
                    args.push("-ac".to_string());
                    args.push(ch.to_string());
                }
            }
            if let Some(sr) = profile.audio_sample_rate {
                args.push("-ar".to_string());
                args.push(sr.to_string());
            }
        }
    }
}

pub(crate) fn build_command(
    input: &str,
    output: &str,
    start_time: f64,
    end_time: f64,
    profile: &VideoProfile,
) -> Vec<String> {
    if let Some(cmd) = &profile.custom_command {
        if !cmd.trim().is_empty() {
            return super::command::build_custom_command(cmd, input, output, start_time, end_time);
        }
    }

    let video_enabled = profile.video_enabled.unwrap_or(true);
    let enc = video_codec(profile);
    let family = if profile.encoder.is_some() {
        encoder_family(&enc)
    } else {
        EncoderFamily::Software
    };
    let mut args = Vec::new();

    let video_is_copy = video_enabled && enc == "copy";
    if video_enabled && !video_is_copy {
        push_hwaccel_args(&mut args, family);
    }

    add_input_and_trim(&mut args, input, start_time, end_time);
    add_stream_mapping(&mut args, profile);

    if video_enabled {
        add_video_branch(&mut args, profile, &enc, family);
    } else {
        // Mirror -an: without -map, ffmpeg's auto-selection would still pick video
        args.push("-vn".to_string());
    }

    add_audio_branch(&mut args, profile);

    args.push("-y".to_string());
    args.push(normalize_path(output));

    args
}

pub(crate) fn build_preview(profile: &VideoProfile) -> Vec<String> {
    build_command("[input]", "[output]", 0.0, 0.0, profile)
}

pub(crate) fn build_normalize_measurement_command(
    input: &str,
    start_time: f64,
    end_time: f64,
    profile: &VideoProfile,
    target_i: f64,
    target_tp: f64,
) -> Vec<String> {
    let mut args = Vec::new();
    args.push("-hide_banner".to_string());
    add_input_and_trim(&mut args, input, start_time, end_time);
    // Analysis is audio-only: never decode video for the measurement pass.
    args.push("-vn".to_string());
    add_audio_stream_mapping(&mut args, profile);
    args.push("-af".to_string());
    args.push(format!(
        "loudnorm=I={}:TP={}:LRA=11:print_format=json",
        target_i, target_tp
    ));
    args.push("-f".to_string());
    args.push("null".to_string());
    args.push("-".to_string());
    args
}

pub(crate) fn parse_normalize_gain(stderr: &str, target_i: f64, target_tp: f64) -> Option<f64> {
    // Scan brace-delimited candidates: banner/warning text must not break extraction
    for (start, _) in stderr.match_indices('{') {
        let Some(end) = stderr[start..].find('}') else {
            continue;
        };
        let Ok(data) = serde_json::from_str::<serde_json::Value>(&stderr[start..start + end + 1])
        else {
            continue;
        };
        let (Some(input_i), Some(input_tp)) = (data["input_i"].as_str(), data["input_tp"].as_str())
        else {
            continue;
        };
        let (Ok(input_i), Ok(input_tp)) = (input_i.parse::<f64>(), input_tp.parse::<f64>()) else {
            continue;
        };
        let gain = target_i - input_i;
        let max_gain = target_tp - input_tp;
        return Some(gain.min(max_gain));
    }
    None
}

pub(crate) fn compute_normalize_gain(
    input: &str,
    start_time: f64,
    end_time: f64,
    profile: &VideoProfile,
) -> anyhow::Result<f64> {
    let filters = profile.audio_filters.as_ref();
    if !filters.is_some_and(|f| f.normalize.unwrap_or(false)) {
        return Err(anyhow::anyhow!("normalization not enabled"));
    }
    let target_i = filters.and_then(|f| f.normalize_target_i).unwrap_or(-14.0);
    let target_tp = filters.and_then(|f| f.normalize_target_tp).unwrap_or(-1.5);

    let args = build_normalize_measurement_command(
        input, start_time, end_time, profile, target_i, target_tp,
    );
    let output = quiet_command("ffmpeg")
        .args(&args)
        .output()
        .context("failed to run ffmpeg normalization analysis")?;
    if !output.status.success() {
        return Err(anyhow::anyhow!("ffmpeg normalization analysis failed"));
    }
    let stderr = String::from_utf8_lossy(&output.stderr);
    parse_normalize_gain(&stderr, target_i, target_tp)
        .ok_or_else(|| anyhow::anyhow!("could not parse loudnorm analysis output"))
}
