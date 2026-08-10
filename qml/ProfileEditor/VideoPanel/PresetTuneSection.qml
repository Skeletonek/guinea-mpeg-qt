import QtQuick 2.15
import QtQuick.Controls 2.15
import "../../Utils/Constants.js" as Constants
import "../../Utils/DataUtils.js" as DataUtils
import "../../Components"

Column {
    id: root
    spacing: 8
    width: parent.width

    property bool loading: false
    property var _capOverrides: ({})
    property string currentCodecKey: "h264"

    signal changed

    LabeledRow {
        id: presetRow
        label: qsTr("Preset")
        visible: root._capOverrides.uses_compression_level !== true

        ComboBox {
            id: presetCombo
            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            editable: true
            onCurrentIndexChanged: if (!root.loading) root.changed()
            onEditTextChanged: if (!root.loading) root.changed()
        }
    }

    LabeledRow {
        id: tuneRow
        label: qsTr("Tune")
        visible: root._capOverrides.uses_compression_level !== true

        ComboBox {
            id: tuneCombo
            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            editable: true
            onCurrentIndexChanged: if (!root.loading) root.changed()
            onEditTextChanged: if (!root.loading) root.changed()
        }
    }

    LabeledRow {
        id: compressionLevelRow
        label: qsTr("Compression Level")
        visible: root._capOverrides.uses_compression_level === true

        TextField {
            id: compressionLevelField
            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            onTextChanged: {
                if (!root.loading) root.changed()
            }
        }
    }

    function rebuildPresetModel(caps) {
        caps = caps || root._capOverrides
        var codec = root.currentCodecKey
        var list = (caps.presets || Constants.presetDefaults[codec] || []).slice()
        list.unshift(Constants.SENTINEL_DEFAULT)
        var prev = presetCombo.currentText
        presetCombo.model = list
        var idx = list.indexOf(prev)
        presetCombo.currentIndex = idx >= 0 ? idx : 0
    }

    function rebuildTuneModel(caps) {
        caps = caps || root._capOverrides
        var codec = root.currentCodecKey
        var tunes = (caps.tunes || Constants.tuneDefaults[codec] || []).slice()
        tunes.unshift(Constants.SENTINEL_DEFAULT)
        var prev = tuneCombo.currentText
        tuneCombo.model = tunes
        var idx = tunes.indexOf(prev)
        tuneCombo.currentIndex = idx >= 0 ? idx : 0
    }

    function getPresetTuneData() {
        if (root._capOverrides.uses_compression_level === true) {
            return {
                preset: null,
                tune: null,
                compression_level: compressionLevelField.text || null
            }
        }
        return {
            preset: DataUtils.comboText(presetCombo, Constants.SENTINEL_DEFAULT),
            tune: DataUtils.comboText(tuneCombo, Constants.SENTINEL_DEFAULT)
        }
    }

    function setPresetTuneData(d) {
        DataUtils.setComboText(presetCombo, d.preset, Constants.SENTINEL_DEFAULT)
        DataUtils.setComboText(tuneCombo, d.tune, Constants.SENTINEL_DEFAULT)
        if (d.compression_level !== undefined) {
            compressionLevelField.text = d.compression_level || ""
        }
    }
}
