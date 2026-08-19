import "../Utils/Centering.js" as Utils
import QtQuick 2.15
import QtQuick.Controls 2.15

Dialog {
    id: root

    signal restoreRequested

    title: qsTr("Restore Default Profiles")
    standardButtons: Dialog.Yes | Dialog.No
    width: 400
    padding: 16
    implicitHeight: implicitHeaderHeight + msg.implicitHeight + implicitFooterHeight + 24
    Component.onCompleted: Utils.centerInParent(root)
    onOpened: Utils.centerInParent(root)
    onAccepted: restoreRequested()

    Label {
        id: msg

        anchors.fill: parent
        text: qsTr("This will reset all built-in profiles to their original settings.\n\nCustom profiles you created will not be affected.\n\nContinue?")
        color: theme.text
        wrapMode: Text.WordWrap
    }
}
