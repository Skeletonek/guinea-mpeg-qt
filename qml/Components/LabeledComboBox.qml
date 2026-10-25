import QtQuick 2.15
import QtQuick.Controls 2.15

/**
 * ComboBox with a label
 * Extends LabeledRow to provide a labeled ComboBox control
 */
LabeledRow {
    id: root

    property var model: []
    property int currentIndex: -1
    readonly property alias currentText: comboBox.currentText
    property bool editable: false
    property var delegate: null

    ComboBox {
        id: comboBox

        width: parent.width - root.effectiveLabelWidth - root.spacing
        model: root.model
        currentIndex: root.currentIndex
        editable: root.editable
        delegate: root.delegate
        // Forward index changes to the wrapper so callers can read and write it.
        onCurrentIndexChanged: root.currentIndex = currentIndex
    }
}
