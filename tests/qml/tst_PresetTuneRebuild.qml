import QtQuick
import QtQuick.Controls 2.15
import QtTest
import "../../qml/Utils/DataUtils.js" as DataUtils

Item {
    id: root
    width: 400
    height: 400

    property var sentinel: "default"
    property var av1Presets: ["default", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13"]
    property var h264Presets: ["default", "ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow", "placebo"]

    function rebuildPresetModel(list) {
        var prev = DataUtils.comboValue(presetCombo)
        presetCombo.model = list
        var idx = list.indexOf(prev)
        presetCombo.currentIndex = idx >= 0 ? idx : 0
    }

    ComboBox {
        id: presetCombo
        editable: true
        model: h264Presets
        currentIndex: 5   // "slow"
    }

    TestCase {
        name: "PresetTuneRebuild"

        // Regression: switching to a profile whose preset/tune value is not yet
        // in the combo model applies the value via the editText fallback. The
        // subsequent model rebuild must preserve it instead of falling back to
        // the "default" sentinel (it used to read the stale currentText).
        function test_value_preserved_across_model_rebuild() {
            presetCombo.model = h264Presets
            presetCombo.currentIndex = 5   // "slow"
            DataUtils.setComboText(presetCombo, "6", sentinel)
            verify(presetCombo.currentText !== "6")   // editText fallback, index still stale
            rebuildPresetModel(av1Presets)
            compare(presetCombo.currentText, "6")
            compare(DataUtils.comboText(presetCombo, sentinel), "6")
        }

        function test_matching_value_sets_index() {
            presetCombo.model = h264Presets
            presetCombo.currentIndex = 5
            DataUtils.setComboText(presetCombo, "slow", sentinel)
            rebuildPresetModel(h264Presets)
            compare(presetCombo.currentText, "slow")
        }

        function test_sentinel_preserved() {
            presetCombo.model = h264Presets
            presetCombo.currentIndex = 5
            DataUtils.setComboText(presetCombo, sentinel, sentinel)
            rebuildPresetModel(av1Presets)
            compare(presetCombo.currentText, sentinel)
        }
    }
}