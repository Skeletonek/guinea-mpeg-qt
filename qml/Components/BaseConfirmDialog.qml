import "../Utils/Centering.js" as Utils
import QtQuick 2.15
import QtQuick.Controls 2.15

Dialog {
    id: root

    property string bodyText: ""

    signal confirmed

    standardButtons: Dialog.Yes | Dialog.No
    padding: 16
    width: 400
    implicitHeight: implicitHeaderHeight + bodyLabel.implicitHeight + implicitFooterHeight + 24
    Component.onCompleted: Utils.centerInParent(root)
    onOpened: Utils.centerInParent(root)
    onAccepted: root.confirmed()

    Label {
        id: bodyLabel

        anchors.fill: parent
        text: root.bodyText
        color: theme.text
        wrapMode: Text.WordWrap
    }
}
