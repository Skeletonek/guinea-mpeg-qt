use crate::config::VideoProfile;
use crate::ffmpeg::software_video_codec;

pub(crate) fn video_codec(profile: &VideoProfile) -> String {
    profile
        .encoder
        .clone()
        .unwrap_or_else(|| software_video_codec(&profile.codec).to_string())
}

pub(crate) fn audio_codec_for_profile(profile: &VideoProfile) -> &str {
    if let Some(ref ac) = profile.audio_codec {
        match ac.to_lowercase().as_str() {
            "aac" => "aac",
            "opus" => "libopus",
            "mp3" => "libmp3lame",
            "flac" => "flac",
            "vorbis" => "libvorbis",
            _ => "aac",
        }
    } else {
        match profile.codec.as_str() {
            "h264" | "hevc" => "aac",
            _ => "libopus",
        }
    }
}
