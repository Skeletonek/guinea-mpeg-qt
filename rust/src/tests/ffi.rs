use crate::ffmpeg::parse_encoders;

const SAMPLE_ENCODERS: &str = "\
Encoders:
 V..... = Video
 V....D = Video & Depends
 ------
 V....D libx264              libx264 H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10, (codec h264)
 V....D libx264rgb           libx264 H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10, (codec h264)
 V..... h264_nvenc           NVIDIA NVENC H.264 encoder (codec h264)
 V..... hevc_qsv             HEVC (via QSV), (codec hevc)
 V..... h264_v4l2m2m         V4L2 (codec h264)
 V..... libsvtav1            SVT-AV1 encoder, (codec av1)
 V..... av1_vulkan           Vulkan AV1 encoder (codec av1)
 V....D ffv1                 FFmpeg video codec #1
 V....D mjpeg                MJPEG (Motion JPEG)
 V....D mpeg2video           MPEG-2 video
 V..... mpeg2_qsv            MPEG-2 video (Intel Quick Sync Video acceleration) (codec mpeg2video)
 V....D mpeg4                MPEG-4 part 2
 V..... libxvid              libxvidcore MPEG-4 part 2 (codec mpeg4)
 V..... libtheora            libtheora Theora (codec theora)
 V....D gif                  GIF (GIF/Compatibility)
 A..... aac                  AAC (Advanced Audio Coding)
";

#[test]
fn parses_encoder_output() {
    let map = parse_encoders(SAMPLE_ENCODERS);
    assert_eq!(map["h264"], vec!["h264_nvenc", "libx264", "libx264rgb"]);
    assert_eq!(map["hevc"], vec!["hevc_qsv"]);
    assert_eq!(map["av1"], vec!["libsvtav1"]);
    assert_eq!(map["gif"], vec!["gif"]);
}

#[test]
fn untagged_encoders_key_by_name() {
    let map = parse_encoders(SAMPLE_ENCODERS);
    assert_eq!(map["ffv1"], vec!["ffv1"]);
    assert_eq!(map["mjpeg"], vec!["mjpeg"]);
    assert_eq!(map["mpeg2video"], vec!["mpeg2_qsv", "mpeg2video"]);
    assert_eq!(map["mpeg4"], vec!["libxvid", "mpeg4"]);
    assert_eq!(map["theora"], vec!["libtheora"]);
}

#[test]
fn ignores_audio_and_headers() {
    let map = parse_encoders(SAMPLE_ENCODERS);
    assert!(!map.contains_key("aac"));
    // legend lines ("V..... = Video") must not be misparsed
    assert!(!map.contains_key("="));
}

#[test]
fn filters_hardware_families() {
    let map = parse_encoders(SAMPLE_ENCODERS);
    assert!(!map["h264"].contains(&"h264_v4l2m2m".to_string()));
    assert!(!map["av1"].contains(&"av1_vulkan".to_string()));
}

#[test]
fn empty_input_produces_empty_map() {
    assert!(parse_encoders("").is_empty());
    assert!(parse_encoders("no encoder lines here").is_empty());
}

#[test]
fn malformed_lines_are_skipped() {
    let malformed = "\
 V..... good_enc              Real encoder (codec h264)
 V..... broken                (codec 
 V..... no_close              (codec h264
 A..... aac                   AAC (codec aac)
";
    let map = parse_encoders(malformed);
    assert_eq!(map["h264"], vec!["good_enc"]);
    assert!(!map.contains_key("broken"));
    assert!(!map.contains_key("no_close"));
    assert!(!map.contains_key("aac"));
}
