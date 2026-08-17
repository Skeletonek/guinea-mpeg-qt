use crate::config::VideoProfile;
use crate::ffmpeg::{build_command, build_preview};

fn profile(json: &str) -> VideoProfile {
    serde_json::from_str(json).unwrap()
}

fn args_for(json: &str) -> Vec<String> {
    build_command("input.mp4", "output.mp4", 0.0, 0.0, &profile(json))
}

fn contains_pair(args: &[String], flag: &str, value: &str) -> bool {
    args.windows(2).any(|w| w[0] == flag && w[1] == value)
}

fn contains_flag(args: &[String], flag: &str) -> bool {
    args.iter().any(|a| a == flag)
}

#[test]
fn software_h264_full_params() {
    let args = args_for(
        r#"{
            "codec":"h264",
            "encoder":"libx264",
            "crf":18,
            "preset":"slow",
            "tune":"film",
            "pixel_format":"yuv420p",
            "resolution":"1080p",
            "framerate":30.0,
            "extra_args":["-x264-params","keyint=250"]
        }"#,
    );
    assert!(contains_flag(&args, "-i"));
    assert!(contains_pair(&args, "-c:v", "libx264"));
    assert!(contains_pair(&args, "-crf", "18"));
    assert!(contains_pair(&args, "-preset", "slow"));
    assert!(contains_pair(&args, "-tune", "film"));
    assert!(contains_pair(&args, "-pix_fmt", "yuv420p"));
    assert!(contains_pair(&args, "-vf", "fps=30,scale=-2:1080"));
    assert!(contains_pair(&args, "-x264-params", "keyint=250"));
    assert_eq!(args.last().unwrap(), "output.mp4");
}

#[test]
fn missing_codec_falls_back_to_software_default() {
    // A profile without a usable codec falls back to the software default (libx264).
    let args = args_for(r#"{"codec":"","crf":18}"#);
    assert!(contains_pair(&args, "-c:v", "libx264"));
    assert!(contains_pair(&args, "-crf", "18"));
}

#[test]
fn unknown_codec_falls_back_to_libx264() {
    let args = args_for(r#"{"codec":"bogus","crf":18}"#);
    assert!(contains_pair(&args, "-c:v", "libx264"));
    assert!(contains_pair(&args, "-crf", "18"));
}

#[test]
fn unknown_encoder_passthrough_with_software_semantics() {
    // Unknown encoder names are emitted verbatim; classification defaults to
    // software, so preset/tune are kept and no hwaccel flags are added.
    let args = args_for(
        r#"{"codec":"h264","encoder":"bogus_enc","crf":18,"preset":"fast","tune":"film"}"#,
    );
    assert!(contains_pair(&args, "-c:v", "bogus_enc"));
    assert!(contains_pair(&args, "-preset", "fast"));
    assert!(contains_pair(&args, "-tune", "film"));
    assert!(!contains_flag(&args, "-hwaccel"));
}

#[test]
fn crf_with_bitrate_emits_both() {
    let args = args_for(r#"{"codec":"h264","encoder":"libx264","crf":20,"bitrate":"2M"}"#);
    assert!(contains_pair(&args, "-crf", "20"));
    assert!(contains_pair(&args, "-b:v", "2M"));
}

#[test]
fn vbr_emits_bitrate_only() {
    let args =
        args_for(r#"{"codec":"h264","encoder":"libx264","bitrate":"2M","rate_control":"vbr"}"#);
    assert!(contains_pair(&args, "-b:v", "2M"));
    assert!(!contains_flag(&args, "-crf"));
    assert!(!contains_flag(&args, "-minrate"));
}

#[test]
fn cbr_emits_minrate_maxrate_bufsize() {
    let args =
        args_for(r#"{"codec":"h264","encoder":"libx264","bitrate":"2M","rate_control":"cbr"}"#);
    assert!(contains_pair(&args, "-b:v", "2M"));
    assert!(contains_pair(&args, "-minrate", "2M"));
    assert!(contains_pair(&args, "-maxrate", "2M"));
    assert!(contains_pair(&args, "-bufsize", "2M"));
}

#[test]
fn vp9_deadline_and_cpu_used() {
    let args = args_for(
        r#"{"codec":"vp9","encoder":"libvpx-vp9","crf":40,"preset":"good","cpu_used":3,"tune":"ssim"}"#,
    );
    assert!(contains_pair(&args, "-deadline", "good"));
    assert!(contains_pair(&args, "-cpu-used", "3"));
    assert!(contains_pair(&args, "-tune", "ssim"));
    assert!(!contains_flag(&args, "-preset"));
}

#[test]
fn vp9_invalid_tune_dropped() {
    let args = args_for(r#"{"codec":"vp9","encoder":"libvpx-vp9","crf":40,"tune":"film"}"#);
    assert!(!contains_flag(&args, "-tune"));
}

#[test]
fn av1_svtav1_params() {
    let args = args_for(
        r#"{
            "codec":"av1","encoder":"libsvtav1","crf":35,"preset":"6","tune":"vmaf",
            "tile_rows":1,"tile_columns":2,"enable_qm":true
        }"#,
    );
    let idx = args.iter().position(|a| a == "-svtav1-params").unwrap();
    assert_eq!(
        args[idx + 1],
        "preset=6:enable-qm=1:tune=2:crf=35:tile-rows=1:tile-columns=2"
    );
}

#[test]
fn nvenc_uses_cq() {
    let args = args_for(r#"{"codec":"h264","encoder":"h264_nvenc","crf":18}"#);
    assert!(contains_pair(&args, "-c:v", "h264_nvenc"));
    assert!(contains_pair(&args, "-cq", "18"));
    assert!(!contains_flag(&args, "-crf"));
    assert!(contains_pair(&args, "-hwaccel", "cuda"));
}

#[test]
fn nvenc_cbr_uses_lowercase_rc() {
    let args =
        args_for(r#"{"codec":"h264","encoder":"h264_nvenc","bitrate":"4M","rate_control":"cbr"}"#);
    assert!(contains_pair(&args, "-rc", "cbr"));
    assert!(!contains_flag(&args, "-cq"));
}

#[test]
fn vaapi_uses_rc_mode_compression_and_hwaccel() {
    let args = args_for(
        r#"{"codec":"h264","encoder":"h264_vaapi","bitrate":"3M","rate_control":"cbr","compression_level":"medium","preset":"slow"}"#,
    );
    assert!(contains_pair(&args, "-c:v", "h264_vaapi"));
    assert!(contains_pair(&args, "-rc_mode", "CBR"));
    assert!(contains_pair(&args, "-compression_level", "medium"));
    assert!(contains_pair(&args, "-hwaccel", "vaapi"));
    assert!(!contains_flag(&args, "-preset"));
    assert!(!contains_flag(&args, "-tune"));
}

#[test]
fn vaapi_crf_uses_qp() {
    let args = args_for(r#"{"codec":"h264","encoder":"h264_vaapi","crf":22}"#);
    assert!(contains_pair(&args, "-qp", "22"));
}

#[test]
fn qsv_uses_global_quality() {
    let args = args_for(r#"{"codec":"hevc","encoder":"hevc_qsv","crf":25}"#);
    assert!(contains_pair(&args, "-global_quality", "25"));
    assert!(contains_flag(&args, "-init_hw_device"));
}

#[test]
fn trim_sets_ss_and_t() {
    let args = build_command(
        "in.mp4",
        "out.mp4",
        10.0,
        16.0,
        &profile(r#"{"codec":"h264"}"#),
    );
    let ss_idx = args.iter().position(|a| a == "-ss").unwrap();
    let i_idx = args.iter().position(|a| a == "-i").unwrap();
    assert_eq!(ss_idx + 2, i_idx);
    assert_eq!(args[ss_idx + 1], "10");
    assert_eq!(args[i_idx + 1], "in.mp4");
    let t_idx = args.iter().position(|a| a == "-t").unwrap();
    assert!(t_idx > i_idx);
    assert_eq!(args[t_idx + 1], "6.000");
}

#[test]
fn no_trim_when_zero_start_or_equal_times() {
    let args = args_for(r#"{"codec":"h264"}"#);
    assert!(!contains_flag(&args, "-ss"));
    assert!(!contains_flag(&args, "-t"));
    let args = build_command(
        "in.mp4",
        "out.mp4",
        10.0,
        10.0,
        &profile(r#"{"codec":"h264"}"#),
    );
    assert!(!contains_flag(&args, "-t"));
}

#[test]
fn explicit_stream_mapping() {
    let args =
        args_for(r#"{"codec":"h264","video_stream_indices":[0,2],"audio_stream_indices":[1]}"#);
    assert!(contains_pair(&args, "-map", "0:v:0"));
    assert!(contains_pair(&args, "-map", "0:v:2"));
    assert!(contains_pair(&args, "-map", "0:a:1"));
}

#[test]
fn no_explicit_stream_indices_no_map() {
    // Without explicit indices no -map is emitted; ffmpeg picks best streams.
    let args = args_for(r#"{"codec":"h264"}"#);
    assert!(!contains_flag(&args, "-map"));
}

#[test]
fn audio_disabled_adds_an() {
    let args = args_for(r#"{"codec":"h264","audio_enabled":false}"#);
    assert!(contains_flag(&args, "-an"));
    assert!(!contains_flag(&args, "-c:a"));
}

#[test]
fn video_disabled_skips_video_args() {
    let args = args_for(r#"{"codec":"h264","video_enabled":false,"audio_enabled":true}"#);
    assert!(!contains_flag(&args, "-c:v"));
    assert!(contains_pair(&args, "-c:a", "aac"));
}

#[test]
fn audio_codec_defaults() {
    let args = args_for(r#"{"codec":"h264"}"#);
    assert!(contains_pair(&args, "-c:a", "aac"));
    let args = args_for(r#"{"codec":"av1"}"#);
    assert!(contains_pair(&args, "-c:a", "libopus"));
}

#[test]
fn audio_codec_explicit() {
    let args = args_for(r#"{"codec":"h264","audio_codec":"mp3"}"#);
    assert!(contains_pair(&args, "-c:a", "libmp3lame"));
}

#[test]
fn audio_parameters() {
    let args = args_for(
        r#"{"codec":"h264","audio_bitrate":"192k","audio_channels":1,"audio_sample_rate":44100}"#,
    );
    assert!(contains_pair(&args, "-b:a", "192k"));
    assert!(contains_pair(&args, "-ac", "1"));
    assert!(contains_pair(&args, "-ar", "44100"));
}

#[test]
fn native_resolution_no_scale() {
    let args = args_for(r#"{"codec":"h264","resolution":"native","framerate":30.0}"#);
    assert!(contains_pair(&args, "-vf", "fps=30"));
    assert!(!args.iter().any(|a| a.contains("scale")));
}

#[test]
fn zero_framerate_no_fps() {
    let args = args_for(r#"{"codec":"h264","resolution":"720p","framerate":0.0}"#);
    assert!(contains_pair(&args, "-vf", "scale=-2:720"));
    assert!(!args.iter().any(|a| a.starts_with("fps=")));
}

#[test]
fn gif_palette_and_loop() {
    let args = args_for(
        r#"{"codec":"gif","encoder":"gif","quality":75,"loop_enabled":true,"audio_enabled":false,"framerate":10.0,"resolution":"480p"}"#,
    );
    assert!(contains_pair(&args, "-c:v", "gif"));
    let vf = args.iter().find(|a| a.contains("split[s0][s1]")).unwrap();
    assert!(vf.contains("palettegen=max_colors=192"));
    assert!(contains_pair(&args, "-loop", "0"));
    assert!(contains_flag(&args, "-an"));
    assert!(!contains_flag(&args, "-quality"));
}

#[test]
fn webp_quality_and_loop() {
    let args = args_for(
        r#"{"codec":"webp","encoder":"libwebp_anim","quality":50,"loop_enabled":false,"audio_enabled":false}"#,
    );
    assert!(contains_pair(&args, "-quality", "50"));
    assert!(contains_pair(&args, "-loop", "1"));
    assert!(contains_flag(&args, "-an"));
}

#[test]
fn preview_uses_placeholders() {
    let args = build_preview(&profile(r#"{"codec":"h264","crf":18}"#));
    assert!(args.contains(&"[input]".to_string()));
    assert_eq!(args.last().unwrap(), "[output]");
    assert!(contains_pair(&args, "-crf", "18"));
}

#[test]
fn custom_command_overrides_generated_args() {
    let args = args_for(
        r#"{"codec":"h264","crf":18,"custom_command":"-c:v libx264 -crf 23 -preset fast -y {output}"}"#,
    );
    assert!(contains_pair(&args, "-c:v", "libx264"));
    assert!(contains_pair(&args, "-crf", "23"));
    assert!(contains_pair(&args, "-preset", "fast"));
    assert_eq!(args.last().unwrap(), "output.mp4");
    assert!(!contains_flag(&args, "-map"));
}

#[test]
fn custom_command_substitutes_placeholders() {
    let args = build_command(
        "in.mp4",
        "out.mkv",
        0.0,
        0.0,
        &profile(r#"{"codec":"h264","custom_command":"-i {input} -c:v libx264 -y {output}"}"#),
    );
    assert_eq!(args[0], "-i");
    assert_eq!(args[1], "in.mp4");
    assert!(args.contains(&"out.mkv".to_string()));
}

#[test]
fn custom_command_strips_leading_ffmpeg() {
    let args = args_for(r#"{"codec":"h264","custom_command":"ffmpeg -c:v libx264"}"#);
    assert!(contains_pair(&args, "-c:v", "libx264"));
    assert!(!args.contains(&"ffmpeg".to_string()));
}

#[test]
fn custom_command_respects_quotes() {
    let args = args_for(
        r#"{"codec":"h264","custom_command":"-vf \"scale=-2:720,setpts=PTS/2\" -c:v libx264"}"#,
    );
    assert!(contains_pair(&args, "-vf", "scale=-2:720,setpts=PTS/2"));
}

#[test]
fn custom_command_drops_trim_when_no_trim() {
    let args = args_for(
        r#"{"codec":"h264","custom_command":"-i {input} -ss {start} -t {duration} -y {output}"}"#,
    );
    assert!(!contains_flag(&args, "-ss"));
    assert!(!contains_flag(&args, "-t"));
    assert_eq!(args[1], "input.mp4");
    assert_eq!(args.last().unwrap(), "output.mp4");
}

#[test]
fn custom_command_keeps_trim_when_trimmed() {
    let args = build_command(
        "in.mp4",
        "out.mp4",
        10.0,
        16.0,
        &profile(
            r#"{"codec":"h264","custom_command":"-i {input} -ss {start} -t {duration} -y {output}"}"#,
        ),
    );
    assert!(contains_pair(&args, "-ss", "10"));
    assert!(contains_pair(&args, "-t", "6.000"));
}

#[test]
fn custom_command_empty_falls_back_to_generated() {
    let args = args_for(r#"{"codec":"h264","crf":18,"custom_command":""}"#);
    assert!(contains_pair(&args, "-crf", "18"));
    assert!(contains_flag(&args, "-i"));
}

#[test]
fn custom_command_preview_uses_placeholders() {
    let args = build_preview(&profile(
        r#"{"codec":"h264","custom_command":"-i {input} -c:v libx264 -y {output}"}"#,
    ));
    assert!(args.contains(&"[input]".to_string()));
    assert_eq!(args.last().unwrap(), "[output]");
    assert!(contains_pair(&args, "-c:v", "libx264"));
}

#[test]
fn tokenize_handles_quotes_and_escapes() {
    assert_eq!(crate::ffmpeg::tokenize("a b c"), vec!["a", "b", "c"]);
    assert_eq!(crate::ffmpeg::tokenize("'a b' c"), vec!["a b", "c"]);
    assert_eq!(crate::ffmpeg::tokenize("\"a b\" c"), vec!["a b", "c"]);
    assert_eq!(crate::ffmpeg::tokenize("a\\ b c"), vec!["a b", "c"]);
    assert_eq!(crate::ffmpeg::tokenize("a \"x\\\"y\""), vec!["a", "x\"y"]);
    assert_eq!(crate::ffmpeg::tokenize("'unbalanced"), vec!["unbalanced"]);
}
