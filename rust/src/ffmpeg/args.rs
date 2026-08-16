use crate::config::VideoProfile;
use crate::ffmpeg::{
    audio_codec_for_profile, detect_vaapi_device, encoder_capabilities, encoder_family,
    normalize_path, video_codec, EncoderFamily,
};

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
            let rc_mode = if rc_flag == "-rc" {
                mode.to_lowercase()
            } else {
                mode.to_uppercase()
            };
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
                let crf_flag = caps.as_ref().map(|c| c.crf_flag.as_str()).unwrap_or("-crf");
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

fn add_codec_specific(args: &mut Vec<String>, profile: &VideoProfile, enc: &str) {
    let caps = encoder_capabilities(enc);

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
                    args.push("-preset".to_string());
                    args.push(preset.clone());
                }
            }
        }
    }
    if let Some(level) = &profile.compression_level {
        if !level.is_empty() {
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

fn add_filter_graph(args: &mut Vec<String>, profile: &VideoProfile, family: EncoderFamily) {
    let mut filter_parts = Vec::new();
    if let Some(fps) = profile.framerate {
        if fps > 0.0 {
            filter_parts.push(format!("fps={}", fps));
        }
    }
    if let Some(res) = &profile.resolution {
        if let Some(scale) = resolution_scale(res) {
            filter_parts.push(scale);
        }
    }
    if family == EncoderFamily::Vulkan {
        filter_parts.insert(0, "format=nv12".to_string());
        filter_parts.push("hwupload".to_string());
    } else if !filter_parts.is_empty() && family != EncoderFamily::Software {
        filter_parts.insert(0, "format=nv12".to_string());
        filter_parts.insert(0, "hwdownload".to_string());
        filter_parts.push("hwupload".to_string());
    }
    if !filter_parts.is_empty() {
        args.push("-vf".to_string());
        args.push(filter_parts.join(","));
    }
}

fn add_av1_params(args: &mut Vec<String>, profile: &VideoProfile) {
    if profile.codec != "av1" {
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
    let q = profile.quality.unwrap_or(75).clamp(0, 100);
    let looping = profile.loop_enabled.unwrap_or(true);

    let mut parts: Vec<String> = Vec::new();
    if let Some(fps) = profile.framerate {
        if fps > 0.0 {
            parts.push(format!("fps={}", fps));
        }
    }
    if let Some(res) = &profile.resolution {
        if let Some(scale) = resolution_scale(res) {
            parts.push(scale);
        }
    }

    if profile.codec == "gif" {
        let colors = (((q as f32 / 100.0) * 256.0).round() as u32).clamp(2, 256);
        parts.push(format!(
            "split[s0][s1];[s0]palettegen=max_colors={}[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5",
            colors
        ));
        if !parts.is_empty() {
            args.push("-vf".to_string());
            args.push(parts.join(","));
        }
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

pub(crate) fn build_command(
    input: &str,
    output: &str,
    start_time: f64,
    end_time: f64,
    profile: &VideoProfile,
) -> Vec<String> {
    let mut args = Vec::new();

    let video_enabled = profile.video_enabled.unwrap_or(true);

    if video_enabled {
        let enc = video_codec(profile);
        let family = if profile.encoder.is_some() {
            encoder_family(&enc)
        } else {
            EncoderFamily::Software
        };

        match family {
            EncoderFamily::Vaapi => {
                args.push("-hwaccel".to_string());
                args.push("vaapi".to_string());
                args.push("-hwaccel_output_format".to_string());
                args.push("vaapi".to_string());
                if let Some(dev) = detect_vaapi_device() {
                    args.push("-vaapi_device".to_string());
                    args.push(dev);
                }
            }
            EncoderFamily::Nvenc => {
                args.push("-hwaccel".to_string());
                args.push("cuda".to_string());
                args.push("-hwaccel_output_format".to_string());
                args.push("cuda".to_string());
            }
            EncoderFamily::Qsv => {
                args.push("-init_hw_device".to_string());
                args.push("qsv=qsv".to_string());
                args.push("-hwaccel".to_string());
                args.push("qsv".to_string());
                args.push("-hwaccel_output_format".to_string());
                args.push("qsv".to_string());
            }
            EncoderFamily::Amf => {
                args.push("-hwaccel".to_string());
                args.push("amf".to_string());
                args.push("-hwaccel_output_format".to_string());
                args.push("amf".to_string());
            }
            //EncoderFamily::Vulkan => {
            //    args.push("-init_hw_device".to_string());
            //    args.push("vulkan".to_string());
            //}
            _ => {}
        }
    }

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

    if video_enabled {
        let enc = video_codec(profile);
        let family = if profile.encoder.is_some() {
            encoder_family(&enc)
        } else {
            EncoderFamily::Software
        };

        args.push("-c:v".to_string());
        args.push(enc.clone());

        if is_animated_codec(&profile.codec) {
            add_animation_params(&mut args, profile);
        } else {
            add_rate_control(&mut args, profile, &enc);
            add_codec_specific(&mut args, profile, &enc);
            add_filter_graph(&mut args, profile, family);
            add_av1_params(&mut args, profile);
        }

        for arg in &profile.extra_args {
            args.push(arg.clone());
        }
    }

    if is_animated_codec(&profile.codec) || !profile.audio_enabled.unwrap_or(true) {
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
