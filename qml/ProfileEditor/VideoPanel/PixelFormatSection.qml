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

    signal changed

    LabeledRow {
        label: qsTr("Pixel fmt")
        ComboBox {
            id: pixfmtCombo
            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            editable: true
            onCurrentIndexChanged: if (!root.loading) root.changed()
            onEditTextChanged: if (!root.loading) root.changed()
        }
    }

    function rebuildPixfmtModel(caps) {
        caps = caps || root._capOverrides
        var list = caps.pix_fmts
            ? caps.pix_fmts.slice()
            : Constants.pixfmtOptions.slice()
        if (list.indexOf(Constants.SENTINEL_DEFAULT) < 0)
            list.unshift(Constants.SENTINEL_DEFAULT)
        var prev = pixfmtCombo.currentText
        pixfmtCombo.model = list
        var idx = list.indexOf(prev)
        pixfmtCombo.currentIndex = idx >= 0 ? idx : 0
    }

    function getPixelFormatData() {
        return {
            pixel_format: DataUtils.comboText(pixfmtCombo, Constants.SENTINEL_DEFAULT)
        }
    }

    function setPixelFormatData(d) {
        DataUtils.setComboText(pixfmtCombo, d.pixel_format, Constants.SENTINEL_DEFAULT)
    }
}
