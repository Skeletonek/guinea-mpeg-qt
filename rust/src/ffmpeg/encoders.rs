use crate::ffmpeg::{EncoderCapabilities, EncoderFamily};

pub(crate) fn encoder_family(encoder: &str) -> EncoderFamily {
    if matches!(encoder, "libx264" | "libx265")
        || encoder.starts_with("libvpx")
        || encoder == "libsvtav1"
        || encoder == "libaom-av1"
        || encoder == "librav1e"
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
    } else {
        EncoderFamily::Software
    }
}

pub(crate) fn encoder_capabilities(encoder: &str) -> Option<EncoderCapabilities> {
    if let Some(caps) = software_quality_caps(encoder) {
        return Some(caps);
    }
    match encoder_family(encoder) {
        EncoderFamily::Software => None,
        EncoderFamily::Nvenc => Some(EncoderCapabilities {
            presets: Some(
                vec!["p1", "p2", "p3", "p4", "p5", "p6", "p7"]
                    .into_iter()
                    .map(String::from)
                    .collect(),
            ),
            tunes: Some(
                vec!["hq", "ll", "ull", "lossless"]
                    .into_iter()
                    .map(String::from)
                    .collect(),
            ),
            pix_fmts: Some(
                vec!["yuv420p", "nv12", "p010le", "yuv444p"]
                    .into_iter()
                    .map(String::from)
                    .collect(),
            ),
            uses_preset: true,
            uses_tune: true,
            uses_compression_level: false,
            crf_flag: "-cq".into(),
            rc_flag: Some("-rc".into()),
            crf_min: None,
            crf_max: None,
        }),
        EncoderFamily::Qsv => Some(EncoderCapabilities {
            presets: Some(
                vec![
                    "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow",
                ]
                .into_iter()
                .map(String::from)
                .collect(),
            ),
            // QSV has no -tune option
            tunes: None,
            pix_fmts: Some(
                vec!["nv12", "yuv420p", "p010le"]
                    .into_iter()
                    .map(String::from)
                    .collect(),
            ),
            uses_preset: true,
            uses_tune: false,
            uses_compression_level: false,
            crf_flag: "-global_quality".into(),
            // QSV has no -rc option: ffmpeg picks CBR/VBR from -b:v/-maxrate
            rc_flag: None,
            crf_min: None,
            crf_max: None,
        }),
        EncoderFamily::Vaapi => Some(EncoderCapabilities {
            presets: None,
            tunes: None,
            pix_fmts: Some(
                vec!["nv12", "vaapi_vld", "p010le"]
                    .into_iter()
                    .map(String::from)
                    .collect(),
            ),
            uses_preset: false,
            uses_tune: false,
            uses_compression_level: true,
            crf_flag: "-qp".into(),
            rc_flag: Some("-rc_mode".into()),
            crf_min: None,
            crf_max: None,
        }),
        EncoderFamily::Amf => Some(EncoderCapabilities {
            presets: Some(
                vec!["speed", "balanced", "quality"]
                    .into_iter()
                    .map(String::from)
                    .collect(),
            ),
            // AMF has no -tune option
            tunes: None,
            pix_fmts: Some(
                vec!["nv12", "yuv420p", "p010le"]
                    .into_iter()
                    .map(String::from)
                    .collect(),
            ),
            uses_preset: true,
            uses_tune: false,
            uses_compression_level: false,
            // no CRF on AMF: add_rate_control() maps the value to -rc cqp + -qp_*
            crf_flag: "-qp_i".into(),
            rc_flag: Some("-rc".into()),
            crf_min: None,
            crf_max: None,
        }),
        EncoderFamily::Vulkan => Some(EncoderCapabilities {
            presets: None,
            tunes: None,
            pix_fmts: Some(
                vec!["yuv420p", "nv12", "gbrp10le"]
                    .into_iter()
                    .map(String::from)
                    .collect(),
            ),
            uses_preset: false,
            uses_tune: false,
            uses_compression_level: false,
            crf_flag: "-crf".into(),
            rc_flag: None,
            crf_min: None,
            crf_max: None,
        }),
    }
}

/// Capabilities for plain software encoders that don't use the x264-style
/// model: quality via -q:v (clamped to the encoder's scale) or none at all,
/// and no preset/tune/compression_level knobs.
fn software_quality_caps(encoder: &str) -> Option<EncoderCapabilities> {
    let (crf_flag, range, pix_fmts): (&str, Option<(i32, i32)>, &[&str]) = match encoder {
        "mjpeg" => ("-q:v", Some((2, 31)), &["yuv420p", "yuv422p", "yuv444p"]),
        "mpeg2video" => ("-q:v", Some((2, 31)), &["yuv420p", "yuv422p"]),
        "mpeg4" | "libxvid" => ("-q:v", Some((2, 31)), &["yuv420p"]),
        "libtheora" => ("-q:v", Some((0, 10)), &["yuv420p", "yuv422p", "yuv444p"]),
        // empty crf_flag: ffv1 is lossless, there is no quality knob
        "ffv1" => (
            "",
            None,
            &[
                "yuv420p",
                "yuv422p",
                "yuv444p",
                "yuv420p10le",
                "yuv422p10le",
                "yuv444p10le",
                "bgr0",
                "gray",
            ],
        ),
        _ => return None,
    };
    Some(EncoderCapabilities {
        presets: None,
        tunes: None,
        pix_fmts: Some(pix_fmts.iter().map(|s| s.to_string()).collect()),
        uses_preset: false,
        uses_tune: false,
        uses_compression_level: false,
        crf_flag: crf_flag.into(),
        rc_flag: None,
        crf_min: range.map(|r| r.0),
        crf_max: range.map(|r| r.1),
    })
}

/// True for pixel formats with more than 8 bits per component ("yuv420p10le",
/// "p010le", "yuv422p12le", ...). Matched on the depth marker before the
/// endianness suffix: substring checks on "10"/"12" alone would hit "nv12".
fn is_high_bit_depth(pix_fmt: &str) -> bool {
    [
        "10le", "12le", "14le", "16le", "10be", "12be", "14be", "16be",
    ]
    .iter()
    .any(|d| pix_fmt.ends_with(d))
}

/// Picks a 10-bit pixel format for a high-bit-depth source when the profile
/// leaves the pixel format at "default". 8-bit-only encoders (libx264 in most
/// distro builds, VP8, legacy codecs) are skipped: the intended path there is
/// tone mapping or an explicit user choice, not a silent depth reduction.
pub(crate) fn auto_pixel_format(encoder: &str, source_pix_fmt: &str) -> Option<String> {
    if !is_high_bit_depth(source_pix_fmt) {
        return None;
    }
    match encoder_family(encoder) {
        EncoderFamily::Nvenc | EncoderFamily::Qsv | EncoderFamily::Vaapi | EncoderFamily::Amf => {
            Some("p010le".to_string())
        }
        EncoderFamily::Vulkan => Some("gbrp10le".to_string()),
        EncoderFamily::Software => match encoder {
            "libx265" | "libsvtav1" | "libaom-av1" | "librav1e" | "libvpx-vp9" | "ffv1" => {
                Some("yuv420p10le".to_string())
            }
            _ => None,
        },
    }
}

pub(crate) fn software_video_codec(codec: &str) -> &str {
    match codec {
        "h264" => "libx264",
        "hevc" => "libx265",
        "vp8" => "libvpx",
        "vp9" => "libvpx-vp9",
        "av1" => "libsvtav1",
        "ffv1" => "ffv1",
        "mjpeg" => "mjpeg",
        "mpeg2video" => "mpeg2video",
        "mpeg4" => "mpeg4",
        "theora" => "libtheora",
        "gif" => "gif",
        "webp" => "libwebp_anim",
        _ => "libx264",
    }
}

pub(crate) fn detect_vaapi_device() -> Option<String> {
    #[cfg(not(target_os = "linux"))]
    return None;

    #[cfg(target_os = "linux")]
    {
        let dir = std::path::Path::new("/dev/dri");
        if !dir.is_dir() {
            return None;
        }
        for entry in std::fs::read_dir(dir).ok()? {
            let Ok(entry) = entry else {
                continue;
            };
            let name = entry.file_name();
            let name = name.to_string_lossy();
            if name.starts_with("renderD") {
                let path = entry.path();
                if std::fs::File::open(&path).is_ok() {
                    return Some(path.to_string_lossy().to_string());
                }
            }
        }
        None
    }
}
