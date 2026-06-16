import QtQuick 2.15
import QtQuick.Controls 2.15
import "../Utils/Constants.js" as Constants

/**
 * Reusable row component with a label and a control
 * Provides consistent spacing and alignment for form elements
 */
Row {
    id: root
    spacing: 8
    width: parent.width
    
    property string label: ""
    property int labelWidth: 130
    property color labelColor: Constants.colorPrimary
    
    Label {
        text: root.label
        color: theme.textSecondary
        width: root.labelWidth
        verticalAlignment: Text.AlignVCenter
        visible: root.label !== ""
    }
}
