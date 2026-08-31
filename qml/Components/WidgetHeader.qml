import QtQuick 2.15
import QtQuick.Controls 2.15

/**
 * Standard widget header with background
 * Used as the header for panel sections (Video, Audio, Advanced)
 */
Rectangle {
    id: root

    property string text: ""
    property color textColor: theme.text
    property bool bold: true
    property int pixelSize: 14

    width: parent.width
    height: 28
    color: theme.widget
    radius: 4

    Row {
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 8
        spacing: 8

        Label {
            text: root.text
            color: root.textColor
            font.bold: root.bold
            font.pixelSize: root.pixelSize
            verticalAlignment: Text.AlignVCenter
        }
    }
}
