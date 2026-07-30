import QtQuick 2.15
import QtQuick.Controls 2.15
import "../../Utils/Constants.js" as Constants
import "../../Components"

Column {
    id: root
    width: parent.width
    visible: codecKey === "av1"
    spacing: 6

    property string codecKey: ""
    property bool loading: false

    signal changed

    SectionHeader {
        text: qsTr("AV1")
    }

    Grid {
        columns: 4
        columnSpacing: 8
        rowSpacing: 6
        width: parent.width

        Label { text: qsTr("Tile rows"); color: theme.textSecondary }
        TextField {
            id: tileRowsField
            width: 60
            placeholderText: qsTr("2")
            validator: IntValidator { bottom: 0; top: 8 }
            onTextChanged: if (!root.loading) root.changed()
        }
        Label { text: qsTr("Tile cols"); color: theme.textSecondary }
        TextField {
            id: tileColsField
            width: 60
            placeholderText: qsTr("3")
            validator: IntValidator { bottom: 0; top: 8 }
            onTextChanged: if (!root.loading) root.changed()
        }
    }

    CheckBox {
        id: enableQmCheck
        text: qsTr("Enable Quantization Matrix")
        onCheckedChanged: if (!root.loading) root.changed()
    }

    function getAV1Data() {
        return {
            tile_rows: tileRowsField.text ? parseInt(tileRowsField.text) : null,
            tile_columns: tileColsField.text ? parseInt(tileColsField.text) : null,
            enable_qm: enableQmCheck.checked ? true : null
        }
    }

    function setAV1Data(d) {
        tileRowsField.text = d.tile_rows != null ? String(d.tile_rows) : ""
        tileColsField.text = d.tile_columns != null ? String(d.tile_columns) : ""
        enableQmCheck.checked = d.enable_qm === true
    }
}
