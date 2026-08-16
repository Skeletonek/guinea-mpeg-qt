import QtQuick 2.15
import QtQuick.Controls 2.15

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

    TextField {
        id: textField

        width: parent.width - root.effectiveLabelWidth - root.spacing
        text: root.text
        placeholderText: root.placeholderText
        validator: root.validator
        readOnly: root.readOnly
        onTextChanged: root.text = text
        onEditingFinished: root.text = text
    }

}
