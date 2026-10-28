import QtQuick 2.15
import QtQuick.Controls 2.15

/**
 * Reusable row component with a label and a control
 * Provides consistent spacing and alignment for form elements
 */
Row {
    id: root

    property string label: ""
    property string toolTipText: ""
    property int labelWidth: 170
    // Actual width given to the label; grows to fit long translations so the
    // text never overlaps the control next to it.
    readonly property int effectiveLabelWidth: Math.max(labelWidth, labelLabel.implicitWidth)

    spacing: 8
    width: parent.width

    Label {
        id: labelLabel

        text: root.toolTipText !== "" ? root.label + " (?)" : root.label
        color: theme.textSecondary
        width: root.effectiveLabelWidth
        verticalAlignment: Text.AlignVCenter
        visible: root.label !== ""

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            visible: root.toolTipText !== ""

            ToolTip.visible: containsMouse
            ToolTip.text: root.toolTipText
        }
    }
}
