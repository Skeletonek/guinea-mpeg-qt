import "../../Components"
import QtQuick 2.15
import QtQuick.Controls 2.15

SectionBase {
    id: root

    property string codecKey: ""
    property bool isCopy: false

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
    visible: codecKey === "av1" && !isCopy

    SectionHeader {
        text: "AV1"
    }

    LabeledTextField {
        id: tileRowsField

        label: qsTr("Tile rows")
        placeholderText: "2"
        onTextChanged: root.emitChanged();

        validator: IntValidator {
            bottom: 0
            top: 8
        }
    }

    LabeledTextField {
        id: tileColsField

        label: qsTr("Tile cols")
        placeholderText: "3"
        onTextChanged: root.emitChanged();

        validator: IntValidator {
            bottom: 0
            top: 8
        }
    }

    LabeledRow {
        label: qsTr("Enable Quantization Matrix")

        Switch {
            id: enableQmCheck

            onCheckedChanged: root.emitChanged();
        }
    }
}
