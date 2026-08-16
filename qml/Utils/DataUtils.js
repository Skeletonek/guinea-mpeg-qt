.pragma library

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
 * Gets text from combo box, returning null if empty or matches sentinel
 * @param {ComboBox} combo - The ComboBox instance
 * @param {string} sentinel - The sentinel value to check against
 * @returns {string|null} The text value or null
 */
function comboText(combo, sentinel) {
    return (combo.currentText && combo.currentText !== sentinel) ? combo.currentText : null
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
