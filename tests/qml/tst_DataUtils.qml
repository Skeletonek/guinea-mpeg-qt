import QtQuick
import QtTest
import "../../qml/Utils/DataUtils.js" as DataUtils

TestCase {
    name: "DataUtils"

    function test_toLocalPath() {
        compare(DataUtils.toLocalPath("file:///home/user/video.mp4"), "/home/user/video.mp4")
        compare(DataUtils.toLocalPath("file:///home/user/my%20video.mp4"), "/home/user/my video.mp4")
        compare(DataUtils.toLocalPath("file:///home/user/caf%C3%A9.mp4"), "/home/user/café.mp4")
        compare(DataUtils.toLocalPath("/plain/path.mp4"), "/plain/path.mp4")
    }

    function test_toLocalPath_edgeCases() {
        compare(DataUtils.toLocalPath(""), "")
        compare(DataUtils.toLocalPath(null), "null")
        compare(DataUtils.toLocalPath(undefined), "undefined")
        compare(DataUtils.toLocalPath("file:"), "file:")
    }

    function test_toggleSelection() {
        var sel = DataUtils.toggleSelection(2, true, [0, 1])
        compare(sel.length, 3)
        compare(sel[2], 2)
        sel = DataUtils.toggleSelection(0, true, [0, 1])
        compare(sel.length, 2)
        sel = DataUtils.toggleSelection(1, false, [0, 1])
        compare(sel.length, 1)
        compare(sel[0], 0)
        sel = DataUtils.toggleSelection(5, false, [0, 1])
        compare(sel.length, 2)
    }

    function test_buildProfileData() {
        var data = DataUtils.buildProfileData({ a: 1, b: 2 }, { b: 3, c: 4 })
        compare(data.a, 1)
        compare(data.b, 3)
        compare(data.c, 4)
        compare(DataUtils.buildProfileData().hasOwnProperty("a"), false)
    }

    function test_comboText() {
        compare(DataUtils.comboText({ currentText: "value" }, "default"), "value")
        compare(DataUtils.comboText({ currentText: "default" }, "default"), null)
        compare(DataUtils.comboText({ currentText: "" }, "default"), null)
        compare(DataUtils.comboText({ currentText: null }, "default"), null)
    }

    function test_comboValue() {
        compare(DataUtils.comboValue({ currentText: "a" }), "a")
        // editable combo: a differing editText wins (typed value / stale-index fallback)
        compare(DataUtils.comboValue({ editable: true, currentText: "fast", editText: "slow" }), "slow")
        compare(DataUtils.comboValue({ editable: true, currentText: "fast", editText: "6" }), "6")
        // empty or identical editText falls through to currentText
        compare(DataUtils.comboValue({ editable: true, currentText: "fast", editText: "" }), "fast")
        compare(DataUtils.comboValue({ editable: true, currentText: "fast", editText: "fast" }), "fast")
    }

    function test_comboText_editable() {
        // regression: editable combo with a stale currentIndex reports editText
        compare(DataUtils.comboText({ editable: true, currentText: "fast", editText: "6" }, "default"), "6")
        compare(DataUtils.comboText({ editable: true, currentText: "6", editText: "6" }, "default"), "6")
        compare(DataUtils.comboText({ editable: true, currentText: "default", editText: "default" }, "default"), null)
    }

    function test_setComboText() {
        var items = ["a", "b", "c"]
        var combo = {
            count: items.length,
            textAt: function (i) { return items[i] },
            currentIndex: 0,
            editText: ""
        }
        DataUtils.setComboText(combo, "b", "default")
        compare(combo.currentIndex, 1)
        DataUtils.setComboText(combo, "default", "default")
        compare(combo.currentIndex, 0)
        DataUtils.setComboText(combo, null, "default")
        compare(combo.currentIndex, 0)
        DataUtils.setComboText(combo, "missing", "default")
        compare(combo.editText, "missing")
    }

    function test_setComboText_edgeCases() {
        var items = ["a", "b", "c"]
        var combo = {
            count: items.length,
            textAt: function (i) { return items[i] },
            currentIndex: 0,
            editText: ""
        }
        DataUtils.setComboText(combo, "", "default")
        compare(combo.currentIndex, 0)
        DataUtils.setComboText(combo, undefined, "default")
        compare(combo.currentIndex, 0)
        DataUtils.setComboText(combo, null, "default")
        compare(combo.currentIndex, 0)
        // non-string values fall back to editText without crashing
        DataUtils.setComboText(combo, 5, "default")
        compare(combo.editText, 5)
    }

    function test_setIndex() {
        var keys = ["a", "b"]
        var combo = { currentIndex: -1 }
        DataUtils.setIndex(keys, combo, "b")
        compare(combo.currentIndex, 1)
        DataUtils.setIndex(keys, combo, "nope")
        compare(combo.currentIndex, 0)
        DataUtils.setIndex([], combo, "x")
        compare(combo.currentIndex, 0)
        DataUtils.setIndex(keys, combo, undefined)
        compare(combo.currentIndex, 0)
    }

    function test_buildProfileData_edgeCases() {
        var data = DataUtils.buildProfileData({ a: 1 }, null, { c: 3 }, undefined)
        compare(data.a, 1)
        compare(data.c, 3)
        compare(DataUtils.buildProfileData(null).hasOwnProperty("a"), false)
        compare(DataUtils.buildProfileData(undefined).hasOwnProperty("a"), false)
    }
}