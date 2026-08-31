import "../../Components"
import "../../Utils/Constants.js" as Constants
import "../../Utils/DataUtils.js" as DataUtils
import QtQuick 2.15
import QtQuick.Controls 2.15

Column {
    id: root

    property bool loading: false
    property var _capOverrides: ({})
    property string currentCodecKey: "h264"

    signal changed

    function rebuildPresetModel(caps) {
        caps = caps || root._capOverrides;
        var codec = root.currentCodecKey;
        var items = caps.presets || Constants.presetDefaults[codec] || [];
        DataUtils.rebuildComboModel(presetCombo, items, Constants.SENTINEL_DEFAULT);
    }

    function rebuildTuneModel(caps) {
        caps = caps || root._capOverrides;
        var codec = root.currentCodecKey;
        var items = caps.tunes || Constants.tuneDefaults[codec] || [];
        DataUtils.rebuildComboModel(tuneCombo, items, Constants.SENTINEL_DEFAULT);
    }

    function getPresetTuneData() {
        if (root._capOverrides.uses_compression_level === true)
            return {
                "preset": null,
                "tune": null,
                "compression_level": compressionLevelField.text || null
            };

        return {
            "preset": DataUtils.comboText(presetCombo, Constants.SENTINEL_DEFAULT),
            "tune": DataUtils.comboText(tuneCombo, Constants.SENTINEL_DEFAULT)
        };
    }

    function setPresetTuneData(d) {
        DataUtils.setComboText(presetCombo, d.preset, Constants.SENTINEL_DEFAULT);
        DataUtils.setComboText(tuneCombo, d.tune, Constants.SENTINEL_DEFAULT);
        if (d.compression_level !== undefined)
            compressionLevelField.text = d.compression_level || "";
    }

    spacing: 8
    width: parent.width

    LabeledRow {
        id: presetRow

        label: qsTr("Preset")
        visible: root._capOverrides.uses_compression_level !== true

        ComboBox {
            id: presetCombo

            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            editable: true
            onCurrentIndexChanged: {
                if (!root.loading)
                    root.changed();
            }
            onEditTextChanged: {
                if (!root.loading)
                    root.changed();
            }
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
            onCurrentIndexChanged: {
                if (!root.loading)
                    root.changed();
            }
            onEditTextChanged: {
                if (!root.loading)
                    root.changed();
            }
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
                if (!root.loading)
                    root.changed();
            }
        }
    }
}
