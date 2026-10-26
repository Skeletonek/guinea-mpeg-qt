use crate::config::VideoProfile;
use crate::ffmpeg::{audio_codec_for_profile, video_codec};

fn profile(json: &str) -> VideoProfile {
    serde_json::from_str(json).unwrap()
}

#[test]
fn video_codec_defaults() {
    for (codec, expected) in [
        ("h264", "libx264"),
        ("hevc", "libx265"),
        ("vp8", "libvpx"),
        ("vp9", "libvpx-vp9"),
        ("av1", "libsvtav1"),
        ("ffv1", "ffv1"),
        ("mjpeg", "mjpeg"),
        ("mpeg2video", "mpeg2video"),
        ("mpeg4", "mpeg4"),
        ("theora", "libtheora"),
        ("gif", "gif"),
        ("webp", "libwebp_anim"),
    ] {
        let p = profile(&format!(r#"{{"codec":"{}"}}"#, codec));
        assert_eq!(video_codec(&p), expected);
    }
}

#[test]
fn video_codec_unknown_falls_back_to_libx264() {
    let p = profile(r#"{"codec":"unknown"}"#);
    assert_eq!(video_codec(&p), "libx264");
}

#[test]
fn video_codec_respects_encoder() {
    let p = profile(r#"{"codec":"h264","encoder":"h264_nvenc"}"#);
    assert_eq!(video_codec(&p), "h264_nvenc");
}

#[test]
fn audio_codec_defaults_per_video_codec() {
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"h264"}"#)),
        "aac"
    );
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"hevc"}"#)),
        "aac"
    );
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"vp8"}"#)),
        "libopus"
    );
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"vp9"}"#)),
        "libopus"
    );
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"av1"}"#)),
        "libopus"
    );
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"ffv1"}"#)),
        "flac"
    );
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"mjpeg"}"#)),
        "libmp3lame"
    );
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"mpeg2video"}"#)),
        "libmp3lame"
    );
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"mpeg4"}"#)),
        "libmp3lame"
    );
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"theora"}"#)),
        "libvorbis"
    );
}

#[test]
fn audio_codec_defaults_per_container() {
    for (container, expected) in [
        ("wav", "pcm_s16le"),
        ("wave", "pcm_s16le"),
        ("avi", "libmp3lame"),
        ("mpg", "libmp3lame"),
        ("mpeg", "libmp3lame"),
        ("ogv", "libvorbis"),
    ] {
        let p = profile(&format!(
            r#"{{"codec":"h264","container":"{}"}}"#,
            container
        ));
        assert_eq!(audio_codec_for_profile(&p), expected);
    }
}

#[test]
fn audio_codec_explicit_mapping() {
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"h264","audio_codec":"opus"}"#)),
        "libopus"
    );
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"h264","audio_codec":"flac"}"#)),
        "flac"
    );
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"h264","audio_codec":"vorbis"}"#)),
        "libvorbis"
    );
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"h264","audio_codec":"aac"}"#)),
        "aac"
    );
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"h264","audio_codec":"mp3"}"#)),
        "libmp3lame"
    );
}

#[test]
fn audio_codec_pcm_variants() {
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"h264","audio_codec":"pcm"}"#)),
        "pcm_s16le"
    );
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"h264","audio_codec":"wav"}"#)),
        "pcm_s16le"
    );
    // explicit pcm_* encoder names pass through verbatim
    for enc in ["pcm_u8", "pcm_s16le", "pcm_s24le", "pcm_f32le"] {
        let p = profile(&format!(r#"{{"codec":"h264","audio_codec":"{}"}}"#, enc));
        assert_eq!(audio_codec_for_profile(&p), enc);
    }
}

#[test]
fn audio_codec_unknown_falls_back_to_aac() {
    assert_eq!(
        audio_codec_for_profile(&profile(r#"{"codec":"h264","audio_codec":"ac3"}"#)),
        "aac"
    );
}
