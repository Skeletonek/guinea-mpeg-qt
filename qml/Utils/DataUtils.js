.pragma library
.import "Constants.js" as Constants

/**
 * Data handling utilities for GuineaMPEG
 * Contains functions for data transformation, validation, and manipulation
 */

/**
 * Converts a file:// URL to a local filesystem path.
 * Strips the file:// prefix and percent-encoding; on Windows also removes the
 * leading slash before the drive letter (file:///C:/... -> C:/...), which
 * C++/Rust path APIs reject.
 * @param {string} url - The file:// URL
 * @returns {string} Local filesystem path
 */
function toLocalPath(url) {
    var p = String(url)
    if (p.startsWith("file://"))
        p = p.substring(7)
    try {
        p = decodeURIComponent(p)
    } catch (e) {}
    if (Qt.platform.os === "windows" && p.length >= 3 && p.charAt(0) === "/" && p.charAt(2) === ":")
        p = p.substring(1)
    return p
}

/**
 * Converts a local filesystem path to a proper file:// URL.
 * Windows drive paths (C:/...) need the file:/// form: "file://" + path
 * makes QUrl parse the drive letter as a hostname, breaking toLocalFile().
 * @param {string} path - Local filesystem path or file:// URL
 * @returns {string} file:// URL
 */
function toFileUrl(path) {
    var p = String(path)
    if (p.startsWith("file://"))
        return p
    if (Qt.platform.os === "windows")
        p = p.replace(/\\/g, "/")
    return "file://" + (p.startsWith("/") ? "" : "/") + encodeURI(p)
}

/**
 * Gets the effective text of an (editable) combo box.
 * For editable combos the edited text wins when it differs from the selected
 * item's text: this is the case for typed/custom values and for values that
 * were applied via the setComboText editText fallback (currentIndex/currentText
 * still point at the previously selected item until the model is rebuilt).
 * @param {ComboBox} combo - The ComboBox instance
 * @returns {string} The effective text
 */
function comboValue(combo) {
    var current = combo.currentText
    if (combo.editable && combo.editText && combo.editText !== current)
        return combo.editText
    return current
}

/**
 * Gets text from combo box, returning null if empty or matches sentinel
 * @param {ComboBox} combo - The ComboBox instance
 * @param {string} sentinel - The sentinel value to check against
 * @returns {string|null} The text value or null
 */
function comboText(combo, sentinel) {
    var text = comboValue(combo)
    return (text && text !== sentinel) ? text : null
}

/**
 * Sets text on combo box, handling both model items and custom values
 * @param {ComboBox} combo - The ComboBox instance
 * @param {string} value - The value to set
 * @param {string} sentinel - The sentinel value for default
 */
function setComboText(combo, value, sentinel) {
    if (value == null || value === sentinel || value === "") {
        combo.currentIndex = 0
        return
    }
    
    if (typeof combo.textAt === "function") {
        for (var i = 0; i < combo.count; i++) {
            if (combo.textAt(i) === value) {
                combo.currentIndex = i
                return
            }
        }
    }
    combo.editText = value
}

/**
 * Sets the combo box index based on key value
 * @param {Array} keys - Array of key values
 * @param {ComboBox} combo - The ComboBox instance
 * @param {string} value - The value to find and select
 */
function setIndex(keys, combo, value) {
    var idx = keys.indexOf(value)
    combo.currentIndex = idx >= 0 ? idx : 0
}

/**
 * Toggles selection in an array
 * @param {number} index - The index to toggle
 * @param {boolean} checked - Whether to add or remove
 * @param {Array} selection - The current selection array
 * @returns {Array} New array with toggled selection
 */
function toggleSelection(index, checked, selection) {
    var arr = selection.slice()
    var pos = arr.indexOf(index)
    if (checked && pos < 0) arr.push(index)
    else if (!checked && pos >= 0) arr.splice(pos, 1)
    return arr
}

/**
 * Builds profile data from panel data objects
 * @param {...Object} panelData - Data objects from video, audio, and advanced panels
 * @returns {Object} Combined profile data
 */
function buildProfileData() {
    var data = {}
    for (var i = 0; i < arguments.length; i++) {
        var panelData = arguments[i]
        for (var k in panelData) {
            data[k] = panelData[k]
        }
    }
    return data
}

/**
 * Rebuilds an editable ComboBox model preserving the previous selection.
 * DRY helper for encoder capability rebuilds (presets/tunes/pix_fmts).
 * @param {ComboBox} combo - ComboBox to update
 * @param {Array} items - Source items (already sliced if needed)
 * @param {string} sentinel - Sentinel value to prepend if missing (e.g. "default")
 */
function rebuildComboModel(combo, items, sentinel) {
    var list = items.slice()
    if (sentinel && list.indexOf(sentinel) < 0)
        list.unshift(sentinel)
    var prev = comboValue(combo)
    combo.model = list
    var idx = list.indexOf(prev)
    combo.currentIndex = idx >= 0 ? idx : 0
}

/**
 * Determines the output file extension for a profile data object
 * @param {Object} d - Profile data object
 * @param {string} inputPath - Optional source path for container="copy" or codec="copy"
 * @returns {string} File extension without the leading dot
 */
function getExtensionForProfile(d, inputPath) {
    function extFromPath(p) {
        if (!p) return ""
        var slash = p.lastIndexOf("/")
        var name = slash >= 0 ? p.substring(slash + 1) : p
        var dot = name.lastIndexOf(".")
        if (dot >= 0 && dot < name.length - 1)
            return name.substring(dot + 1).toLowerCase()
        return ""
    }
    if (!d)
        return "webm"
    if (d.container) {
        if (d.container === "copy") {
            var e = extFromPath(inputPath)
            if (e) return e
            // fallback: codec mapping or generic
            if (d.video_enabled !== false)
                return Constants.profileExtensions[d.codec] || "mkv"
            return Constants.audioExtensions[d.audio_codec] || "mkv"
        }
        return d.container
    }
    if (d.video_enabled !== false) {
        if (d.codec === "copy") {
            var ce = extFromPath(inputPath)
            if (ce) return ce
        }
        return Constants.profileExtensions[d.codec] || "webm"
    }
    if (d.audio_codec && d.audio_codec.toLowerCase() === "copy") {
        var ae = extFromPath(inputPath)
        if (ae) return ae
    }
    return Constants.audioExtensions[d.audio_codec] || "ogg"
}

/**
 * Builds an editable advanced-mode command template from a preview argument
 * array (which uses [input]/[output] placeholders). Arguments containing
 * whitespace or quotes are shell-quoted so they round-trip through the
 * tokenizer, and -ss {start} -t {duration} are injected right after the input.
 * @param {Array} args - The preview argument array
 * @returns {string} Full ffmpeg command line with {input}/{output}/{start}/{duration}
 */
function advancedTemplateFromArgs(args) {
    if (!args)
        return ""
    var parts = []
    for (var i = 0; i < args.length; i++) {
        var a = String(args[i])
        if (a.indexOf(" ") >= 0 || a.indexOf("\"") >= 0)
            a = "\"" + a.replace(/\"/g, "\\\"") + "\""
        parts.push(a)
    }
    for (var i = 0; i < parts.length; i++) {
        if (parts[i] === "-i") {
            parts.splice(i + 2, 0, "-ss", "{start}", "-t", "{duration}")
            break
        }
    }
    return "ffmpeg " + parts.join(" ").replace(/\[input\]/g, "{input}").replace(/\[output\]/g, "{output}")
}

/**
 * Parses ffmpeg's `frame=` status lines from stderr text and converts the last
 * frame count to progress (0..1). Used by both transcode and preview progress.
 * @param {string} text - ffmpeg stderr text to scan
 * @param {number} totalFrames - expected total frame count (0 = unknown)
 * @returns {number} Progress 0..1, or -1 when no frame count was found
 */
function parseFrameProgress(text, totalFrames) {
    var re = /frame=\s*(\d+)/g
    var match, last
    while ((match = re.exec(text)) !== null)
        last = match
    if (!last || totalFrames <= 0)
        return -1
    return Math.min(parseInt(last[1]) / totalFrames, 1)
}
