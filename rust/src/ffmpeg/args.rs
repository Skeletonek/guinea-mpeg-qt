use crate::config::VideoProfile;
use crate::ffmpeg::{audio_codec_for_profile, encoder_capabilities, encoder_family, normalize_path, video_codec, EncoderFamily};

fn push_rc_flag(args: &mut Vec<String>, family: EncoderFamily, caps: &Option<super::EncoderCapabilities>, mode: &str) {
    if family == EncoderFamily::Vaapi {
        args.push("-rc_mode".to_string());
        args.push(mode.to_uppercase());
    } else if let Some(ref caps) = caps {
        if let Some(ref rc_flag) = caps.rc_flag {
            let rc_mode = if rc_flag == "-rc" { mode.to_lowercase() } else { mode.to_uppercase() };
            args.push(rc_flag.clone());
            args.push(rc_mode);
        }
    }
}

fn add_stream_mapping(args: &mut Vec<String>, profile: &VideoProfile) {
    let video_enabled = profile.video_enabled.unwrap_or(true);
    let audio_enabled = profile.audio_enabled.unwrap_or(true);
    let vs_idxs = &profile.video_stream_indices;
    let as_idxs = &profile.audio_stream_indices;
    if vs_idxs.is_empty() && as_idxs.is_empty() {
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

fn add_rate_control(args: &mut Vec<String>, profile: &VideoProfile, enc: &str) {
    let family = if profile.encoder.is_some() {
        encoder_family(enc)
    } else {
        EncoderFamily::Software
    };
    let caps = encoder_capabilities(enc);

    match profile.rate_control.as_deref() {
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
                    push_rc_flag(args, family, &caps, "cbr");
                }
            }
        }
        Some("vbr") | Some("bitrate") => {
            if let Some(bitrate) = &profile.bitrate {
                if !bitrate.is_empty() {
                    args.push("-b:v".to_string());
                    args.push(bitrate.clone());
                    push_rc_flag(args, family, &caps, "vbr");
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
            if profile.rate_control.is_none() {
                if let Some(bitrate) = &profile.bitrate {
                    if !bitrate.is_empty() {
                        args.push("-b:v".to_string());
                        args.push(bitrate.clone());
                    }
                }
            }
        }
    }
}

fn add_codec_specific(args: &mut Vec<String>, profile: &VideoProfile) {
    match profile.codec.as_str() {
        "h264" | "hevc" => {
            if let Some(preset) = &profile.preset {
                args.push("-preset".to_string());
                args.push(preset.clone());
            }
        }
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
        codec => {
            if let Some(preset) = &profile.preset {
                if codec != "svtav1" {
                    args.push("-preset".to_string());
                    args.push(preset.clone());
                }
            }
        }
    }
    if let Some(pix_fmt) = &profile.pixel_format {
        args.push("-pix_fmt".to_string());
        args.push(pix_fmt.clone());
    }
    if let Some(tune) = &profile.tune {
        match profile.codec.as_str() {
            "h264" | "hevc" | "svtav1" => {
                args.push("-tune".to_string());
                args.push(tune.clone());
            }
            "vp8" | "vp9" => {
                if tune == "psnr" || tune == "ssim" {
                    args.push("-tune".to_string());
                    args.push(tune.clone());
                }
            }
            _ => {}
        }
    }
}

fn add_filter_graph(args: &mut Vec<String>, profile: &VideoProfile) {
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
}

fn add_svtav1_params(args: &mut Vec<String>, profile: &VideoProfile) {
    if profile.codec != "svtav1" {
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
        svt.push(format!("tune={}", match tune.to_lowercase().as_str() {
            "psnr" => "0",
            "ssim" => "1",
            "vmaf" => "2",
            _ => "0",
        }));
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

pub(crate) fn build_command(
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

    add_stream_mapping(&mut args, profile);

    if profile.video_enabled.unwrap_or(true) {
        let enc = video_codec(profile);
        args.push("-c:v".to_string());
        args.push(enc.clone());

        add_rate_control(&mut args, profile, &enc);
        add_codec_specific(&mut args, profile);
        add_filter_graph(&mut args, profile);
        add_svtav1_params(&mut args, profile);

        for arg in &profile.extra_args {
            args.push(arg.clone());
        }
    }

    if !profile.audio_enabled.unwrap_or(true) {
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

pub(crate) fn build_preview(profile: &VideoProfile) -> Vec<String> {
    build_command("[input]", "[output]", 0.0, 0.0, profile)
}
