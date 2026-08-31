import QtQuick
import QtQuick.Controls

Dialog {
    id: root

    property string headline: ""
    property string body: ""

    standardButtons: Dialog.Ok
    modal: true

    Column {
        spacing: 8
        padding: 16

        Label {
            text: root.headline
            color: theme.text
            font.bold: true
        }

        Label {
            text: root.body
            color: theme.text
            wrapMode: Text.Wrap
            width: 400
        }
    }

    background: Rectangle {
        color: theme.surface
    }
}
