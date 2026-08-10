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
    property int labelWidth: 170
    property color labelColor: Constants.colorPrimary
    
    // Actual width given to the label; grows to fit long translations so the
    // text never overlaps the control next to it.
    readonly property int effectiveLabelWidth: Math.max(labelWidth, labelLabel.implicitWidth)
    
    Label {
        id: labelLabel
        text: root.label
        color: theme.textSecondary
        width: root.effectiveLabelWidth
        verticalAlignment: Text.AlignVCenter
        visible: root.label !== ""
    }
}
