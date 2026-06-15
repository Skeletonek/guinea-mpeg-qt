.pragma library

// Sentinel values used throughout the application
var SENTINEL_DEFAULT = "default"
var SENTINEL_NATIVE = "native"
var SENTINEL_SOURCE = "source"

// Rate control types
var rateControlKeys = ["crf", "vbr", "cbr"]
var rateControlLabels = ["CRF", "VBR", "CBR"]

// Video codec definitions
var codecKeys = ["h264", "hevc", "vp8", "vp9", "av1"]
var codecLabels = ["H.264", "H.265/HEVC", "VP8", "VP9", "AV1"]

// Audio codec definitions
var audioCodecLabels = ["AAC", "Opus", "MP3", "FLAC", "Vorbis"]
var audioCodecKeys = ["aac", "opus", "mp3", "flac", "vorbis"]

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
    "av1": "libsvtav1"
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
    "av1": "webm"
}

// Audio file extensions
var audioExtensions = {
    "FLAC": "flac",
    "MP3": "mp3",
    "AAC": "m4a",
    "Opus": "opus",
    "Vorbis": "ogg"
}

// Color constants
var colorPrimary = "#4a9eff"
var colorSecondary = "#ff6b4a"
var colorWarning = "#ff9800"
var colorError = "#f44336"
var colorInfo = "#2196f3"

// Timeline colors
var timelineSelectionColor = "#4a9eff"
var timelineSelectionOpacity = 0.5
var timelineStartHandleColor = "#4a9eff"
var timelineEndHandleColor = "#ff6b4a"

// Validation constants
var crfMin = 0
var crfMax = 63
var audioChannelsMin = 0
var audioChannelsMax = 8
var audioSampleRateMin = 0
var audioSampleRateMax = 192000