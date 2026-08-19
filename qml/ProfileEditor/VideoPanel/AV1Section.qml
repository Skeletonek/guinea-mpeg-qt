import "../../Components"
import QtQuick 2.15
import QtQuick.Controls 2.15

Column {
    id: root

    property string codecKey: ""
    property bool loading: false

    signal changed

    function getAV1Data() {
        return {
            "tile_rows": tileRowsField.text ? parseInt(tileRowsField.text) : null,
            "tile_columns": tileColsField.text ? parseInt(tileColsField.text) : null,
            "enable_qm": enableQmCheck.checked ? true : null
        };
    }

    function setAV1Data(d) {
        tileRowsField.text = d.tile_rows != null ? String(d.tile_rows) : "";
        tileColsField.text = d.tile_columns != null ? String(d.tile_columns) : "";
        enableQmCheck.checked = d.enable_qm === true;
    }

    width: parent.width
    visible: codecKey === "av1"
    spacing: 8

    SectionHeader {
        text: "AV1"
    }

    Grid {
        columns: 4
        columnSpacing: 8
        rowSpacing: 8
        width: parent.width

        Label {
            text: qsTr("Tile rows")
            color: theme.textSecondary
        }

        TextField {
            id: tileRowsField

            width: 60
            placeholderText: "2"
            onTextChanged: {
                if (!root.loading)
                    root.changed();
            }

            validator: IntValidator {
                bottom: 0
                top: 8
            }
        }

        Label {
            text: qsTr("Tile cols")
            color: theme.textSecondary
        }

        TextField {
            id: tileColsField

            width: 60
            placeholderText: "3"
            onTextChanged: {
                if (!root.loading)
                    root.changed();
            }

            validator: IntValidator {
                bottom: 0
                top: 8
            }
        }
    }

    CheckBox {
        id: enableQmCheck

        text: qsTr("Enable Quantization Matrix")
        onCheckedChanged: {
            if (!root.loading)
                root.changed();
        }
    }
}
