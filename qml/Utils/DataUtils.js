.pragma library

/**
 * Data handling utilities for GuineaMPEG
 * Contains functions for data transformation, validation, and manipulation
 */

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
 * Gets the key value from an index-based array
 * @param {Array} keys - Array of key values
 * @param {ComboBox} combo - The ComboBox instance
 * @returns {string} The key at the current index
 */
function indexValue(keys, combo) {
    return keys[combo.currentIndex]
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
 * Safely gets nested property with default fallback
 * @param {Object} obj - The object to query
 * @param {string} path - Dot-separated property path
 * @param {*} defaultValue - Default value if property doesn't exist
 * @returns {*} The property value or default
 */
function getNestedProperty(obj, path, defaultValue) {
    if (!obj || !path) return defaultValue
    
    var parts = path.split(".")
    var current = obj
    
    for (var i = 0; i < parts.length; i++) {
        if (current == null) return defaultValue
        current = current[parts[i]]
    }
    
    return current !== undefined ? current : defaultValue
}

/**
 * Checks if value is null, undefined, or empty string
 * @param {*} value - The value to check
 * @returns {boolean} True if value is empty
 */
function isEmpty(value) {
    return value == null || value === ""
}

/**
 * Converts value to integer if possible, otherwise returns null
 * @param {*} value - The value to convert
 * @returns {number|null} Integer value or null
 */
function toIntOrNull(value) {
    if (isEmpty(value)) return null
    var num = parseInt(value)
    return isNaN(num) ? null : num
}

/**
 * Converts value to float if possible, otherwise returns null
 * @param {*} value - The value to convert
 * @returns {number|null} Float value or null
 */
function toFloatOrNull(value) {
    if (isEmpty(value)) return null
    var num = parseFloat(value)
    return isNaN(num) ? null : num
}

/**
 * Creates a deep copy of an object
 * @param {Object} obj - The object to copy
 * @returns {Object} Deep copy of the object
 */
function deepCopy(obj) {
    if (obj == null || typeof obj !== "object") return obj
    
    if (Array.isArray(obj)) {
        return obj.map(deepCopy)
    }
    
    var copy = {}
    for (var key in obj) {
        if (obj.hasOwnProperty(key)) {
            copy[key] = deepCopy(obj[key])
        }
    }
    return copy
}

/**
 * Merges multiple objects into one (shallow merge)
 * @param {...Object} objects - Objects to merge
 * @returns {Object} Merged object
 */
function mergeObjects() {
    var result = {}
    for (var i = 0; i < arguments.length; i++) {
        var obj = arguments[i]
        for (var key in obj) {
            if (obj.hasOwnProperty(key)) {
                result[key] = obj[key]
            }
        }
    }
    return result
}