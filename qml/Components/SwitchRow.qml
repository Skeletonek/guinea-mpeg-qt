import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../Utils/Constants.js" as Constants

/**
 * Row with a label and a switch control
 * Used for boolean settings in form layouts
 */
Row {
    id: root
    spacing: 8
    width: parent.width
    
    property string label: ""
    property int labelWidth: 100
    property bool checked: false
    property color labelColor: theme.text
    property bool labelBold: false
    property int labelPixelSize: 14
    
    Label {
        text: root.label
        color: root.labelColor
        font.bold: root.labelBold
        font.pixelSize: root.labelPixelSize
        width: root.labelWidth
        verticalAlignment: Text.AlignVCenter
        visible: root.label !== ""
    }
    
    Item { width: root.spacing }
    
    Switch {
        id: switchControl
        checked: root.checked
        onCheckedChanged: root.checked = checked
    }
}
