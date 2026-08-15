import QtQuick 2.15
import QtQuick.Controls 2.15
import "../Utils/Centering.js" as Utils

Dialog {
    id: root
    title: qsTr("Overwrite File")
    standardButtons: Dialog.Yes | Dialog.No
    width: 400
    padding: 16
    implicitHeight: implicitHeaderHeight + msg.implicitHeight + implicitFooterHeight + 24
    Component.onCompleted: Utils.centerInParent(root)

    property string filePath: ""
    signal overwriteRequested()
    onAccepted: overwriteRequested()
    onOpened: {
        Utils.centerInParent(root)
        backend.systemBeep()
    }

    Label {
        id: msg
        anchors.fill: parent
        text: qsTr("The output file already exists:\n\n\"%1\"\n\nDo you want to overwrite it?").arg(root.filePath)
        color: theme.text
        wrapMode: Text.WordWrap
        elide: Text.ElideMiddle
    }
}