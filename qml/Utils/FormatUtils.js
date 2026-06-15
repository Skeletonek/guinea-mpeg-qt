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
    return stream.language || "Stream " + (index + 1) + ": " + stream.codec
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