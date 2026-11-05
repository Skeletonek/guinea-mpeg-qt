.pragma library

// Sentinel values used throughout the application
var SENTINEL_DEFAULT = "default"
var SENTINEL_NATIVE = "native"

// Rate control types
var rateControlKeys = ["crf", "vbr", "cbr"]
var rateControlLabels = ["CRF", "VBR", "CBR"]

// Audio rate control types
var audioRateControlKeys = ["cbr", "vbr", "quality"]
var audioRateControlLabels = ["CBR", "VBR", "Quality"]

// Video filter options
var deinterlaceOptions = ["none", "yadif", "bwdif", "nnedi"]
var denoiseOptions = ["none", "hqdn3d", "nlmeans", "atadenoise"]
var rotateOptions = ["0", "90", "180", "270"]

var flipKeys = ["none", "horizontal", "vertical", "both"]
var flipLabels = ["None", "Horizontal", "Vertical", "Both"]

// Audio combo options
var audioChannelOptions = ["Auto", "1", "2", "6", "8"]
var audioSampleRateOptions = ["Auto", "22050", "44100", "48000", "96000", "192000"]

// Loudnorm defaults
var loudnormDefaultI = -14
var loudnormDefaultTP = -1.5
var loudnormDefaultLRA = 11

// Normalize defaults
var normalizeDefaultI = -14
var normalizeDefaultTP = -1.5

// Video codec definitions
var codecKeys = ["h264", "hevc", "vp8", "vp9", "av1", "ffv1", "mjpeg", "mpeg2video", "mpeg4", "theora", "gif", "webp", "copy"]
var codecLabels = ["H.264", "H.265/HEVC", "VP8", "VP9", "AV1", "FFV1", "MJPEG", "MPEG-2", "MPEG-4", "Theora", "GIF", "WebP", "Copy"]

// Audio codec definitions
var audioCodecLabels = ["AAC", "Opus", "MP3", "FLAC", "Vorbis", "PCM", "Copy"]

// Resolution options
var resOptions = ["native", "360p", "480p", "720p", "1080p", "1440p", "2160p"]

// FPS options
var fpsOptions = ["source", 20, 23.976, 25, 30, 40, 45, 50, 60]

// Pixel format options
var pixfmtOptions = [
    "default", "yuv420p", "yuv422p", "yuv444p", 
    "yuv420p10le", "yuv422p10le", "yuv444p10le", "nv12"
]

// Default encoders for each codec
var defaultEncoders = {
    "h264": "libx264",
    "hevc": "libx265", 
    "vp8": "libvpx",
    "vp9": "libvpx-vp9",
    "av1": "libsvtav1",
    "ffv1": "ffv1",
    "mjpeg": "mjpeg",
    "mpeg2video": "mpeg2video",
    "mpeg4": "mpeg4",
    "theora": "libtheora",
    "gif": "gif",
    "webp": "libwebp_anim"
}

// Tune defaults for each codec
var tuneDefaults = {
    "h264": ["film", "grain", "animation", "psnr", "ssim", "fastdecode", "zerolatency"],
    "hevc": ["film", "grain", "animation", "psnr", "ssim", "fastdecode", "zerolatency"],
    "vp8": ["psnr", "ssim", "good", "best"],
    "vp9": ["psnr", "ssim", "good", "best"],
    "av1": ["psnr", "ssim", "vmaf"]
}

// Preset defaults for each codec
var presetDefaults = {
    "h264": ["ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow", "placebo"],
    "hevc": ["ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow", "placebo"],
    "vp8": ["good", "best", "realtime"],
    "vp9": ["good", "best", "realtime"],
    "av1": ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13"]
}

// VP8/VP9 CPU used options
var vp8Vp9CpuUsedOptions = ["default", "0", "1", "2", "3", "4", "5"]

// File extensions for different profiles
var profileExtensions = {
    "h264": "mp4",
    "hevc": "mp4",
    "vp8": "webm",
    "vp9": "webm", 
    "av1": "webm",
    "ffv1": "mkv",
    "mjpeg": "avi",
    "mpeg2video": "mpg",
    "mpeg4": "avi",
    "theora": "ogv",
    "gif": "gif",
    "webp": "webp"
}

// Audio file extensions (keys matched case-insensitively via toLowerCase)
var audioExtensions = {
    "flac": "flac",
    "mp3": "mp3",
    "aac": "m4a",
    "opus": "opus",
    "vorbis": "ogg",
    "pcm": "wav",
    "pcm_u8": "wav",
    "pcm_s16le": "wav",
    "pcm_s24le": "wav",
    "pcm_f32le": "wav"
}

// PCM sample formats: keys are pcm_<key> encoder name suffixes
var pcmFormatKeys = ["u8", "s16le", "s24le", "f32le"]
var pcmFormatLabels = ["8-bit integer", "16-bit integer", "24-bit integer", "32-bit float"]
var pcmFormatDefaultIndex = 1

// Output containers per video codec; "default" (sentinel) = codec-based extension
var containerKeysByCodec = {
    "h264": ["mp4", "mkv", "mov", "mpegts", "avi"],
    "hevc": ["mp4", "mkv", "mov", "mpegts", "avi"],
    "vp8": ["webm", "mkv"],
    "vp9": ["webm", "mkv"],
    "av1": ["webm", "mkv", "mp4"],
    "ffv1": ["mkv", "avi", "mov"],
    "mjpeg": ["avi", "mov", "mkv"],
    "mpeg2video": ["mpg", "mpegts", "mkv", "avi"],
    "mpeg4": ["avi", "mp4", "mkv", "mov"],
    "theora": ["ogv", "ogg", "mkv"],
    "copy": ["copy", "mp4", "mkv", "mov", "webm", "avi", "mpegts", "flac", "mp3", "m4a", "ogg", "opus", "wav"],
    "gif": ["gif"],
    "webp": ["webp"]
}

// Color constants
var colorPrimary = "#4a9eff"
var colorSecondary = "#ff6b4a"

// Timeline colors
var timelineSelectionColor = "#4a9eff"
var timelineSelectionOpacity = 0.5

// Validation constants
var crfMin = 0
var crfMax = 63

// Controls panel splitter
var controlsPanelDefaultWidth = 390
var controlsPanelMinWidth = 390
var controlsPanelMaxWidth = 640
var controlsPanelCollapseThreshold = 140
var splitterHandleWidth = 8

// Window
var windowDefaultWidth = 1024
var windowDefaultHeight = 800
var windowMinWidth = 900
var windowMinHeight = 700

// Dialog sizes
var dialogWidthSmall = 380
var dialogWidthMedium = 400
var dialogWidthLarge = 460
var dialogWidthAbout = 430
var dialogWidthTranscode = 1200
var dialogHeightTranscode = 700

// Timeline / UI colors
var timelineTrackColor = "#555555"
var timelineHandleBorder = "#ffffff"
var errorColor = "#e66"
var previewGeneratingTextSize = 14
var noVideoPlaceholderSize = 18
var audioNoteIconSize = 64