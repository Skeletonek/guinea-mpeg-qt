use crate::ffmpeg::{encoder_capabilities, encoder_family, software_video_codec, EncoderFamily};

#[test]
fn encoder_family_classification() {
    assert_eq!(encoder_family("libx264"), EncoderFamily::Software);
    assert_eq!(encoder_family("libx265"), EncoderFamily::Software);
    assert_eq!(encoder_family("libvpx"), EncoderFamily::Software);
    assert_eq!(encoder_family("libvpx-vp9"), EncoderFamily::Software);
    assert_eq!(encoder_family("libsvtav1"), EncoderFamily::Software);
    assert_eq!(encoder_family("libaom-av1"), EncoderFamily::Software);
    assert_eq!(encoder_family("librav1e"), EncoderFamily::Software);
    assert_eq!(encoder_family("h264_nvenc"), EncoderFamily::Nvenc);
    assert_eq!(encoder_family("av1_nvenc"), EncoderFamily::Nvenc);
    assert_eq!(encoder_family("hevc_qsv"), EncoderFamily::Qsv);
    assert_eq!(encoder_family("h264_vaapi"), EncoderFamily::Vaapi);
    assert_eq!(encoder_family("av1_amf"), EncoderFamily::Amf);
    assert_eq!(encoder_family("av1_vulkan"), EncoderFamily::Vulkan);
    assert_eq!(encoder_family("unexpected"), EncoderFamily::Software);
}

#[test]
fn unknown_encoder_falls_back_to_software() {
    assert_eq!(encoder_family(""), EncoderFamily::Software);
    assert_eq!(encoder_family("bogus_enc"), EncoderFamily::Software);
    assert_eq!(encoder_family("av1"), EncoderFamily::Software);
    assert_eq!(encoder_family("_nvenc"), EncoderFamily::Nvenc);
    assert!(encoder_capabilities("bogus_enc").is_none());
}

#[test]
fn unknown_codec_maps_to_libx264() {
    assert_eq!(software_video_codec(""), "libx264");
    assert_eq!(software_video_codec("prores"), "libx264");
    assert_eq!(software_video_codec("theora"), "libx264");
}

#[test]
fn software_video_codec_mapping() {
    assert_eq!(software_video_codec("h264"), "libx264");
    assert_eq!(software_video_codec("hevc"), "libx265");
    assert_eq!(software_video_codec("vp8"), "libvpx");
    assert_eq!(software_video_codec("vp9"), "libvpx-vp9");
    assert_eq!(software_video_codec("av1"), "libsvtav1");
    assert_eq!(software_video_codec("gif"), "gif");
    assert_eq!(software_video_codec("webp"), "libwebp_anim");
    assert_eq!(software_video_codec("mpeg4"), "libx264");
}

#[test]
fn software_encoders_have_no_capabilities() {
    assert!(encoder_capabilities("libx264").is_none());
    assert!(encoder_capabilities("libsvtav1").is_none());
}

#[test]
fn nvenc_capabilities() {
    let caps = encoder_capabilities("h264_nvenc").unwrap();
    assert!(caps.uses_preset);
    assert!(caps.uses_tune);
    assert!(!caps.uses_compression_level);
    assert_eq!(caps.crf_flag, "-cq");
    assert_eq!(caps.rc_flag.as_deref(), Some("-rc"));
    assert_eq!(caps.presets.as_ref().unwrap().first().unwrap(), "p1");
    assert!(caps.pix_fmts.as_ref().unwrap().contains(&"yuv420p".to_string()));
}

#[test]
fn vaapi_capabilities() {
    let caps = encoder_capabilities("h264_vaapi").unwrap();
    assert!(!caps.uses_preset);
    assert!(!caps.uses_tune);
    assert!(caps.uses_compression_level);
    assert_eq!(caps.crf_flag, "-qp");
    assert_eq!(caps.rc_flag.as_deref(), Some("-rc_mode"));
    assert!(caps.presets.is_none());
    assert!(caps.tunes.is_none());
}

#[test]
fn qsv_capabilities() {
    let caps = encoder_capabilities("hevc_qsv").unwrap();
    assert_eq!(caps.crf_flag, "-global_quality");
    assert!(caps.uses_preset);
    assert!(caps.uses_tune);
}

#[test]
fn amf_and_vulkan_capabilities() {
    let amf = encoder_capabilities("h264_amf").unwrap();
    assert_eq!(amf.crf_flag, "-quality");
    assert!(amf.uses_preset);
    let vulkan = encoder_capabilities("av1_vulkan").unwrap();
    assert_eq!(vulkan.crf_flag, "-crf");
    assert!(vulkan.rc_flag.is_none());
    assert!(!vulkan.uses_preset);
}