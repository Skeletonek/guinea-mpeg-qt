import "../../Components"
import "../../Utils/Constants.js" as Constants
import "../../Utils/DataUtils.js" as DataUtils
import QtQuick 2.15
import QtQuick.Controls 2.15

Column {
    id: root

    property bool loading: false
    property var _capOverrides: ({})

    signal changed

    function rebuildPixfmtModel(caps) {
        caps = caps || root._capOverrides;
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

    spacing: 8
    width: parent.width

    LabeledRow {
        label: qsTr("Pixel fmt")

        ComboBox {
            id: pixfmtCombo

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
}
