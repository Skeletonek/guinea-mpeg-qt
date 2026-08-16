import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property string text: ""
    property string subText: ""
    property color accentColor: theme.accent
    property int autoHideMs: 0
    default property alias actions: buttonsRow.children

    function show() {
        root.visible = true;
        root.opacity = 1;
        if (root.autoHideMs > 0)
            hideTimer.start();

    }

    function hide() {
        hideTimer.stop();
        root.opacity = 0;
        collapseTimer.start();
    }

    color: theme.widget
    border.color: theme.widgetBorder
    border.width: 1
    radius: 6
    implicitHeight: contentColumn.implicitHeight + 16

    Rectangle {
        id: accentBar

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: 4
        radius: 2
        color: root.accentColor
    }

    ColumnLayout {
        id: contentColumn

        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 8
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 4

        Text {
            id: mainText

            visible: root.text !== ""
            text: root.text
            color: theme.text
            font.pixelSize: 13
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Text {
            id: subTextLabel

            visible: root.subText !== ""
            text: root.subText
            color: root.accentColor
            font.pixelSize: 13
            font.bold: true
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        RowLayout {
            id: buttonsRow

            Layout.alignment: Qt.AlignRight
            spacing: 8
            visible: buttonsRow.children.length > 0
        }

    }

    Timer {
        id: hideTimer

        interval: Math.max(1, root.autoHideMs)
        onTriggered: hide()
    }

    Timer {
        id: collapseTimer

        interval: 250
        onTriggered: root.visible = false
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 200
        }

    }

}
