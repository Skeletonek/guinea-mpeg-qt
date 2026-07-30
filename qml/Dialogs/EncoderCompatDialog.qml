import QtQuick 2.15
import QtQuick.Controls 2.15
import "../Utils/Centering.js" as Utils

Dialog {
    id: root
    title: qsTr("Available Encoders")
    standardButtons: Dialog.Ok
    width: 360
    padding: 0
    implicitHeight: implicitHeaderHeight + contentCol.implicitHeight + implicitFooterHeight + 24
    Component.onCompleted: Utils.centerInParent(root)
    onOpened: Utils.centerInParent(root)

    property var codecLabels: []
    property var codecKeys: []
    property var availableEncoders: ({})

    Column {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8
        Repeater {
            model: root.codecLabels.length
            delegate: Column {
                spacing: 3
                readonly property var encs: root.availableEncoders[root.codecKeys[index]] || []
                visible: encs.length > 0
                Label {
                    text: root.codecLabels[index] + " (" + encs.length + ")"
                    color: theme.text
                    font.bold: true
                    font.pixelSize: 12
                }
                Repeater {
                    model: encs
                    delegate: Label {
                        text: "\u2022 " + modelData
                        color: theme.textSecondary
                        font.pixelSize: 11
                        leftPadding: 12
                    }
                }
            }
        }
    }
}
