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
fn software_video_codec_mapping() {
    assert_eq!(software_video_codec("h264"), "libx264");
    assert_eq!(software_video_codec("hevc"), "libx265");
    assert_eq!(software_video_codec("vp8"), "libvpx");
    assert_eq!(software_video_codec("vp9"), "libvpx-vp9");
    assert_eq!(software_video_codec("av1"), "libsvtav1");
    assert_eq!(software_video_codec("ffv1"), "ffv1");
    assert_eq!(software_video_codec("mjpeg"), "mjpeg");
    assert_eq!(software_video_codec("mpeg2video"), "mpeg2video");
    assert_eq!(software_video_codec("mpeg4"), "mpeg4");
    assert_eq!(software_video_codec("theora"), "libtheora");
    assert_eq!(software_video_codec("gif"), "gif");
    assert_eq!(software_video_codec("webp"), "libwebp_anim");
}
