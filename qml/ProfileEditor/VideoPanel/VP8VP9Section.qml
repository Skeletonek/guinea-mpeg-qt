import "../../Components"
import "../../Utils/Constants.js" as Constants
import "../../Utils/DataUtils.js" as DataUtils
import QtQuick 2.15
import QtQuick.Controls 2.15

SectionBase {
    id: root

    property string codecKey: ""
    property bool isCopy: false

    function getVP8VP9Data() {
        var cpuUsedTmp = DataUtils.comboText(cpuUsedCombo, Constants.SENTINEL_DEFAULT);
        return {
            "cpu_used": cpuUsedTmp ? parseInt(cpuUsedTmp) : null
        };
    }

    function setVP8VP9Data(d) {
        DataUtils.setComboText(cpuUsedCombo, d.cpu_used != null ? String(d.cpu_used) : null, Constants.SENTINEL_DEFAULT);
    }

    width: parent.width
    visible: (codecKey === "vp8" || codecKey === "vp9") && !isCopy

    SectionHeader {
        text: "VP8/VP9"
    }

    LabeledRow {
        label: qsTr("CPU used")

        ComboBox {
            id: cpuUsedCombo

            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            editable: true
            model: Constants.vp8Vp9CpuUsedOptions
            onCurrentIndexChanged: root.emitChanged();
            onEditTextChanged: root.emitChanged();
        }
    }
}
