import "../Utils/Constants.js" as Constants
import QtQuick 2.15
import QtQuick.Controls 2.15

AppDialog {
    id: root

    property string bodyText: ""

    signal confirmed

    standardButtons: Dialog.Yes | Dialog.No
    width: Constants.dialogWidthMedium
    contentImplicitHeight: bodyLabel.implicitHeight
    onAccepted: root.confirmed()

    Label {
        id: bodyLabel

        anchors.fill: parent
        text: root.bodyText
        color: theme.text
        wrapMode: Text.WordWrap
    }
}
