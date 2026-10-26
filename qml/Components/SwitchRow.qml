import QtQuick 2.15
import QtQuick.Controls 2.15

/**
 * Row with a label and a switch control
 * Used for boolean settings in form layouts
 */
Row {
    id: root

    property string label: ""
    property bool checked: false
    property color labelColor: theme.text
    property bool labelBold: false
    property int labelPixelSize: 14

    spacing: 8
    width: parent.width

    Label {
        text: root.label
        color: root.labelColor
        font.bold: root.labelBold
        font.pixelSize: root.labelPixelSize
        verticalAlignment: Text.AlignVCenter
        visible: root.label !== ""
    }

    Item {
        width: root.spacing
    }

    Switch {
        id: switchControl
        objectName: "innerSwitch"

        // checkable: false — an internal toggle would destroy the binding and desync host state (see StreamSelector)
        checkable: false
        checked: root.checked
        onClicked: root.checked = !root.checked
    }
}
