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
    assert!(contains_pair(&args, "-vf", "scale=-2:1080,fps=30"));
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
    // software decode; the encoder uploads frames itself
    assert!(!contains_flag(&args, "-hwaccel"));
}

#[test]
fn nvenc_with_filters_needs_no_hwupload() {
    let args = args_for(r#"{"codec":"h264","encoder":"h264_nvenc","crf":18,"framerate":30.0}"#);
    let vf = &args[args.iter().position(|a| a == "-vf").unwrap() + 1];
    assert_eq!(vf, "fps=30");
    assert!(!contains_flag(&args, "-hwdownload"));
    assert!(!contains_flag(&args, "-hwupload"));
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
    // software decode; the encoder uploads frames itself
    assert!(!contains_flag(&args, "-init_hw_device"));
    assert!(!contains_flag(&args, "-hwaccel"));
}

#[test]
fn qsv_with_filters_needs_no_hwupload() {
    let args = args_for(r#"{"codec":"hevc","encoder":"hevc_qsv","crf":25,"framerate":30.0}"#);
    let vf = &args[args.iter().position(|a| a == "-vf").unwrap() + 1];
    assert_eq!(vf, "fps=30");
    assert!(!contains_flag(&args, "-hwdownload"));
    assert!(!contains_flag(&args, "-hwupload"));
}

#[test]
fn qsv_bitrate_modes_have_no_rc_flag() {
    // QSV has no -rc option: ffmpeg auto-selects CBR (minrate == maxrate == b:v)
    // or VBR (b:v alone) from the bitrate options
    let cbr =
        args_for(r#"{"codec":"hevc","encoder":"hevc_qsv","bitrate":"4M","rate_control":"cbr"}"#);
    assert!(contains_pair(&cbr, "-b:v", "4M"));
    assert!(contains_pair(&cbr, "-minrate", "4M"));
    assert!(!contains_flag(&cbr, "-rc"));
    let vbr =
        args_for(r#"{"codec":"hevc","encoder":"hevc_qsv","bitrate":"4M","rate_control":"vbr"}"#);
    assert!(contains_pair(&vbr, "-b:v", "4M"));
    assert!(!contains_flag(&vbr, "-rc"));
    assert!(!contains_flag(&vbr, "-tune"));
}

#[test]
fn amf_crf_maps_to_cqp() {
    let args = args_for(r#"{"codec":"hevc","encoder":"hevc_amf","crf":22,"preset":"balanced"}"#);
    assert!(contains_pair(&args, "-c:v", "hevc_amf"));
    assert!(contains_pair(&args, "-rc", "cqp"));
    assert!(contains_pair(&args, "-qp_i", "22"));
    assert!(contains_pair(&args, "-qp_p", "22"));
    // hevc_amf has no -qp_b option and no -tune; the preset goes via -quality
    assert!(!contains_flag(&args, "-qp_b"));
    assert!(!contains_flag(&args, "-tune"));
    assert!(contains_pair(&args, "-quality", "balanced"));
    assert!(!contains_flag(&args, "-preset"));
    assert!(!contains_pair(&args, "-quality", "22"));
    // AMF takes system-memory frames: no hwaccel, no hwupload plumbing
    assert!(!contains_flag(&args, "-hwaccel"));
}

#[test]
fn amf_with_filters_needs_no_hwdownload() {
    let args = args_for(r#"{"codec":"h264","encoder":"h264_amf","crf":22,"framerate":30.0}"#);
    let vf = &args[args.iter().position(|a| a == "-vf").unwrap() + 1];
    assert_eq!(vf, "fps=30");
    assert!(!contains_flag(&args, "-hwdownload"));
    assert!(!contains_flag(&args, "-hwupload"));
    assert!(!contains_flag(&args, "-hwaccel"));
}

#[test]
fn amf_cqp_clamps_qp_and_h264_has_qp_b() {
    let args = args_for(r#"{"codec":"h264","encoder":"h264_amf","crf":80}"#);
    assert!(contains_pair(&args, "-qp_i", "51"));
    assert!(contains_pair(&args, "-qp_b", "51"));
    assert!(!contains_pair(&args, "-qp_i", "80"));
}

#[test]
fn amf_vbr_uses_vbr_peak() {
    let args =
        args_for(r#"{"codec":"h264","encoder":"h264_amf","bitrate":"4M","rate_control":"vbr"}"#);
    assert!(contains_pair(&args, "-rc", "vbr_peak"));
    assert!(!contains_pair(&args, "-rc", "vbr"));
}

#[test]
fn amf_av1_gets_no_svtav1_params() {
    let args = args_for(r#"{"codec":"av1","encoder":"av1_amf","crf":30}"#);
    assert!(!contains_flag(&args, "-svtav1-params"));
    assert!(contains_pair(&args, "-rc", "cqp"));
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
    assert!(contains_flag(&args, "-vn"));
    assert!(contains_pair(&args, "-c:a", "aac"));
}

#[test]
fn video_disabled_never_maps_video() {
    let args = args_for(
        r#"{"codec":"h264","video_enabled":false,"video_stream_indices":[0],"audio_stream_indices":[1]}"#,
    );
    assert!(contains_pair(&args, "-map", "0:a:1"));
    assert!(!args.iter().any(|a| a.starts_with("0:v:")));
    assert!(contains_flag(&args, "-vn"));
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
fn container_selects_audio_codec() {
    let args = args_for(r#"{"codec":"av1","container":"mp4"}"#);
    assert!(contains_pair(&args, "-c:a", "aac"));
    let args = args_for(r#"{"codec":"av1","container":"webm"}"#);
    assert!(contains_pair(&args, "-c:a", "libopus"));
    let args = args_for(r#"{"codec":"h264","container":"mkv"}"#);
    assert!(contains_pair(&args, "-c:a", "aac"));
    let args = args_for(r#"{"codec":"av1","container":"ogg"}"#);
    assert!(contains_pair(&args, "-c:a", "libvorbis"));
    // Explicit audio codec wins over container.
    let args = args_for(r#"{"codec":"av1","container":"mp4","audio_codec":"opus"}"#);
    assert!(contains_pair(&args, "-c:a", "libopus"));
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
fn deinterlace_yadif_added_to_vf() {
    let args = args_for(r#"{"codec":"h264","video_filters":{"deinterlace":"yadif"}}"#);
    let vf = &args[args.iter().position(|a| a == "-vf").unwrap() + 1];
    assert!(vf.starts_with("yadif"));
}

#[test]
fn denoise_hqdn3d_added_to_vf() {
    let args = args_for(r#"{"codec":"h264","video_filters":{"denoise":"hqdn3d"}}"#);
    assert!(contains_pair(&args, "-vf", "hqdn3d"));
}

#[test]
fn crop_filter_computed_from_edges() {
    let args = args_for(
        r#"{"codec":"h264","video_filters":{"crop_top":10,"crop_bottom":20,"crop_left":4,"crop_right":8}}"#,
    );
    assert!(contains_pair(&args, "-vf", "crop=iw-4-8:ih-10-20:4:10"));
}

#[test]
fn rotate_90_adds_transpose() {
    let args = args_for(r#"{"codec":"h264","video_filters":{"rotate":90}}"#);
    assert!(contains_pair(&args, "-vf", "transpose=1"));
}

#[test]
fn flips_add_hflip_and_vflip() {
    let args = args_for(r#"{"codec":"h264","video_filters":{"hflip":true,"vflip":true}}"#);
    let vf = &args[args.iter().position(|a| a == "-vf").unwrap() + 1];
    assert!(vf.contains("hflip") && vf.contains("vflip"));
}

#[test]
fn audio_gain_adds_volume_filter() {
    let args = args_for(r#"{"codec":"h264","audio_filters":{"gain_db":6.0}}"#);
    assert!(contains_pair(&args, "-af", "volume=6dB"));
}

#[test]
fn audio_loudnorm_adds_filter_with_defaults() {
    let args = args_for(r#"{"codec":"h264","audio_filters":{"loudnorm":true}}"#);
    assert!(contains_pair(&args, "-af", "loudnorm=I=-14:TP=-1.5:LRA=11"));
}

#[test]
fn audio_opus_vbr_enables_vbr_flag() {
    let args = args_for(
        r#"{"codec":"av1","container":"webm","audio_codec":"opus","audio_filters":{"rate_control":"vbr"}}"#,
    );
    assert!(contains_pair(&args, "-c:a", "libopus"));
    assert!(contains_pair(&args, "-vbr", "on"));
    assert!(contains_pair(&args, "-b:a", "128k"));
}

#[test]
fn audio_mp3_quality_uses_qa() {
    let args = args_for(
        r#"{"codec":"h264","audio_codec":"mp3","audio_filters":{"rate_control":"quality","quality":"2"}}"#,
    );
    assert!(contains_pair(&args, "-c:a", "libmp3lame"));
    assert!(contains_pair(&args, "-q:a", "2"));
    assert!(!contains_flag(&args, "-b:a"));
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

#[test]
fn parse_gain_from_loudnorm_json() {
    let stderr = r#"
        [Parsed_loudnorm_0 @ 0x...]
        {
            "input_i" : "-23.5",
            "input_tp" : "-2.3"
        }
    "#;
    let gain = crate::ffmpeg::parse_normalize_gain(stderr, -14.0, -1.5).unwrap();
    // gain would be 9.5 dB, but clamped to avoid clipping: -1.5 - (-2.3) = 0.8 dB
    assert!((gain - 0.8).abs() < 0.01);
}

#[test]
fn parse_gain_clamps_to_avoid_clipping() {
    let stderr = r#"
        {
            "input_i" : "-30.0",
            "input_tp" : "-0.5"
        }
    "#;
    let gain = crate::ffmpeg::parse_normalize_gain(stderr, -14.0, -1.5).unwrap();
    assert!((gain - (-1.0)).abs() < 0.01);
}

#[test]
fn parse_gain_skips_stray_braces_in_stderr() {
    let stderr = r#"
        warning: metadata {not json}
        {
            "input_i" : "-23.5",
            "input_tp" : "-2.3"
        }
    "#;
    let gain = crate::ffmpeg::parse_normalize_gain(stderr, -14.0, -1.5).unwrap();
    assert!((gain - 0.8).abs() < 0.01);
}

#[test]
fn normalize_measurement_command_is_audio_only() {
    let p = profile(r#"{"codec":"h264","video_stream_indices":[0],"audio_stream_indices":[1]}"#);
    let args =
        crate::ffmpeg::build_normalize_measurement_command("in.mkv", 0.0, 10.0, &p, -14.0, -1.5);
    assert!(contains_flag(&args, "-vn"));
    assert!(contains_pair(&args, "-map", "0:a:1"));
    assert!(!args.iter().any(|a| a.starts_with("0:v:")));
}
