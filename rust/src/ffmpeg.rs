use serde::Serialize;

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
    let mut args = Vec::new();

    // Input
    if start_time > 0.0 {
        args.push("-ss".to_string());
        args.push(format!("{}", start_time));
    }
    args.push("-i".to_string());
    args.push(input.to_string());

    // Time duration
    if end_time > start_time {
        args.push("-t".to_string());
        args.push(format!("{:.3}", end_time - start_time));
    }

    // Profile
    if let Ok(profile) = serde_json::from_str::<super::config::VideoProfile>(profile_json) {
        // Video codec
        args.push("-c:v".to_string());
        args.push(profile.codec);

        // CRF or bitrate
        if let Some(crf) = profile.crf {
            args.push("-crf".to_string());
            args.push(format!("{}", crf));
        }
        if let Some(bitrate) = &profile.bitrate {
            args.push("-b:v".to_string());
            args.push(bitrate.clone());
        }

        // Preset
        if let Some(preset) = &profile.preset {
            args.push("-preset".to_string());
            args.push(preset.clone());
        }

        // Pixel format
        if let Some(pix_fmt) = &profile.pixel_format {
            args.push("-pix_fmt".to_string());
            args.push(pix_fmt.clone());
        }

        // AV1-specific params
        if let Some(av1) = &profile.av1_params {
            let mut svt_params = Vec::new();
            svt_params.push(format!("preset={}", av1.preset));

            if av1.enable_qm {
                svt_params.push("enable-qm=1".to_string());
            }

            let tune = av1.tune.to_lowercase();
            let tune_val = match tune.as_str() {
                "psnr" => "0",
                "ssim" => "1",
                "vmaf" => "2",
                _ => "0",
            };
            svt_params.push(format!("tune={}", tune_val));

            if let Some(crf) = av1.crf {
                svt_params.push(format!("crf={}", crf));
            }
            if let Some(tr) = av1.tile_rows {
                svt_params.push(format!("tile-rows={}", tr));
            }
            if let Some(tc) = av1.tile_columns {
                svt_params.push(format!("tile-columns={}", tc));
            }

            args.push("-svtav1-params".to_string());
            args.push(svt_params.join(":"));
        }

        // Extra args
        args.extend(profile.extra_args);
    }

    // Audio handling based on output container
    let is_webm = output.to_lowercase().ends_with(".webm");
    if is_webm {
        args.push("-c:a".to_string());
        args.push("libopus".to_string());
        args.push("-b:a".to_string());
        args.push("128k".to_string());
    } else {
        args.push("-c:a".to_string());
        args.push("copy".to_string());
    }

    // Overwrite output
    args.push("-y".to_string());

    // Output
    args.push(output.to_string());

    args
}

#[allow(unused_variables)]
pub fn parse_ffprobe_output(_json: &str) -> VideoInfo {
    // Simplified ffprobe JSON parsing
    // In production, use serde to parse actual ffprobe output
    VideoInfo {
        duration: 0.0,
        width: 0,
        height: 0,
        fps: 0.0,
        codec: "unknown".to_string(),
        bitrate: 0,
    }
}
