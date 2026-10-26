use crate::config::VideoProfile;
use crate::ffmpeg::software_video_codec;

pub(crate) fn video_codec(profile: &VideoProfile) -> String {
    if profile.codec.to_lowercase() == "copy" {
        return "copy".to_string();
    }
    profile
        .encoder
        .clone()
        .unwrap_or_else(|| software_video_codec(&profile.codec).to_string())
}

pub(crate) fn audio_codec_for_profile(profile: &VideoProfile) -> &str {
    if let Some(ref ac) = profile.audio_codec {
        match ac.to_lowercase().as_str() {
            "copy" => "copy",
            "aac" => "aac",
            "opus" => "libopus",
            "mp3" => "libmp3lame",
            "flac" => "flac",
            "vorbis" => "libvorbis",
            "pcm" | "wav" => "pcm_s16le",
            other if other.starts_with("pcm_") => ac,
            _ => "aac",
        }
    } else {
        match profile.container.as_deref() {
            Some("mp4") | Some("mov") | Some("m4a") => "aac",
            Some("webm") | Some("opus") => "libopus",
            Some("ogg") | Some("ogv") => "libvorbis",
            Some("mp3") => "libmp3lame",
            Some("flac") => "flac",
            Some("wav") | Some("wave") => "pcm_s16le",
            Some("avi") | Some("mpg") | Some("mpeg") => "libmp3lame",
            _ => match profile.codec.as_str() {
                "h264" | "hevc" => "aac",
                "mjpeg" | "mpeg2video" | "mpeg4" => "libmp3lame",
                "theora" => "libvorbis",
                "ffv1" => "flac",
                _ => "libopus",
            },
        }
    }
}
