import QtQuick
import QtQuick.Controls

AppDialog {
    id: root

    property string headline: ""
    property string body: ""

    title: headline
    // Semantic action (quits) — shown even when the style draws its own close button
    standardButtons: Dialog.Ok

    Label {
        id: bodyLabel

        text: root.body
        color: theme.text
        wrapMode: Text.Wrap
        width: 400
    }
}
