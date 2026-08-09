.pragma library

/**
 * Update checking utility - parses the remote update metadata and compares
 * semantic version numbers as integers.
 */

/**
 * Parses the app's own version string (e.g. "0.7.0" or "0.7.0-dev") into
 * [major, minor, patch] integers.
 * @param {string} version - Version string
 * @returns {number[]} Array of three integers
 */
function currentVersionParts(version) {
    var parts = String(version || "0.0.0").split(".")
    var out = [0, 0, 0]
    for (var i = 0; i < 3; i++) {
        var n = parseInt(parts[i], 10)
        out[i] = isNaN(n) ? 0 : n
    }
    return out
}

/**
 * Parses the remote update.toml metadata into an object with integer
 * major/minor/patch and a url string. Returns null on malformed input.
 * @param {string} text - Raw TOML content
 * @returns {Object|null} { major, minor, patch, url } or null
 */
function parseUpdateToml(text) {
    if (!text) return null
    var result = { major: 0, minor: 0, patch: 0, url: "" }
    var lines = String(text).split(/\r?\n/)
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (line === "" || line.charAt(0) === "#") continue
        var eq = line.indexOf("=")
        if (eq < 0) continue
        var key = line.substring(0, eq).trim()
        var raw = line.substring(eq + 1).trim()
        if (key === "url") {
            var m = raw.match(/^"([^"]*)"$/)
            if (m) result.url = m[1]
        } else if (key === "major" || key === "minor" || key === "patch") {
            var n = parseInt(raw, 10)
            if (!isNaN(n)) result[key] = n
        }
    }
    if (!result.url) return null
    return result
}

/**
 * Compares a remote version to the current version.
 * @param {Object} remote - { major, minor, patch } from the metadata
 * @param {number[]} current - [major, minor, patch] of the running app
 * @returns {boolean} true if remote is newer than current
 */
function isNewer(remote, current) {
    if (!remote) return false
    if (remote.major !== current[0]) return remote.major > current[0]
    if (remote.minor !== current[1]) return remote.minor > current[1]
    return remote.patch > current[2]
}
