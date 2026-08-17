import "../Utils/Centering.js" as Utils
import QtQuick 2.15
import QtQuick.Controls 2.15

Dialog {
    id: root

    signal exitRequested()

    title: qsTr("Exit Advanced Mode")
    standardButtons: Dialog.Yes | Dialog.No
    width: 400
    padding: 16
    implicitHeight: implicitHeaderHeight + msg.implicitHeight + implicitFooterHeight + 24
    Component.onCompleted: Utils.centerInParent(root)
    onOpened: Utils.centerInParent(root)
    onAccepted: exitRequested()

    Label {
        id: msg

        anchors.fill: parent
        text: qsTr("Exiting advanced mode will erase your custom ffmpeg command and return to standard profile editing.\n\nYour other profile settings are kept.\n\nContinue?")
        color: theme.text
        wrapMode: Text.WordWrap
    }

}
