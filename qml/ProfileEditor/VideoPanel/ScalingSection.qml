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

    signal changed

    LabeledRow {
        label: qsTr("Resolution")
        ComboBox {
            id: resCombo
            model: Constants.resOptions
            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            onCurrentIndexChanged: if (!root.loading) root.changed()
            onActivated: if (!root.loading) root.changed()
        }
    }

    LabeledRow {
        label: qsTr("Framerate")
        ComboBox {
            id: fpsCombo
            model: Constants.fpsOptions
            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            editable: true
            validator: DoubleValidator { bottom: 0; top: 120 }
            onCurrentIndexChanged: if (!root.loading) root.changed()
            onEditTextChanged: if (!root.loading) root.changed()
        }
    }

    function getScalingData() {
        var fpsText = fpsCombo.editText.trim()
        return {
            resolution: DataUtils.comboText(resCombo, Constants.SENTINEL_NATIVE),
            framerate: (fpsText === "" || fpsText === Constants.fpsOptions[0]) ? null : parseFloat(fpsText)
        }
    }

    function setScalingData(d) {
        DataUtils.setComboText(resCombo, d.resolution, Constants.SENTINEL_NATIVE)

        if (d.framerate > 0) {
            var fi = Constants.fpsOptions.indexOf(d.framerate)
            if (fi >= 0) {
                fpsCombo.currentIndex = fi
            } else {
                fpsCombo.currentIndex = -1
                fpsCombo.editText = String(d.framerate)
            }
        } else {
            fpsCombo.currentIndex = 0
        }
    }
}
