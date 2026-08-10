use crate::ffmpeg::{EncoderCapabilities, EncoderFamily};

pub(crate) fn encoder_family(encoder: &str) -> EncoderFamily {
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
    } else {
        EncoderFamily::Software
    }
}

pub(crate) fn encoder_capabilities(encoder: &str) -> Option<EncoderCapabilities> {
    Some(match encoder_family(encoder) {
        EncoderFamily::Nvenc => EncoderCapabilities {
            presets: Some(vec!["p1","p2","p3","p4","p5","p6","p7"].into_iter().map(String::from).collect()),
            tunes: Some(vec!["hq","ll","ull","lossless"].into_iter().map(String::from).collect()),
            pix_fmts: Some(vec!["yuv420p","nv12","p010le","yuv444p"].into_iter().map(String::from).collect()),
            uses_preset: true,
            uses_tune: true,
            uses_compression_level: false,
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
            uses_compression_level: false,
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
            uses_compression_level: true,
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
            uses_compression_level: false,
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
            uses_compression_level: false,
            crf_flag: "-crf".into(),
            vbr_flag: "-b:v".into(),
            cbr_flag: "-b:v".into(),
            rc_flag: None,
        },
        EncoderFamily::Software => return None,
    })
}

pub(crate) fn software_video_codec(codec: &str) -> &str {
    match codec {
        "h264" => "libx264",
        "hevc" => "libx265",
        "vp8" => "libvpx",
        "vp9" => "libvpx-vp9",
        "av1" => "libsvtav1",
        "gif" => "gif",
        "webp" => "libwebp",
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
            let entry = entry.ok()?;
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
