.pragma library

// Sentinel values used throughout the application
var SENTINEL_DEFAULT = "default"
var SENTINEL_NATIVE = "native"

// Rate control types
var rateControlKeys = ["crf", "vbr", "cbr"]
var rateControlLabels = ["CRF", "VBR", "CBR"]

// Video codec definitions
var codecKeys = ["h264", "hevc", "vp8", "vp9", "av1", "gif", "webp"]
var codecLabels = ["H.264", "H.265/HEVC", "VP8", "VP9", "AV1", "GIF", "WebP"]

// Audio codec definitions
var audioCodecLabels = ["AAC", "Opus", "MP3", "FLAC", "Vorbis"]

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
    "gif": "gif",
    "webp": "webp"
}

// Audio file extensions
var audioExtensions = {
    "FLAC": "flac",
    "MP3": "mp3",
    "AAC": "m4a",
    "Opus": "opus",
    "Vorbis": "ogg"
}

// Output containers per video codec; "default" (sentinel) = codec-based extension
var containerKeysByCodec = {
    "h264": ["mp4", "mkv", "mov", "mpegts", "avi"],
    "hevc": ["mp4", "mkv", "mov", "mpegts", "avi"],
    "vp8": ["webm", "mkv"],
    "vp9": ["webm", "mkv"],
    "av1": ["webm", "mkv", "mp4"],
    "gif": ["gif"],
    "webp": ["webp"]
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

// Validation constants
var crfMin = 0
var crfMax = 63

// Controls panel splitter
var controlsPanelDefaultWidth = 300
var controlsPanelMinWidth = 300
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
var dialogWidthCompat = 360
var dialogWidthTranscode = 700
var dialogHeightTranscode = 500

// Timeline / UI colors
var timelineTrackColor = "#555555"
var timelineHandleBorder = "#ffffff"
var errorColor = "#e66"
var previewGeneratingTextSize = 14
var noVideoPlaceholderSize = 18