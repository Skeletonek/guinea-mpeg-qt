import QtQuick 2.15
import QtQuick.Controls 2.15
import "LabeledRow.qml"

/**
 * TextField with a label
 * Extends LabeledRow to provide a labeled TextField control
 */
LabeledRow {
    id: root
    
    property string text: ""
    property string placeholderText: ""
    property var validator: null
    property bool readOnly: false
    property bool passwordMode: false
    
    TextField {
        id: textField
        width: parent.width - root.labelWidth - root.spacing
        text: root.text
        placeholderText: root.placeholderText
        validator: root.validator
        readOnly: root.readOnly
        passwordMode: root.passwordMode
        
        onTextChanged: root.text = text
        onEditingFinished: root.text = text
    }
}
