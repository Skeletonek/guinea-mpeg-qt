import "../Utils/Constants.js" as Constants
import QtQuick 2.15
import QtQuick.Controls 2.15

Dialog {
    id: root

    property var codecLabels: []
    property var codecKeys: []
    property var availableEncoders: ({})

    title: qsTr("Available Encoders")
    standardButtons: Dialog.Ok
    width: Constants.dialogWidthCompat
    padding: 16
    modal: true
    anchors.centerIn: Overlay.overlay
    implicitHeight: implicitHeaderHeight + scroll.height + implicitFooterHeight + 24

    ScrollView {
        id: scroll

        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(440, contentCol.implicitHeight + 8)
        clip: true

        Column {
            id: contentCol

            width: scroll.availableWidth
            spacing: 8

            Repeater {
                model: root.codecLabels.length

                delegate: Column {
                    readonly property var encs: root.availableEncoders[root.codecKeys[index]] || []

                    spacing: 4
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
                            leftPadding: 8
                        }
                    }
                }
            }
        }
    }
}
