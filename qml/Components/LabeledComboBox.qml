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
    property string currentText: ""
    property bool editable: false
    property var delegate: null
    
    ComboBox {
        id: comboBox
        width: parent.width - root.effectiveLabelWidth - root.spacing
        model: root.model
        currentIndex: root.currentIndex
        currentText: root.currentText
        editable: root.editable
        delegate: root.delegate
        
        // Forward signals
        onCurrentIndexChanged: root.currentIndex = currentIndex
        onCurrentTextChanged: root.currentText = currentText
    }
}
