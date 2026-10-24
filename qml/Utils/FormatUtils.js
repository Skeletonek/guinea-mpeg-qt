.pragma library

/**
 * Time formatting utility - converts milliseconds to MM:SS format
 * @param {number} ms - Time in milliseconds
 * @returns {string} Formatted time string (MM:SS)
 */
function formatTime(ms) {
    var s = Math.floor(ms / 1000)
    var m = Math.floor(s / 60)
    s = s % 60
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
}

/**
 * Time formatting utility - MM:SS with fraction: frame index within the current
 * second (2 digits) when fps is known, milliseconds (3 digits) otherwise.
 * @param {number} ms - Time in milliseconds
 * @param {number} [fps] - Frames per second; 0/null falls back to milliseconds
 * @returns {string} Formatted time string (MM:SS.ff with fps, MM:SS.fff without)
 */
function formatTimePrecise(ms, fps) {
    var t = Math.max(0, ms)
    var frac = 0
    var digits = 3
    if (fps > 0) {
        var perSecond = Math.ceil(fps)
        frac = Math.min(perSecond - 1, Math.floor((t % 1000) * fps / 1000))
        digits = 2
    } else {
        frac = t % 1000
    }
    var s = Math.floor(t / 1000)
    var m = Math.floor(s / 60)
    s = s % 60
    var text = String(frac)
    while (text.length < digits)
        text = "0" + text
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s + "." + text
}

/**
 * Formats stream information for display
 * @param {Object} stream - Stream object with codec, width, height, fps, language properties
 * @param {number} index - Stream index
 * @param {string} type - Stream type ('video' or 'audio')
 * @returns {string} Formatted stream description
 */
function streamText(stream, index, type) {
    if (type === "video") {
        var fps = ""
        if (stream.fps) {
            var parts = String(stream.fps).split("/")
            fps = parts.length === 2
                ? (parseInt(parts[0]) / parseInt(parts[1])).toFixed(1)
                : stream.fps
        }
        return stream.width + "x" + stream.height + " " + stream.codec + " " + fps + "fps"
    }
    return stream.title || stream.language || "Stream " + (index + 1) + ": " + stream.codec
}

/**
 * Extracts filename from path
 * @param {string} path - Full file path
 * @returns {string} Filename without directory
 */
function getFilename(path) {
    var idx = path.lastIndexOf("/")
    return idx >= 0 ? path.substring(idx + 1) : path
}

/**
 * Extracts base filename without extension
 * @param {string} filename - Filename with extension
 * @returns {string} Base filename without extension
 */
function getBaseFilename(filename) {
    var dot = filename.lastIndexOf(".")
    return dot >= 0 ? filename.substring(0, dot) : filename
}

/**
 * Extracts directory from path
 * @param {string} path - Full file path
 * @returns {string} Directory path with trailing slash
 */
function getDirectory(path) {
    var idx = path.lastIndexOf("/")
    return idx >= 0 ? path.substring(0, idx + 1) : ""
}

/**
 * Safely parses JSON with fallback
 * @param {string} jsonString - JSON string to parse
 * @param {Object} fallback - Fallback object if parsing fails
 * @returns {Object} Parsed object or fallback
 */
function safeJsonParse(jsonString, fallback) {
    try {
        return JSON.parse(jsonString)
    } catch (e) {
        return fallback || {}
    }
}

/**
 * Converts FPS string to decimal number
 * @param {string} fpsString - FPS as string (e.g., "30/1", "24000/1001")
 * @returns {number|null} FPS as decimal number or null if invalid
 */
function fpsToDecimal(fpsString) {
    if (!fpsString) return null
    
    var parts = String(fpsString).split("/")
    if (parts.length === 2) {
        var numerator = parseFloat(parts[0])
        var denominator = parseFloat(parts[1])
        if (denominator !== 0) {
            return numerator / denominator
        }
    }
    return null
}

/**
 * Formats FPS for display
 * @param {string|number} fps - FPS value
 * @returns {string} Formatted FPS string
 */
function formatFps(fps) {
    if (!fps) return "?"
    
    var decimalFps = typeof fps === "string" ? fpsToDecimal(fps) : fps
    if (decimalFps !== null) {
        return decimalFps.toFixed(2)
    }
    return String(fps)
}

/**
 * Formats a byte count into a human-readable size (binary units)
 * @param {number} bytes - Size in bytes
 * @returns {string} Formatted size string (e.g. "12.3 MB")
 */
function formatSize(bytes) {
    if (!bytes || bytes <= 0) return "0 B";
    var units = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    var n = bytes;
    while (n >= 1024 && i < units.length - 1) {
        n /= 1024;
        i++;
    }
    return (i === 0 ? Math.round(n).toString() : n.toFixed(1)) + " " + units[i];
}

/**
 * Formats a bit rate into a human-readable string (decimal units)
 * @param {number} bps - Bit rate in bits per second (0 or negative → "N/A")
 * @returns {string} Formatted bit rate string (e.g. "4.5 Mbps")
 */
function formatBitrate(bps) {
    if (!bps || bps <= 0) return "N/A";
    var units = ["bps", "kbps", "Mbps", "Gbps"];
    var i = 0;
    var n = bps;
    while (n >= 1000 && i < units.length - 1) {
        n /= 1000;
        i++;
    }
    return (i === 0 ? Math.round(n).toString() : n.toFixed(1)) + " " + units[i];
}

/**
 * Formats an audio sample rate in Hz (0 or negative → "N/A")
 * @param {number|string} hz - Sample rate in Hz (e.g. 48000, "48000")
 * @returns {string} Formatted sample rate string (e.g. "48.0 kHz")
 */
function formatSampleRate(hz) {
    var rate = typeof hz === "string" ? parseFloat(hz) : hz;
    if (!rate || rate <= 0) return "N/A";
    return (rate / 1000).toFixed(1) + " kHz";
}

/**
 * Formats an audio channel count with a common layout hint
 * @param {number} channels - Channel count
 * @returns {string} Formatted channel string (e.g. "2 (stereo)")
 */
function formatChannels(channels) {
    if (!channels || channels <= 0) return "N/A";
    var layouts = {1: qsTr("mono"), 2: qsTr("stereo"), 6: qsTr("5.1"), 8: qsTr("7.1")};
    var hint = layouts[channels];
    return channels + (hint ? " (" + hint + ")" : "");
}