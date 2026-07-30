import QtQuick 2.15
import QtQuick.Controls 2.15
import "../Utils/Centering.js" as Utils

Dialog {
    id: root
    title: qsTr("Delete Profile")
    standardButtons: Dialog.Yes | Dialog.No
    width: 380
    padding: 0
    implicitHeight: implicitHeaderHeight + delMsg.implicitHeight + implicitFooterHeight + 24
    Component.onCompleted: Utils.centerInParent(root)
    onOpened: Utils.centerInParent(root)

    property string profileName: ""
    signal deleteRequested()
    onAccepted: deleteRequested()

    Label {
        id: delMsg
        anchors.fill: parent
        anchors.margins: 16
        text: qsTr("Delete profile \"%1\"?\n\nThis cannot be undone.").arg(root.profileName)
        color: theme.text
        wrapMode: Text.WordWrap
    }
}
