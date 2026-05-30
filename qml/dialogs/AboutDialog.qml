import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: "About GuineaMPEG"
    standardButtons: Dialog.Ok
    width: 380
    implicitHeight: 400

    Component.onCompleted: centerInParent()
    onOpened: centerInParent()
    function centerInParent() {
        if (parent) {
            x = Math.round((parent.width - width) / 2)
            y = Math.round((parent.height - height) / 2)
        }
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 6

        Label { text: "GuineaMPEG"; font.pixelSize: 20; font.bold: true; color: theme.text }
        Label { text: "FFmpeg Frontend with Rust Core"; color: theme.textSecondary; font.pixelSize: 12 }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.widgetBorder
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }

        Label { text: "Version: " + buildInfo.version; color: theme.text }
        Label { text: "Author: " + buildInfo.author; color: theme.text }
        Label { text: "License: " + buildInfo.license; color: theme.text }
        Label { text: "Distro: " + buildInfo.distroName; color: theme.text }
        Label { text: "Package: " + buildInfo.packageTarget; color: theme.textMuted; font.pixelSize: 11 }
        Label { text: "Build: " + buildInfo.buildDate; color: theme.textMuted; font.pixelSize: 11 }
        Label { text: "Copyright © " + buildInfo.copyright; color: theme.textMuted; font.pixelSize: 11 }
    }
}
