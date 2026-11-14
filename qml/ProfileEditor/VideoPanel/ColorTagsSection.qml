import "../../Components"
import "../../Utils/Constants.js" as Constants
import "../../Utils/DataUtils.js" as DataUtils
import QtQuick 2.15
import QtQuick.Controls 2.15

SectionBase {
    id: root

    function getColorData() {
        return {
            "color_primaries": DataUtils.comboText(primariesCombo, Constants.SENTINEL_DEFAULT),
            "color_trc": DataUtils.comboText(trcCombo, Constants.SENTINEL_DEFAULT),
            "colorspace": DataUtils.comboText(colorspaceCombo, Constants.SENTINEL_DEFAULT),
            "color_range": DataUtils.comboText(rangeCombo, Constants.SENTINEL_DEFAULT)
        };
    }

    function setColorData(d) {
        DataUtils.setComboText(primariesCombo, d.color_primaries, Constants.SENTINEL_DEFAULT);
        DataUtils.setComboText(trcCombo, d.color_trc, Constants.SENTINEL_DEFAULT);
        DataUtils.setComboText(colorspaceCombo, d.colorspace, Constants.SENTINEL_DEFAULT);
        DataUtils.setComboText(rangeCombo, d.color_range, Constants.SENTINEL_DEFAULT);
    }

    SectionHeader {
        text: qsTr("Color tags")
    }

    LabeledRow {
        label: qsTr("Primaries")

        ComboBox {
            id: primariesCombo

            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            model: Constants.colorPrimariesOptions
            editable: true
            onCurrentIndexChanged: root.emitChanged();
            onEditTextChanged: root.emitChanged();
        }
    }

    LabeledRow {
        label: qsTr("Transfer")

        ComboBox {
            id: trcCombo

            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            model: Constants.colorTrcOptions
            editable: true
            onCurrentIndexChanged: root.emitChanged();
            onEditTextChanged: root.emitChanged();
        }
    }

    LabeledRow {
        label: qsTr("Colorspace")

        ComboBox {
            id: colorspaceCombo

            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            model: Constants.colorspaceOptions
            editable: true
            onCurrentIndexChanged: root.emitChanged();
            onEditTextChanged: root.emitChanged();
        }
    }

    LabeledRow {
        label: qsTr("Range")

        ComboBox {
            id: rangeCombo

            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            model: Constants.colorRangeOptions
            editable: true
            onCurrentIndexChanged: root.emitChanged();
            onEditTextChanged: root.emitChanged();
        }
    }
}
