import "../../Components"
import "../../Utils/Constants.js" as Constants
import "../../Utils/DataUtils.js" as DataUtils
import QtQuick 2.15
import QtQuick.Controls 2.15

SectionBase {
    id: root

    function rebuildPixfmtModel(caps) {
        var items = caps.pix_fmts || Constants.pixfmtOptions;
        DataUtils.rebuildComboModel(pixfmtCombo, items, Constants.SENTINEL_DEFAULT);
    }

    function getPixelFormatData() {
        return {
            "pixel_format": DataUtils.comboText(pixfmtCombo, Constants.SENTINEL_DEFAULT)
        };
    }

    function setPixelFormatData(d) {
        DataUtils.setComboText(pixfmtCombo, d.pixel_format, Constants.SENTINEL_DEFAULT);
    }

    LabeledRow {
        label: qsTr("Pixel fmt")

        ComboBox {
            id: pixfmtCombo

            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            editable: true
            onCurrentIndexChanged: root.emitChanged();
            onEditTextChanged: root.emitChanged();
        }
    }
}
