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

    WidgetHeader {
        text: "Scaling"
        topPadding: 4
    }

    LabeledRow {
        label: "Resolution"
        labelWidth: 100

        ComboBox {
            id: resCombo
            model: Constants.resOptions
            width: parent.width - 108
            onCurrentIndexChanged: if (!root.loading) root.changed()
            onActivated: if (!root.loading) root.changed()
        }
    }

    LabeledRow {
        label: "Framerate"
        labelWidth: 100

        ComboBox {
            id: fpsCombo
            model: Constants.fpsOptions
            width: parent.width - 108
            editable: true
            validator: DoubleValidator { bottom: 0; top: 120 }
            onCurrentIndexChanged: if (!root.loading) root.changed()
            onEditTextChanged: if (!root.loading) root.changed()
        }
    }

    function getScalingData() {
        return {
            resolution: DataUtils.comboText(resCombo, Constants.SENTINEL_NATIVE),
            framerate: fpsCombo.currentIndex === 0 ? null : parseFloat(fpsCombo.currentText)
        }
    }

    function setScalingData(d) {
        DataUtils.setComboText(resCombo, d.resolution, Constants.SENTINEL_NATIVE)

        if (d.framerate != null) {
            var fi = Constants.fpsOptions.indexOf(d.framerate)
            if (fi >= 0) fpsCombo.currentIndex = fi
            else fpsCombo.editText = String(d.framerate)
        } else {
            fpsCombo.currentIndex = 0
        }
    }
}
