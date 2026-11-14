.pragma library

/**
 * Time formatting utility - MM:SS with fraction: frame index within the current
 * second (2 digits, 3 when fps > 100 so the counter width never changes) when
 * fps is known, milliseconds (3 digits) otherwise.
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
        digits = perSecond - 1 > 99 ? 3 : 2
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
 * Formats video color information (dynamic range, primaries, transfer) for display
 * @param {Object} stream - Video stream object with hdr, color_primaries, color_trc properties
 * @returns {string} Formatted color description (e.g. "HDR10 · BT.2020 · PQ")
 */
function formatColor(stream) {
    var names = {
        "bt709": "BT.709",
        "bt2020": "BT.2020",
        "bt2020nc": "BT.2020",
        "bt2020-10": "BT.2020",
        "smpte432": "DCI-P3",
        "smpte170m": "SMPTE 170M",
        "bt470bg": "BT.470BG",
        "smpte2084": "PQ",
        "arib-std-b67": "HLG"
    }
    var candidates = []
    if (stream.hdr && stream.hdr !== "SDR")
        candidates.push(stream.hdr)
    if (stream.color_primaries && stream.color_primaries !== "unknown")
        candidates.push(names[stream.color_primaries] || stream.color_primaries)
    if (stream.color_trc && stream.color_trc !== "unknown")
        candidates.push(names[stream.color_trc] || stream.color_trc)
    var parts = []
    for (var i = 0; i < candidates.length; i++) {
        if (parts.indexOf(candidates[i]) < 0)
            parts.push(candidates[i])
    }
    if (parts.length > 0)
        return parts.join(" · ")
    return stream.hdr ? "SDR" : "N/A"
}

function getFilename(path) {
    var idx = path.lastIndexOf("/")
    return idx >= 0 ? path.substring(idx + 1) : path
}

function getBaseFilename(filename) {
    var dot = filename.lastIndexOf(".")
    return dot >= 0 ? filename.substring(0, dot) : filename
}

function getDirectory(path) {
    var idx = path.lastIndexOf("/")
    return idx >= 0 ? path.substring(0, idx + 1) : ""
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

function formatFps(fps) {
    if (!fps) return "?"

    var decimalFps = typeof fps === "string" ? fpsToDecimal(fps) : fps
    if (decimalFps !== null) {
        return decimalFps.toFixed(2)
    }
    return String(fps)
}

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

function formatSampleRate(hz) {
    var rate = typeof hz === "string" ? parseFloat(hz) : hz;
    if (!rate || rate <= 0) return "N/A";
    return (rate / 1000).toFixed(1) + " kHz";
}

function formatChannels(channels) {
    if (!channels || channels <= 0) return "N/A";
    var layouts = {1: qsTr("mono"), 2: qsTr("stereo"), 6: qsTr("5.1"), 8: qsTr("7.1")};
    var hint = layouts[channels];
    return channels + (hint ? " (" + hint + ")" : "");
}
